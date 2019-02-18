extension Version: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let s = try container.decode(String.self)
        guard let v = Version(s) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid semantic version")
        }
        self = v
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
