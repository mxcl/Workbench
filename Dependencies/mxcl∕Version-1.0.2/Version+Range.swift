extension ClosedRange where Bound == Version {
    /**
     - Returns: `true` if the provided Version exists within this range.
     - Important: Returns `false` if `version` has prerelease identifiers unless
     the range *also* contains prerelease identifiers.
     */
    public func contains(_ version: Version) -> Bool {
        // Special cases if version contains prerelease identifiers.
        if !version.prereleaseIdentifiers.isEmpty, lowerBound.prereleaseIdentifiers.isEmpty && upperBound.prereleaseIdentifiers.isEmpty {
            // If the range does not contain prerelease identifiers, return false.
            return false
        }

        // Otherwise, apply normal contains rules.
        return version >= lowerBound && version <= upperBound
    }
}

extension Range where Bound == Version {
    /**
     - Returns: `true` if the provided Version exists within this range.
     - Important: Returns `false` if `version` has prerelease identifiers unless
     the range *also* contains prerelease identifiers.
     */
    public func contains(_ version: Version) -> Bool {
        // Special cases if version contains prerelease identifiers.
        if !version.prereleaseIdentifiers.isEmpty {
            // If the range does not contain prerelease identifiers, return false.
            if lowerBound.prereleaseIdentifiers.isEmpty && upperBound.prereleaseIdentifiers.isEmpty {
                return false
            }

            // At this point, one of the bounds contains prerelease identifiers.
            // Reject 2.0.0-alpha when upper bound is 2.0.0.
            if upperBound.prereleaseIdentifiers.isEmpty && upperBound.isEqualWithoutPrerelease(version) {
                return false
            }
        }

        // Otherwise, apply normal contains rules.
        return version >= lowerBound && version < upperBound
    }
}
