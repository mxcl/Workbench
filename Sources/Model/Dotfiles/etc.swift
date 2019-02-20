import CloudKit

var db: CKDatabase {
    @inline(__always)
    get { return CKContainer.default().privateCloudDatabase }
}

extension String {
    static let recordType = "dotfile"
    static let asset = "asset"
    static let checksum = "md5"
}
