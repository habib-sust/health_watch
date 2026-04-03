import Foundation

/// Protocol for providing auth tokens to the API client.
protocol TokenStore: Sendable {
    func currentToken() async -> String?
}

/// Static token store for demo — always returns the hardcoded token.
final class StaticTokenStore: TokenStore, @unchecked Sendable {
    private let token: String

    init(token: String) {
        self.token = token
    }

    func currentToken() async -> String? {
        token
    }
}
