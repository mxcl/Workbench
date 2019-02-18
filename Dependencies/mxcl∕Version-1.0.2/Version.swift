/*
 This source file was modified by Max Howell from its original
 form that was part of the Swift open source project.

 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/**
 A struct representing a “semver” version, that is: a Semantic Version.
 - SeeAlso: https://semver.org
 */
public struct Version: Hashable {
    /// The major version.
    public let major: Int

    /// The minor version.
    public let minor: Int

    /// The patch version.
    public let patch: Int

    /// The pre-release identifiers (if any).
    public let prereleaseIdentifiers: [String]

    /// The build metadatas (if any).
    public let buildMetadataIdentifiers: [String]

    /**
     Create a version object.
     - Remark: This initializer variant provided for more readable code when initializing with static integers.
     */
    @inlinable
    public init(_ major: Int, _ minor: Int, _ patch: Int, prereleaseIdentifiers: [String] = [], buildMetadataIdentifiers: [String] = []) {
        self.major = abs(major)
        self.minor = abs(minor)
        self.patch = abs(patch)
        self.prereleaseIdentifiers = prereleaseIdentifiers
        self.buildMetadataIdentifiers = buildMetadataIdentifiers

        if major < 0 || minor < 0 || patch < 0 {
            print("warning: negative component in version: \(major).\(minor).\(patch)")
            print("notice: negative components were abs’d")
        }
    }

    /**
     Creates a version object.
     - Remark: This initializer variant provided when it would be more readable than the nameless variant.
     */
    @inlinable
    public init(major: Int, minor: Int, patch: Int, prereleaseIdentifiers: [String] = [], buildMetadataIdentifiers: [String] = []) {
        self.init(major, minor, patch, prereleaseIdentifiers: prereleaseIdentifiers, buildMetadataIdentifiers: buildMetadataIdentifiers)
    }

    /**
     Creates a version object.
     - Remark: This initializer variant uses a more tolerant parser, eg. `10.1` parses to `Version(10,1,0)`
     */
    public init?(tolerant: String) {
        if let major = Int(tolerant) {
            self.init(major, 0, 0)
        } else if let pair = Double(tolerant) {
            self.init("\(pair).0")
        } else {
            self.init(tolerant)
        }
    }

    /// Represents `0.0.0`
    public static let null = Version(0,0,0)
}

extension Version: LosslessStringConvertible {
    /**
     Creates a version object from a string.
     - Note: Returns `nil` if the string is not a valid semantic version.
     - Parameter string: The string to parse.
     */
    public init?(_ string: String) {
        let prereleaseStartIndex = string.firstIndex(of: "-")
        let metadataStartIndex = string.firstIndex(of: "+")

        let requiredEndIndex = prereleaseStartIndex ?? metadataStartIndex ?? string.endIndex
        let requiredCharacters = string.prefix(upTo: requiredEndIndex)
        let requiredComponents = requiredCharacters
            .split(separator: ".", maxSplits: 2, omittingEmptySubsequences: false)
            .map(String.init).compactMap({ Int($0) }).filter({ $0 >= 0 })

        guard requiredComponents.count == 3 else { return nil }

        self.major = requiredComponents[0]
        self.minor = requiredComponents[1]
        self.patch = requiredComponents[2]

        func identifiers(start: String.Index?, end: String.Index) -> [String] {
            guard let start = start else { return [] }
            let identifiers = string[string.index(after: start)..<end]
            return identifiers.split(separator: ".").map(String.init)
        }

        self.prereleaseIdentifiers = identifiers(
            start: prereleaseStartIndex,
            end: metadataStartIndex ?? string.endIndex)
        self.buildMetadataIdentifiers = identifiers(
            start: metadataStartIndex,
            end: string.endIndex)
    }

    /// Returns the lossless string representation of this semantic version.
    public var description: String {
        var base = "\(major).\(minor).\(patch)"
        if !prereleaseIdentifiers.isEmpty {
            base += "-" + prereleaseIdentifiers.joined(separator: ".")
        }
        if !buildMetadataIdentifiers.isEmpty {
            base += "+" + buildMetadataIdentifiers.joined(separator: ".")
        }
        return base
    }
}
