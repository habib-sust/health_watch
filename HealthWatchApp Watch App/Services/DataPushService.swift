import Foundation
import WatchKit

final class DataPushService: NSObject {
    static let shared = DataPushService()

    private static let backgroundSessionIdentifier = "com.company.healthwatch.push"

    /// Tracks batch IDs for in-flight uploads so we can clear them on success
    private var inFlightBatches: [Int: UUID] = [:]  // taskIdentifier -> batchId

    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(
            withIdentifier: Self.backgroundSessionIdentifier
        )
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    /// Called by ExtensionDelegate when watchOS wakes us for a background URL session event
    func handleBackgroundURLSession(identifier: String) -> Bool {
        guard identifier == Self.backgroundSessionIdentifier else { return false }
        // Accessing backgroundSession triggers the lazy initialization,
        // which reconnects the delegate to the existing session
        let _ = backgroundSession
        return true
    }

    // MARK: - Collect and Push Pipeline

    func collectAndPush() async {
        // 1. Fetch new samples from HealthKit
        let newSamples = await HealthKitCollector.shared.fetchAllNewSamples()

        // 2. Load previously buffered (untransmitted) samples
        let buffered = LocalBufferManager.shared.loadBuffered()

        // 3. Combine and limit
        let allSamples = Array((newSamples + buffered).prefix(AppConstants.maxBufferedSamplesPerCycle))

        guard !allSamples.isEmpty else {
            print("[DataPushService] No samples to push")
            return
        }

        // 4. Load provisioning config from Keychain
        let keychain = KeychainManager()
        guard let config = try? keychain.loadProvisioningConfig() else {
            print("[DataPushService] No provisioning config — cannot push")
            return
        }

        // 5. Build payload
        let batchId = UUID()
        let payload = HealthPayload(
            individualId: config.individualId,
            deviceId: WKInterfaceDevice.current().identifierForVendor?.uuidString ?? "unknown",
            timestamp: Date(),
            samples: allSamples,
            batchId: batchId
        )

        // 6. Serialize
        guard let body = try? JSONEncoder.healthWatch.encode(payload),
              let url = URL(string: "\(config.serverURL)/api/v1/health-data")
        else {
            print("[DataPushService] Failed to encode payload or build URL")
            return
        }

        // 7. Buffer samples locally in case push fails
        //    Only buffer the new samples (buffered ones are already stored)
        if !newSamples.isEmpty {
            LocalBufferManager.shared.buffer(newSamples, batchId: batchId)
        }

        // 8. Write body to temp file for background upload
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(batchId.uuidString + ".json")
        do {
            try body.write(to: tempFile)
        } catch {
            print("[DataPushService] Failed to write temp file: \(error)")
            return
        }

        // 9. Create background upload task
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.authToken)", forHTTPHeaderField: "Authorization")

        let task = backgroundSession.uploadTask(with: request, fromFile: tempFile)
        inFlightBatches[task.taskIdentifier] = batchId
        task.resume()

        print("[DataPushService] Pushed \(allSamples.count) samples (batch: \(batchId.uuidString.prefix(8)))")

        // 10. Update sync status
        await MainActor.run {
            WatchAppState.shared.syncStatus = .syncing
        }
    }
}

// MARK: - URLSessionDataDelegate

extension DataPushService: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let batchId = inFlightBatches.removeValue(forKey: task.taskIdentifier)

        if let error {
            print("[DataPushService] Upload failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                WatchAppState.shared.syncStatus = .failed
            }
            return
        }

        guard let http = task.response as? HTTPURLResponse else {
            DispatchQueue.main.async {
                WatchAppState.shared.syncStatus = .failed
            }
            return
        }

        if (200...299).contains(http.statusCode) {
            // Success — clear buffered data for this batch
            if let batchId {
                LocalBufferManager.shared.clearBatch(batchId)
            }
            DispatchQueue.main.async {
                WatchAppState.shared.syncStatus = .success
                WatchAppState.shared.lastSyncDate = Date()
            }
            print("[DataPushService] Upload succeeded (status: \(http.statusCode))")
        } else if http.statusCode == 401 {
            // Token revoked — enter error state
            DispatchQueue.main.async {
                WatchAppState.shared.handleError(.tokenRevoked)
            }
            print("[DataPushService] 401 — token revoked")
        } else {
            // Other failure — data stays buffered for next cycle
            DispatchQueue.main.async {
                WatchAppState.shared.syncStatus = .failed
            }
            print("[DataPushService] Upload failed (status: \(http.statusCode))")
        }

        // Clean up temp file
        if let batchId {
            let tempFile = FileManager.default.temporaryDirectory
                .appendingPathComponent(batchId.uuidString + ".json")
            try? FileManager.default.removeItem(at: tempFile)
        }
    }
}
