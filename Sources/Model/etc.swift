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
