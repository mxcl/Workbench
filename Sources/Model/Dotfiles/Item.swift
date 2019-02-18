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
    let record: CKRecord
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
            return "✅ \((record.modificationDate ?? record.creationDate)?.ago ?? "")"
        case .error(let error):
            return "❌ \(error.legibleLocalizedDescription)"
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
