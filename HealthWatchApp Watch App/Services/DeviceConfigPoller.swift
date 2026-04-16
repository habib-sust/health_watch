import Foundation
import os

/// Response model for the device config polling endpoint
struct DeviceConfigResponse: Codable {
    let status: String
    let serverURL: String?
    let individualId: String?
    let individualName: String?
    let authToken: String?

    var isProvisioned: Bool { status == "provisioned" }
}

/// Polls the server for device provisioning configuration.
/// When `useMockResponse` is true, returns a mock config after a short delay instead of calling the server.
final class DeviceConfigPoller {
    private var isPolling = false

    /// Set to `false` once a real server is available
    var useMockResponse = true

    /// Start polling for device config. Returns when config is available, or nil on timeout/cancellation.
    func startPolling(deviceId: String) async -> DeviceConfigResponse? {
        isPolling = true
        Logger.provisioning.info("Start polling for deviceId: \(deviceId), mock: \(self.useMockResponse)")

        if useMockResponse {
            return await pollMock(deviceId: deviceId)
        }

        return await pollServer(deviceId: deviceId)
    }

    func stopPolling() {
        Logger.provisioning.info("Polling stopped")
        isPolling = false
    }

    // MARK: - Mock Polling

    /// Simulates a server response after a brief delay
    private func pollMock(deviceId: String) async -> DeviceConfigResponse? {
        Logger.provisioning.info("Mock polling — simulating 3s network delay for device: \(deviceId)")
        do {
            try await Task.sleep(nanoseconds: 3_000_000_000)
        } catch {
            Logger.provisioning.info("Mock polling cancelled during sleep")
            return nil
        }

        guard isPolling else {
            Logger.provisioning.info("Mock polling aborted — polling was stopped")
            return nil
        }

        let config = DeviceConfigResponse(
            status: "provisioned",
            serverURL: AppConstants.provisioningServerURL,
            individualId: "mock-individual-001",
            individualName: "Demo User",
            authToken: "mock-auth-token-\(deviceId)"
        )
        Logger.provisioning.info("Mock config returned — status: \(config.status), individualId: \(config.individualId ?? "nil"), individualName: \(config.individualName ?? "nil")")
        return config
    }

    // MARK: - Server Polling

    private func pollServer(deviceId: String) async -> DeviceConfigResponse? {
        let startTime = Date()
        let timeout = AppConstants.qrProvisioningTimeout
        let interval = AppConstants.qrPollingInterval
        let serverURL = AppConstants.provisioningServerURL

        Logger.provisioning.info("Server polling started — serverURL: \(serverURL), timeout: \(Int(timeout))s, interval: \(interval)s")

        var attempt = 0
        while isPolling {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= timeout {
                Logger.provisioning.warning("Polling timed out after \(Int(elapsed))s (\(attempt) attempts)")
                return nil
            }

            attempt += 1
            Logger.provisioning.debug("Poll attempt \(attempt) for device \(deviceId) (elapsed: \(Int(elapsed))s)")

            if let config = await fetchConfig(deviceId: deviceId, serverURL: serverURL) {
                if config.isProvisioned {
                    Logger.provisioning.info("Device provisioned on attempt \(attempt) — individualId: \(config.individualId ?? "nil"), individualName: \(config.individualName ?? "nil")")
                    return config
                }
                Logger.provisioning.debug("Config received but status is '\(config.status)' — not yet provisioned")
            }

            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            } catch {
                Logger.provisioning.info("Server polling cancelled during sleep")
                return nil
            }
        }

        Logger.provisioning.info("Server polling stopped externally")
        return nil
    }

    private func fetchConfig(deviceId: String, serverURL: String) async -> DeviceConfigResponse? {
        let urlString = "\(serverURL)/api/v1/device/\(deviceId)/config"
        guard let url = URL(string: urlString) else {
            Logger.provisioning.error("Invalid URL: \(urlString)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.provisioning.error("Response is not HTTPURLResponse")
                return nil
            }

            Logger.provisioning.debug("GET \(urlString) — status: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 200 {
                let config = try JSONDecoder.healthWatch.decode(DeviceConfigResponse.self, from: data)
                Logger.provisioning.info("Config decoded — status: \(config.status)")
                return config
            } else if httpResponse.statusCode == 404 {
                Logger.provisioning.debug("Device \(deviceId) not yet registered (404)")
                return nil
            } else {
                Logger.provisioning.warning("Unexpected HTTP status: \(httpResponse.statusCode)")
                return nil
            }
        } catch {
            Logger.provisioning.error("Fetch failed for \(deviceId): \(error.localizedDescription)")
            return nil
        }
    }
}
