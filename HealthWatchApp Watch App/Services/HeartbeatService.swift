import Foundation
import WatchKit
import os

/// Sends periodic heartbeats to the server for absence detection.
/// Piggybacks on the data push cycle or runs standalone if no data.
final class HeartbeatService {
    static let shared = HeartbeatService()

    func sendHeartbeat() async {
        let keychain = KeychainManager()
        guard let config = try? keychain.loadProvisioningConfig() else {
            Logger.sync.warning("No provisioning config — skipping heartbeat")
            return
        }

        let deviceId = WKInterfaceDevice.current().identifierForVendor?.uuidString ?? "unknown"
        let batteryLevel = WKInterfaceDevice.current().batteryLevel
        let bufferSize = LocalBufferManager.shared.bufferedCount()

        let heartbeat = HeartbeatPayload(
            individualId: config.individualId,
            deviceId: deviceId,
            batteryLevel: Double(batteryLevel),
            bufferSize: bufferSize,
            lastPushTimestamp: UserDefaults.standard.object(forKey: "lastSuccessfulPush") as? Date,
            timestamp: Date()
        )

        guard let body = try? JSONEncoder.healthWatch.encode(heartbeat),
              let url = URL(string: "\(config.serverURL)/api/v1/device/heartbeat")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                Logger.sync.info("Heartbeat sent successfully")
            }
        } catch {
            Logger.sync.error("Heartbeat failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

struct HeartbeatPayload: Codable {
    let individualId: String
    let deviceId: String
    let batteryLevel: Double
    let bufferSize: Int
    let lastPushTimestamp: Date?
    let timestamp: Date
}
