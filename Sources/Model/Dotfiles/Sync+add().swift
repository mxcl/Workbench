import Dependencies
import Foundation
import CloudKit

extension Sync {
    public static let defaults = [
        ".bash_profile",
        ".bashrc",
        ".gitconfig",
        ".hushlogin",
        ".ssh/config",
        ".ssh/known_hosts",
        ".lldbinit",
        ".profile",
    ].map(Path.home.join)

    public struct AddError: Swift.Error {
        public enum Kind {
            case noSuchFile
            case invalidUrl
            case notHomeFile
        }
        public let kind: Kind
        public let url: URL
    }

    /// for user-initiated explicit add
    public func add(urls: [URL]) -> Guarantee<[Result<Item>]> {
        let home = Path.home

        func add(_ url: URL) -> Promise<Item> {
            do {
                guard url.isFileURL else {
                    throw AddError(kind: .invalidUrl, url: url)
                }
                guard FileManager.default.isReadableFile(atPath: url.path) else {
                    throw AddError(kind: .noSuchFile, url: url)
                }
                guard let path = Path(url: url) else {
                    throw AddError(kind: .invalidUrl, url: url)
                }
                guard path.string.hasPrefix(home.string) else {
                    throw AddError(kind: .notHomeFile, url: url)
                }
                let relativePath = path.relative(to: home)

                return self.add(validatedUrl: url, relativePath: relativePath)
            } catch {
                return Promise(error: error)
            }
        }

        return when(resolved: urls.map(add))
    }

    private func add(validatedUrl: URL, relativePath: String) -> Promise<Item> {

        var item: Item!

        func save(_ record: CKRecord) -> Promise<Item> {
            let promise1 = db.save(record)
            item = Item(record: record, status: .networking(promise1.asVoid()))
            let promise2 = DispatchQueue.main.async(.promise) {
                self.items.append(item)
            }
            return when(fulfilled: promise1, promise2).map(on: nil){ _ in item }
        }

        return DispatchQueue.global().async(.promise) {
            let record = CKRecord(recordType: .recordType, recordID: CKRecord.ID(recordName: relativePath))
            let data = try Data(contentsOf: validatedUrl)
            record[.data] = data as CKRecordValue
            record[.checksum] = data.md5 as CKRecordValue
            return record
        }.then {
            save($0)
        }.tap(on: .main) { result in
            switch result {
            case .fulfilled:
                item.status = .init(record: item.record)
            case .rejected(let error):
                item.status = .error(error)
            }
            self.delegate?.dotfilesSyncItemsUpdated()
        }
    }
}
