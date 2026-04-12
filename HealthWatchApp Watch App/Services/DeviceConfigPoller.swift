import Foundation

/// Response model for the device config polling endpoint
struct DeviceConfigResponse: Codable {
    let status: String
    let serverURL: String?
    let individualId: String?
    let individualName: String?
    let authToken: String?

    var isProvisioned: Bool { status == "provisioned" }
}

/// Polls the server for device provisioning configuration
final class DeviceConfigPoller {
    private var isPolling = false

    /// Start polling for device config. Returns when config is available, or nil on timeout/cancellation.
    func startPolling(deviceId: String) async -> DeviceConfigResponse? {
        isPolling = true
        let startTime = Date()
        let timeout = AppConstants.qrProvisioningTimeout
        let interval = AppConstants.qrPollingInterval
        let serverURL = AppConstants.provisioningServerURL

        while isPolling {
            // Check timeout
            if Date().timeIntervalSince(startTime) >= timeout {
                print("[DeviceConfigPoller] Polling timed out after \(Int(timeout))s")
                return nil
            }

            // Poll the server
            if let config = await fetchConfig(deviceId: deviceId, serverURL: serverURL) {
                if config.isProvisioned {
                    print("[DeviceConfigPoller] Device provisioned!")
                    return config
                }
            }

            // Wait before next poll
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            } catch {
                // Task was cancelled
                return nil
            }
        }

        return nil
    }

    func stopPolling() {
        isPolling = false
    }

    private func fetchConfig(deviceId: String, serverURL: String) async -> DeviceConfigResponse? {
        guard let url = URL(string: "\(serverURL)/api/v1/device/\(deviceId)/config") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return nil }

            if httpResponse.statusCode == 200 {
                return try JSONDecoder.healthWatch.decode(DeviceConfigResponse.self, from: data)
            } else if httpResponse.statusCode == 404 {
                // Device not yet registered — continue polling
                return nil
            } else {
                print("[DeviceConfigPoller] Unexpected status: \(httpResponse.statusCode)")
                return nil
            }
        } catch {
            print("[DeviceConfigPoller] Fetch failed: \(error.localizedDescription)")
            return nil
        }
    }
}
