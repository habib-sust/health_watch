import Foundation

extension JSONEncoder {
    /// Shared encoder configured for the HealthWatch API
    nonisolated static let healthWatch: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
}

extension JSONDecoder {
    /// Shared decoder configured for the HealthWatch API
    nonisolated static let healthWatch: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
