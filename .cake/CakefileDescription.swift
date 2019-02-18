import Foundation

/// Dependencies for your Model (can be used by App too, but we will eventually add a separate
public var dependencies: [Dependency] = []

/// Checks out the dependency but does not integrate, integration is up to you
public var vendors: [Vendor] = []

/**
 Will also build executables and then make those executables available for scripts
 possibly make it possible for these tools to define their own scripts for user benefit
*/
public var buildDependencies: [Dependency] = []

/// Configures the build targets for model modules
public var platforms: Set<PlatformSpecification> = []


/// Various configurable properties
public struct Options: Codable {
    /// The name of the base model module, if there is only one
    public var baseModuleName = "CakeBase"
}

/// - See: `Options`
public var options = Options()


public enum Dependency {
    case github(PackageSpecification)
    case xcode(VersionSpecification)
    case swift(VersionSpecification)
    case macOS(VersionSpecification)
    case cake(VersionSpecification)
}

public enum VersionSpecification: Codable, Hashable, Equatable {
    case from(Version)
    case range(Range<Version>)
    case exact(Version)
    case master

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Kind.self, forKey: .type)
        switch type {
        case .from:
            self = .from(try container.decode(Version.self, forKey: .version))
        case .range:
            fatalError()
        case .exact:
            self = .exact(try container.decode(Version.self, forKey: .version))
        case .master:
            self = .master
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .from(let version):
            try container.encode(Kind.from, forKey: .type)
            try container.encode(version, forKey: .version)
        case .range:
            try container.encode(Kind.range, forKey: .type)
            fatalError()
        case .exact(let version):
            try container.encode(Kind.exact, forKey: .type)
            try container.encode(version, forKey: .version)
        case .master:
            try container.encode(Kind.master, forKey: .type)
        }
    }

    enum Kind: String, Codable {
        case from
        case range
        case exact
        case master
    }

    enum CodingKeys: CodingKey {
        case type
        case version
    }
}

public struct PackageSpecification: Codable, Hashable {
    public init(url: URL, versionSpecification: VersionSpecification) {
        self.url = url
        self.versionSpecification = versionSpecification
    }
    public let url: URL
    public let versionSpecification: VersionSpecification
}

public enum Platform: String, Codable, Hashable, Equatable {
    case iOS, macOS
}

public struct PlatformSpecification: Codable, Equatable, Hashable {
    public let platform: Platform
    public let version: Version

    //FIXME Set semantics may make this bad in practice
    func hasher(into hasher: inout Hasher) {
        hasher.combine(platform)
    }

    public init(platform: Platform, version: Version) {
        self.platform = platform
        self.version = version
    }
}

extension PlatformSpecification: CustomStringConvertible {
    public var description: String {
        return ".\(platform) ~> \(version.major).\(version.minor)"
    }
}

extension PackageSpecification: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.url = URL(string: "https://github.com/\(value.githubPair).git")!
        self.versionSpecification = .master

        warning("Specifying packages without a version constraint (~>) fetches master which, in extreme cases, may lead to miffed co‐workers.")
    }
}

extension Version: ExpressibleByFloatLiteral {
    @inlinable
    public init(_ value: FloatLiteralType) {
        self.init(floatLiteral: value)
    }

    @inlinable
    public init(floatLiteral value: FloatLiteralType) {
        self.init(string: "\(value).0")!
    }
}

extension VersionSpecification: ExpressibleByFloatLiteral {
    @inlinable
    public init(floatLiteral value: FloatLiteralType) {
        self = .exact(Version(value))
    }
}

public enum Vendor {
    case github(PackageSpecification)
}

public func ~> (lhs: String, rhs: Double) -> PackageSpecification {
    let url = URL(string: "https://github.com/\(lhs.githubPair).git")!
    return .init(url: url, versionSpecification: .from(Version(floatLiteral: rhs)))
}

public func ~> (lhs: Platform, rhs: Double) -> PlatformSpecification {
    return .init(platform: lhs, version: Version(floatLiteral: rhs))
}

prefix operator ~>
public prefix func ~> (value: Double) -> VersionSpecification {
    return .from(Version(floatLiteral: value))
}

private func warning(_ msg: String) {
    fputs("warning: \(msg)\n", stderr)
}

private extension String {
    var githubPair: String {
        if hasPrefix("/") {
            warning("package specifier has leading slashes")
        }
        if hasSuffix("/") {
            warning("package specifier has trailing slashes")
        }

        let split = self.split(separator: "/", omittingEmptySubsequences: true)

        if split.count < 2 {
            warning("insufficient path components for package specification, SwiftPM *will* fail")
        }
        if split.count > 2 {
            warning("ignoring components in package specification beyond 2")
        }

        return split[0...1].joined(separator: "/")
    }
}

public struct CakefileDump: Codable {
    public let platforms: Set<PlatformSpecification>
    public let dependencies: [PackageSpecification]
    public let options: Options

    public init(platforms: Set<PlatformSpecification>, dependencies: [PackageSpecification], options: Options) {
        self.platforms = platforms
        self.dependencies = dependencies
        self.options = options
    }
}
