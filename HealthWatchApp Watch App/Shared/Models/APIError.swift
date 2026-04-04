import Foundation

enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case rateLimited(retryAfter: String?)
    case serverError(statusCode: Int)
    case httpError(statusCode: Int, data: Data)
    case networkUnavailable
    case timeout
    case encodingFailed
    case decodingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case .unauthorized:
            return "Authentication required. Please sign in again."
        case .rateLimited:
            return "Too many requests. Please try again shortly."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .httpError(let code, _):
            return "Request failed with status \(code)."
        case .networkUnavailable:
            return "No network connection. Please check your internet."
        case .timeout:
            return "Request timed out. Please try again."
        case .encodingFailed:
            return "Failed to prepare request data."
        case .decodingFailed:
            return "Failed to read server response."
        }
    }
}

enum WatchError: Error {
    case tokenRevoked
    case provisioningRequired
    case healthKitUnavailable
    case storageFull
    case configCorrupted
}

enum ProvisioningError: Error {
    case watchNotReachable
    case codeExpired
    case maxAttemptsExceeded
    case configDeliveryFailed
    case keychainSaveFailed
    case serverUnavailable
}
