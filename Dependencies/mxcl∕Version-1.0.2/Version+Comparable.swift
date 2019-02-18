extension Version: Comparable {
    func isEqualWithoutPrerelease(_ other: Version) -> Bool {
        return major == other.major && minor == other.minor && patch == other.patch
    }

    /**
     `1.0.0` is less than `1.0.1`, `1.0.1-alpha` is less than `1.0.1` but
     greater than `1.0.0`.
     - Returns: `true` if `lhs` is less than `rhs`
     */
    public static func < (lhs: Version, rhs: Version) -> Bool {
        let lhsComparators = [lhs.major, lhs.minor, lhs.patch]
        let rhsComparators = [rhs.major, rhs.minor, rhs.patch]

        if lhsComparators != rhsComparators {
            return lhsComparators.lexicographicallyPrecedes(rhsComparators)
        }

        guard lhs.prereleaseIdentifiers.count > 0 else {
            return false // Non-prerelease lhs >= potentially prerelease rhs
        }

        guard rhs.prereleaseIdentifiers.count > 0 else {
            return true // Prerelease lhs < non-prerelease rhs
        }

        let zippedIdentifiers = zip(lhs.prereleaseIdentifiers, rhs.prereleaseIdentifiers)
        for (lhsPrereleaseIdentifier, rhsPrereleaseIdentifier) in zippedIdentifiers {
            if lhsPrereleaseIdentifier == rhsPrereleaseIdentifier {
                continue
            }

            let typedLhsIdentifier: Any = Int(lhsPrereleaseIdentifier) ?? lhsPrereleaseIdentifier
            let typedRhsIdentifier: Any = Int(rhsPrereleaseIdentifier) ?? rhsPrereleaseIdentifier

            switch (typedLhsIdentifier, typedRhsIdentifier) {
                case let (int1 as Int, int2 as Int): return int1 < int2
                case let (string1 as String, string2 as String): return string1 < string2
                case (is Int, is String): return true // Int prereleases < String prereleases
                case (is String, is Int): return false
            default:
                fatalError("impossi-op")
            }
        }

        return lhs.prereleaseIdentifiers.count < rhs.prereleaseIdentifiers.count
    }
}
