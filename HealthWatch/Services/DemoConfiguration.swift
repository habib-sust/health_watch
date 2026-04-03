import Foundation

/// Hardcoded demo configuration — replaces AuthManager for the demo build.
/// This entire file will be replaced by real authentication in the production build.
struct DemoConfiguration {
    /// Hardcoded staff identity
    static let staffId = "staff-demo-001"
    static let staffName = "Demo Staff"

    /// Server URL — configure to point at your demo backend
    static let serverURL = "https://dev-api.healthwatch.example"

    /// Hardcoded bearer token for API calls (demo server must accept this)
    static let apiToken = "demo-token-healthwatch-2026"

    /// Watch-scoped token issued during provisioning.
    /// In production this comes from POST /api/v1/individuals/{id}/provision
    static let watchAuthToken = "demo-watch-token-healthwatch-2026"
}
