import SwiftUI
import Combine
import WatchKit
import os

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
    @Published var healthAuthDone = false
    @Published var healthAuthStatus: HealthAuthStatus = .notDetermined

    private let keychain = KeychainManager()

    func initialize() {
        Task {
            // Check health authorization first
            healthAuthStatus = await HealthKitService.shared.checkAuthorizationStatus()
            healthAuthDone = true

            if let _ = try? keychain.loadProvisioningConfig() {
                mode = .provisioned
                individualName = UserDefaults.standard.string(forKey: "provisionedIndividualName")
                Logger.provisioning.info("Initialized — already provisioned for \(self.individualName ?? "unknown")")
                startDataCollection()
            } else {
                mode = .unprovisioned
                Logger.provisioning.info("Initialized — unprovisioned")
            }
        }
    }

    func grantHealthAccess() async {
        do {
            try await HealthKitService.shared.requestAuthorization()
            healthAuthStatus = await HealthKitService.shared.checkAuthorizationStatus()
            if healthAuthStatus == .authorized {
                HealthKitCollector.shared.enableBackgroundDelivery()
            }
        } catch {
            Logger.healthKit.error("[WatchAppState] Health authorization error: \(error.localizedDescription)")
        }
    }

    /// Generate a pairing code and transition to code display mode
    func beginProvisioning() {
        let code = Self.getOrCreateDeviceCode()
        Logger.provisioning.info("Begin provisioning — deviceCode: \(code)")
        mode = .showingCode(deviceCode: code)
    }

    /// Cancel provisioning and return to unprovisioned
    func cancelProvisioning() {
        Logger.provisioning.info("Provisioning cancelled by user")
        mode = .unprovisioned
    }

    /// Complete provisioning with config received from server polling
    func completeProvisioning(with config: DeviceConfigResponse) {
        Logger.provisioning.info("Completing provisioning — status: \(config.status), individualId: \(config.individualId ?? "nil"), individualName: \(config.individualName ?? "nil")")

        guard let serverURL = config.serverURL,
              let individualId = config.individualId,
              let authToken = config.authToken else {
            Logger.provisioning.error("Incomplete provisioning config — serverURL: \(config.serverURL ?? "nil"), individualId: \(config.individualId ?? "nil"), authToken: \(config.authToken != nil ? "present" : "nil")")
            return
        }

        do {
            try keychain.saveServerURL(serverURL)
            try keychain.saveIndividualId(individualId)
            try keychain.saveAuthToken(authToken)
            Logger.provisioning.info("Keychain saved — serverURL: \(serverURL), individualId: \(individualId)")
        } catch {
            Logger.provisioning.error("Keychain save failed: \(error.localizedDescription)")
            handleError(.keychainFailed)
            return
        }

        individualName = config.individualName
        if let name = config.individualName {
            UserDefaults.standard.set(name, forKey: "provisionedIndividualName")
        }
        mode = .provisioned
        Logger.provisioning.info("Provisioning complete — starting data collection")
        startDataCollection()
    }

    // MARK: - Device Code

    /// Get or create a persistent 8-character device code used for pairing
    static func getOrCreateDeviceCode() -> String {
        let key = "healthwatch.deviceCode"
        if let existing = UserDefaults.standard.string(forKey: key) {
            Logger.provisioning.debug("Using existing device code: \(existing)")
            return existing
        }
        let bytes = (0..<4).map { _ in UInt8.random(in: 0...255) }
        let code = bytes.map { String(format: "%02X", $0) }.joined()
        UserDefaults.standard.set(code, forKey: key)
        Logger.provisioning.info("Generated new device code: \(code)")
        return code
    }

    /// Formatted device code for display (e.g., "A3B7-9F2E")
    static func formattedDeviceCode(_ code: String) -> String {
        guard code.count == 8 else { return code }
        let idx = code.index(code.startIndex, offsetBy: 4)
        return "\(code[..<idx])-\(code[idx...])"
    }

    /// Start HealthKit collection and background scheduling after provisioning.
    /// Note: HealthKit authorization is deferred to DailyActivityView's onboarding
    /// flow so the user sees our explanation page before the system permission alert.
    func startDataCollection() {
        Logger.provisioning.info("Starting data collection pipeline (auth deferred to onboarding)")

        HealthKitCollector.shared.restoreAnchors()
        HealthKitCollector.shared.enableBackgroundDelivery()
        Logger.provisioning.info("HealthKit observer queries and background delivery enabled")

        HealthKitCollector.shared.onNewSamplesReceived = { samples in
            let batchId = UUID()
            Logger.provisioning.debug("Received \(samples.count) new samples — batchId: \(batchId)")
            LocalBufferManager.shared.buffer(samples, batchId: batchId)
        }

        BackgroundTaskScheduler.shared.scheduleNextRefresh()
        Logger.provisioning.info("Data collection started successfully")
    }

    func handleError(_ error: WatchError) {
        Logger.provisioning.error("Watch error: \(String(describing: error))")
        mode = .error(error)
    }

    // MARK: - Recovery

    /// Re-provisioning: clear all data and return to unprovisioned state.
    /// Set `notifyPhone` to true when the user initiates from the watch,
    /// false when the reset is triggered by an incoming deprovision message from the phone.
    func resetToUnprovisioned(notifyPhone: Bool = true) {
        Logger.provisioning.info("Resetting to unprovisioned state — clearing all data (notifyPhone: \(notifyPhone))")
        HealthKitCollector.shared.stopObserverQueries()
        HealthKitCollector.shared.clearDeduplicationCache()
        LocalBufferManager.shared.clearAllBufferedData()
        try? keychain.clearAll()
        UserDefaults.standard.removeObject(forKey: "provisionedIndividualName")
        individualName = nil
        lastSyncDate = nil
        syncStatus = .idle
        mode = .unprovisioned

        if notifyPhone {
            WatchConnectivityHandler.shared.sendDeprovision()
            Logger.provisioning.info("Deprovision message sent to phone")
        }

        Logger.provisioning.info("Reset complete — watch is unprovisioned")
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
