import LegibleError
import PromiseKit
import CloudKit
import Bakeware
import Path

enum E: Error {
    case invalidRecord
    case conflict
}

public class Item {
    var md5: String { return record[.checksum] as! String }
    var record: CKRecord
    public var relativePath: String { return record.recordID.recordName }
    public var path: Path { return Path.home/relativePath }

    public internal(set) var status: Status

    init(record: CKRecord) {
        self.record = record
        self.status = .init(record: record)
    }

    init(record: CKRecord, status: Status) {
        self.record = record
        self.status = status
    }

    public enum Status {
        case synced
        case error(Error)
        case networking(Promise<Void>)

        init(record: CKRecord) {
            do {
                guard let md5 = record[.checksum] as? String else {
                    throw E.invalidRecord
                }
                guard try Data(contentsOf: Path.home/record.recordID.recordName).md5 == md5 else {
                    throw E.conflict
                }
                self = .synced
            } catch {
                self = .error(error)
            }
        }
    }

    public var statusString: String {
        switch status {
        case .synced:
            return "✅ \(ago: record.modificationDate ?? record.creationDate)"
        case .error(let error):
            return "❌ \(error.legibleDescription)"
        case .networking:
            return "🔃 Networking…"
        }
    }
}

extension Item: Equatable {
    public static func == (lhs: Item, rhs: Item) -> Bool {
        return lhs.relativePath == rhs.relativePath
    }
}

extension Item: Comparable {
    public static func < (lhs: Item, rhs: Item) -> Bool {
        return lhs.path < rhs.path
    }
}

extension Item: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(relativePath)
    }
}

extension String {
    static let recordType = "dotfile"
    static let data = "data"
    static let checksum = "md5"
}

public extension Promise where T == [Item] {
    convenience init() {
        self.init(resolver: { seal in
            let query = CKQuery(recordType: .recordType, predicate: NSPredicate(value: true))
            db.perform(query).mapValues(Item.init).pipe(to: seal.resolve)
        })
    }
}

public extension Promise where T == Item {
    convenience init(validatedUrl: URL, relativePath: String) {

        //TODO sucks, add item immediately to tableView in networking state

        assert(Path(url: validatedUrl)?.relative(to: Path.home) == relativePath)

        self.init { seal in
            DispatchQueue.global().async(.promise) {
                let record = CKRecord(recordType: .recordType, recordID: CKRecord.ID(recordName: relativePath))
                let data = try Data(contentsOf: validatedUrl)
                record[.data] = data as CKRecordValue
                record[.checksum] = data.md5 as CKRecordValue
                return record
            }.then(db.save).map {
                Item(record: $0, status: .synced)
            }.pipe(to: seal.resolve)
        }
    }
}
