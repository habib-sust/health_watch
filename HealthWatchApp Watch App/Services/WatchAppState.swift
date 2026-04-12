import SwiftUI
import Combine
import WatchKit

enum WatchMode {
    case unprovisioned
    case showingCode(deviceCode: String)
    case provisioned
    case error(WatchError)
}

enum SyncStatus {
    case idle
    case syncing
    case success
    case failed
}

@MainActor
final class WatchAppState: ObservableObject {
    static let shared = WatchAppState()

    @Published var mode: WatchMode = .unprovisioned
    @Published var lastSyncDate: Date?
    @Published var syncStatus: SyncStatus = .idle
    @Published var individualName: String?

    private let keychain = KeychainManager()

    func initialize() {
        if let _ = try? keychain.loadProvisioningConfig() {
            mode = .provisioned
            individualName = UserDefaults.standard.string(forKey: "provisionedIndividualName")
            startDataCollection()
        } else {
            mode = .unprovisioned
        }
    }

    /// Generate a pairing code and transition to code display mode
    func beginProvisioning() {
        let code = Self.getOrCreateDeviceCode()
        mode = .showingCode(deviceCode: code)
    }

    /// Cancel provisioning and return to unprovisioned
    func cancelProvisioning() {
        mode = .unprovisioned
    }

    /// Complete provisioning with config received from server polling
    func completeProvisioning(with config: DeviceConfigResponse) {
        guard let serverURL = config.serverURL,
              let individualId = config.individualId,
              let authToken = config.authToken else {
            print("[WatchAppState] Incomplete provisioning config")
            return
        }

        do {
            try keychain.saveServerURL(serverURL)
            try keychain.saveIndividualId(individualId)
            try keychain.saveAuthToken(authToken)
        } catch {
            print("[WatchAppState] Keychain save failed: \(error.localizedDescription)")
            handleError(.keychainFailed)
            return
        }

        individualName = config.individualName
        if let name = config.individualName {
            UserDefaults.standard.set(name, forKey: "provisionedIndividualName")
        }
        mode = .provisioned
        startDataCollection()
    }

    // MARK: - Device Code

    /// Get or create a persistent 8-character device code used for pairing
    static func getOrCreateDeviceCode() -> String {
        let key = "healthwatch.deviceCode"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        // Generate a random 8-character hex code (e.g., "A3B79F2E")
        let bytes = (0..<4).map { _ in UInt8.random(in: 0...255) }
        let code = bytes.map { String(format: "%02X", $0) }.joined()
        UserDefaults.standard.set(code, forKey: key)
        return code
    }

    /// Formatted device code for display (e.g., "A3B7-9F2E")
    static func formattedDeviceCode(_ code: String) -> String {
        guard code.count == 8 else { return code }
        let idx = code.index(code.startIndex, offsetBy: 4)
        return "\(code[..<idx])-\(code[idx...])"
    }

    /// Start HealthKit collection and background scheduling after provisioning
    func startDataCollection() {
        Task {
            do {
                try await HealthKitCollector.shared.requestAuthorization()
                HealthKitCollector.shared.restoreAnchors()
                HealthKitCollector.shared.enableBackgroundDelivery()

                // Set up callback for observer-triggered samples
                HealthKitCollector.shared.onNewSamplesReceived = { samples in
                    let batchId = UUID()
                    LocalBufferManager.shared.buffer(samples, batchId: batchId)
                }

                BackgroundTaskScheduler.shared.scheduleNextRefresh()
                print("[WatchAppState] Data collection started")
            } catch {
                print("[WatchAppState] HealthKit authorization failed: \(error)")
            }
        }
    }

    func handleError(_ error: WatchError) {
        mode = .error(error)
    }

    // MARK: - Recovery

    /// Re-provisioning: clear all data and return to unprovisioned state
    func resetToUnprovisioned() {
        HealthKitCollector.shared.stopObserverQueries()
        HealthKitCollector.shared.clearDeduplicationCache()
        LocalBufferManager.shared.clearAllBufferedData()
        try? keychain.clearAll()
        UserDefaults.standard.removeObject(forKey: "provisionedIndividualName")
        individualName = nil
        lastSyncDate = nil
        syncStatus = .idle
        mode = .unprovisioned
    }

    /// Handle storage-full: purge oldest buffered data and resume
    func handleStoragePressure() {
        LocalBufferManager.shared.purgeExpired()
        // If still too large after purge, clear transmitted batches aggressively
        if LocalBufferManager.shared.bufferedCount() > AppConstants.maxBufferedSamplesPerCycle * 2 {
            LocalBufferManager.shared.clearAllBufferedData()
        }
    }

    /// Recover from network failure — stays in provisioned mode, sync status shows failed
    func handleNetworkFailure() {
        syncStatus = .failed
        // Data stays buffered for next cycle — no state change needed
    }

    /// Attempt to recover from token-revoked error by re-provisioning
    func recoverFromTokenRevoked() {
        resetToUnprovisioned()
    }
}
