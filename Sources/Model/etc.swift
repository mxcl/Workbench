import CommonCrypto
import Foundation

public extension Data {
    var md5: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        func convert(bytes: UnsafeRawBufferPointer) -> Void {
            CC_MD5(bytes.baseAddress, CC_LONG(count), &digest)
        }
        withUnsafeBytes(convert)
        return (0..<digest.count).reduce(into: "") {
            $0 += String(format:"%02x", digest[$1])
        }
    }
}

public extension Date {
    var ago: String {
        let timeIntervalSinceNow = self.timeIntervalSinceNow
        if timeIntervalSinceNow >= 60 {
            // allow a minute of variance
            // anything more means the user’s system time is *really* wrong and
            // we *should* tell them about it!
            return "The future"
        }
        let ti = abs(timeIntervalSinceNow)

        if ti < 120 { return "Just now" }
        if ti < 2*60*60 { return "\(lrint(ti / 60)) minutes" }
        if ti < 2*24*60*60 { return "\(lrint(ti / (60*60))) hours" }
        if ti < 14*24*60*60 { return "\(lrint(ti / (24*60*60))) days" }

        return "\(lrint(ti / (7*24*60*60))) weeks"
    }
}

public extension Optional where Wrapped == Date {
    var ago: String {
        switch self {
        case .none:
            return "Never"
        case .some(let date):
            return date.ago
        }
    }
}

public extension Sequence {
    @inlinable
    func map<T>(_ keyPath: KeyPath<Element, T>) -> [T] {
        return map {
            $0[keyPath: keyPath]
        }
    }

    @inlinable
    func compactMap<T>(_ keyPath: KeyPath<Element, T?>) -> [T] {
        return compactMap {
            $0[keyPath: keyPath]
        }
    }

    @inlinable
    func flatMap<T>(_ keyPath: KeyPath<Element, [T]>) -> [T] {
        return flatMap {
            $0[keyPath: keyPath]
        }
    }
}

public extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}


import CloudKit

public var db: CKDatabase {
    @inline(__always)
    get { return CKContainer.default().privateCloudDatabase }
}

public struct StateMachineError: Error {
    let line: UInt
    let file: StaticString

    public init(file: StaticString = #file, line: UInt = #line) {
        self.file = file
        self.line = line
    }
}


import LegibleError
import PromiseKit

public extension Promise {
    @discardableResult
    func log() -> PMKFinalizer {
        return self.catch {
            print("error:", $0.legibleDescription)
        }
    }
}

public extension PromiseKit.Result {
    var value: T? {
        switch self {
        case .fulfilled(let tee):
            return tee
        case .rejected:
            return nil
        }
    }
}
