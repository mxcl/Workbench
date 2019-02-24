import struct Foundation.OperatingSystemVersion
import class Foundation.ProcessInfo
import class Foundation.Bundle

/// An extension to Bundle that provides Versions
public extension Bundle {
    /**
     The version of the bundle.
     - Remark: We use a tolerant parser, so strings like `10.1` or even `3` will parse.
     - Note: Uses the value for the key `CFBundleShortVersionString`.
     - Important: Returns `0.0.0` (`Version.null`) if result is absent or invalid.
    */
    var version: Version {
        return (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(Version.init(tolerant:)) ?? .null
    }
}

/// An extension to ProcessInfo that provides Versions
public extension ProcessInfo {
    /// The version of the operating system on which the process is executing.
    @available(OSX, introduced: 10.10)
    @available(iOS, introduced: 8.0)
    var osVersion: Version {
        //NOTE cannot call “super” from an extension that replaces that method
        // tried to use keypaths but couldn’t. This way we are not making the
        // method ambiguous anyway, so probably better.
        let v: OperatingSystemVersion = operatingSystemVersion
        return Version(major: v.majorVersion, minor: v.minorVersion, patch: v.patchVersion)
    }
}
