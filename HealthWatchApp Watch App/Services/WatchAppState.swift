import SwiftUI
import Combine

enum WatchMode {
    case unprovisioned
    case provisioning(ProvisioningMessage)
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

    func beginProvisioning(with message: ProvisioningMessage) {
        mode = .provisioning(message)
    }

    func completeProvisioning(individualName name: String?) {
        individualName = name
        if let name {
            UserDefaults.standard.set(name, forKey: "provisionedIndividualName")
        }
        mode = .provisioned
        startDataCollection()
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
