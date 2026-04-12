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

/// Polls the server for device provisioning configuration.
/// When `useMockResponse` is true, returns a mock config after a short delay instead of calling the server.
final class DeviceConfigPoller {
    private var isPolling = false

    /// Set to `false` once a real server is available
    var useMockResponse = true

    /// Start polling for device config. Returns when config is available, or nil on timeout/cancellation.
    func startPolling(deviceId: String) async -> DeviceConfigResponse? {
        isPolling = true

        if useMockResponse {
            return await pollMock(deviceId: deviceId)
        }

        return await pollServer(deviceId: deviceId)
    }

    func stopPolling() {
        isPolling = false
    }

    // MARK: - Mock Polling

    /// Simulates a server response after a brief delay
    private func pollMock(deviceId: String) async -> DeviceConfigResponse? {
        // Simulate network delay so the user sees the QR code briefly
        do {
            try await Task.sleep(nanoseconds: 3_000_000_000)
        } catch {
            return nil
        }

        guard isPolling else { return nil }

        print("[DeviceConfigPoller] Returning mock provisioning config for device: \(deviceId)")
        return DeviceConfigResponse(
            status: "provisioned",
            serverURL: AppConstants.provisioningServerURL,
            individualId: "mock-individual-001",
            individualName: "Demo User",
            authToken: "mock-auth-token-\(deviceId)"
        )
    }

    // MARK: - Server Polling

    private func pollServer(deviceId: String) async -> DeviceConfigResponse? {
        let startTime = Date()
        let timeout = AppConstants.qrProvisioningTimeout
        let interval = AppConstants.qrPollingInterval
        let serverURL = AppConstants.provisioningServerURL

        while isPolling {
            if Date().timeIntervalSince(startTime) >= timeout {
                print("[DeviceConfigPoller] Polling timed out after \(Int(timeout))s")
                return nil
            }

            if let config = await fetchConfig(deviceId: deviceId, serverURL: serverURL) {
                if config.isProvisioned {
                    print("[DeviceConfigPoller] Device provisioned!")
                    return config
                }
            }

            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            } catch {
                return nil
            }
        }

        return nil
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
