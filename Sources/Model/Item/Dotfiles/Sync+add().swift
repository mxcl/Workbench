import Dependencies
import Foundation
import Bakeware
import CloudKit
import Item

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
        return firstly {
            Promise(validatedUrl: validatedUrl, relativePath: relativePath)
        }.get { newItem in
            self.items.append(newItem)
            self.delegate?.dotfilesSyncItemsUpdated()
        }
    }
}
