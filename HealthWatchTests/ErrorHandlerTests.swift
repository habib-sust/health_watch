import Testing
@testable import HealthWatch

struct ErrorHandlerTests {

    @Test("API errors produce user-friendly titles")
    func apiErrorMessages() {
        let errors: [APIError] = [
            .unauthorized,
            .rateLimited(retryAfter: "60"),
            .serverError(statusCode: 500),
            .networkUnavailable,
            .timeout,
            .decodingFailed(underlying: NSError(domain: "", code: 0)),
            .invalidResponse
        ]

        for error in errors {
            let message = ErrorHandler.userMessage(for: error)
            #expect(!message.title.isEmpty)
            #expect(!message.message.isEmpty)
            // Ensure no raw error codes leak into user messages
            #expect(!message.message.contains("500"))
            #expect(!message.title.contains("Error("))
        }
    }

    @Test("Provisioning errors include actionable guidance")
    func provisioningErrorMessages() {
        let errors: [ProvisioningError] = [
            .watchNotReachable,
            .codeExpired,
            .maxAttemptsExceeded,
            .configDeliveryFailed,
            .keychainSaveFailed,
            .serverUnavailable
        ]

        for error in errors {
            let message = ErrorHandler.userMessage(for: error)
            #expect(!message.title.isEmpty)
            #expect(!message.message.isEmpty)
        }
    }

    @Test("watchNotReachable mentions Apple Watch")
    func watchNotReachableMessage() {
        let message = ErrorHandler.userMessage(for: ProvisioningError.watchNotReachable)
        #expect(message.message.contains("Apple Watch"))
    }

    @Test("Unknown errors get generic message")
    func unknownError() {
        let error = NSError(domain: "test", code: 42)
        let message = ErrorHandler.userMessage(for: error)
        #expect(message.title == "Something Went Wrong")
    }
}
