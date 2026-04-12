import Foundation

enum AppConstants {
    /// Keychain service identifier
    static let keychainService = "com.company.healthwatch"

    /// Shared Keychain access group for iOS <-> watchOS
    static let keychainAccessGroup = "com.company.healthwatch.shared"

    /// Provisioning code length
    static let provisioningCodeLength = 4

    /// Provisioning code expiry in seconds
    static let provisioningCodeExpiry: TimeInterval = 120

    /// Max provisioning code attempts before lockout
    static let maxProvisioningAttempts = 3

    /// Lockout duration after max failed attempts (5 minutes)
    static let provisioningLockoutDuration: TimeInterval = 300

    /// Background refresh preferred interval (15 minutes)
    static let backgroundRefreshInterval: TimeInterval = 15 * 60

    /// Dashboard polling interval in seconds
    static let dashboardPollingInterval: TimeInterval = 60

    /// Max buffered samples per push cycle
    static let maxBufferedSamplesPerCycle = 500

    /// Buffer purge age (7 days)
    static let bufferPurgeDays = 7

    /// De-duplication cache size
    static let deduplicationCacheSize = 10_000

    /// API timeout for regular requests
    static let apiRequestTimeout: TimeInterval = 30

    /// API timeout for resource downloads
    static let apiResourceTimeout: TimeInterval = 60

    // MARK: - QR Provisioning

    /// Polling interval for watch config check (seconds)
    static let qrPollingInterval: TimeInterval = 5

    /// Max time to poll before timeout (5 minutes)
    static let qrProvisioningTimeout: TimeInterval = 300

    /// Server URL for provisioning polling (demo)
    static let provisioningServerURL = "https://dev-api.healthwatch.example"
}
