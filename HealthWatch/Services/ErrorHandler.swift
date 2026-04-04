import Foundation

/// Centralized error handler that maps errors to user-facing messages.
/// Never shows raw error codes or technical details.
enum ErrorHandler {

    struct UserMessage {
        let title: String
        let message: String
        let actionLabel: String?
    }

    static func userMessage(for error: Error) -> UserMessage {
        if let apiError = error as? APIError {
            return mapAPIError(apiError)
        }
        if let provError = error as? ProvisioningError {
            return mapProvisioningError(provError)
        }
        return UserMessage(
            title: "Something Went Wrong",
            message: "An unexpected error occurred. Please try again.",
            actionLabel: "Retry"
        )
    }

    private static func mapAPIError(_ error: APIError) -> UserMessage {
        switch error {
        case .unauthorized:
            return UserMessage(
                title: "Session Expired",
                message: "Your session has expired. Please restart the app.",
                actionLabel: "OK"
            )
        case .rateLimited:
            return UserMessage(
                title: "Too Many Requests",
                message: "Please wait a moment before trying again.",
                actionLabel: "OK"
            )
        case .serverError:
            return UserMessage(
                title: "Server Error",
                message: "The server is temporarily unavailable. Data will sync automatically when it's back online.",
                actionLabel: "OK"
            )
        case .networkUnavailable:
            return UserMessage(
                title: "No Connection",
                message: "Check your internet connection and try again.",
                actionLabel: "Retry"
            )
        case .timeout:
            return UserMessage(
                title: "Connection Slow",
                message: "The request took too long. Please try again.",
                actionLabel: "Retry"
            )
        case .decodingFailed:
            return UserMessage(
                title: "Data Error",
                message: "There was a problem reading the server response. Please try again later.",
                actionLabel: nil
            )
        default:
            return UserMessage(
                title: "Request Failed",
                message: "Something went wrong. Please try again.",
                actionLabel: "Retry"
            )
        }
    }

    private static func mapProvisioningError(_ error: ProvisioningError) -> UserMessage {
        switch error {
        case .watchNotReachable:
            return UserMessage(
                title: "Watch Not Found",
                message: "Make sure your Apple Watch is nearby, unlocked, and the HealthWatch app is installed.",
                actionLabel: "Try Again"
            )
        case .codeExpired:
            return UserMessage(
                title: "Code Expired",
                message: "The verification code has expired. Please start the provisioning process again.",
                actionLabel: "Start Over"
            )
        case .maxAttemptsExceeded:
            return UserMessage(
                title: "Too Many Attempts",
                message: "You've exceeded the maximum number of attempts. Please wait 5 minutes and try again.",
                actionLabel: nil
            )
        case .configDeliveryFailed:
            return UserMessage(
                title: "Setup Failed",
                message: "Could not send configuration to the watch. Make sure it's nearby and try again.",
                actionLabel: "Try Again"
            )
        case .keychainSaveFailed:
            return UserMessage(
                title: "Storage Error",
                message: "Could not save secure credentials. Please try again.",
                actionLabel: "Retry"
            )
        case .serverUnavailable:
            return UserMessage(
                title: "Server Unavailable",
                message: "Could not reach the server. Please check your connection and try again.",
                actionLabel: "Retry"
            )
        }
    }
}
