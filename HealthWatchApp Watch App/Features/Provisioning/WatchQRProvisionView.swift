import SwiftUI
import WatchKit
import QRCode
import os

/// Displays a QR code containing the device ID.
/// After the user scans the QR on the iPhone and taps "Done" here,
/// the watch starts polling the server for provisioning config.
struct WatchProvisionCodeView: View {
    let deviceCode: String
    @EnvironmentObject var appState: WatchAppState

    @State private var isPolling = false
    @State private var pollingStatus = ""
    @State private var pollTask: Task<Void, Never>?
    @State private var pairingComplete = false
    @State private var receivedConfig: DeviceConfigResponse?
    @State private var pollingFailed = false
    @State private var runtimeSession: WKExtendedRuntimeSession?

    private let poller = DeviceConfigPoller()

    /// JSON payload encoded in the QR code
    private var qrPayload: String {
        "{\"app\":\"healthwatch\",\"version\":1,\"deviceId\":\"\(deviceCode)\"}"
    }

    var body: some View {
        ScrollView {
            if pairingComplete {
                pairedView
            } else if isPolling {
                pollingView
            } else {
                qrCodeView
            }
        }
        .onAppear {
            startKeepAwakeSession()
        }
        .onDisappear {
            stopKeepAwakeSession()
            if !pairingComplete {
                cancelProvisioning()
            }
        }
    }

    // MARK: - QR Code View

    private var qrCodeView: some View {
        VStack(spacing: 8) {
            QRCodeViewUI(
                content: qrPayload,
                foregroundColor: CGColor(gray: 0, alpha: 1),
                backgroundColor: CGColor(gray: 1, alpha: 1),
                additionalQuietZonePixels: 2
            )
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 4)

            Text(WatchAppState.formattedDeviceCode(deviceCode))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("Scan this code with the HealthWatch iPhone app, then tap Done.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                startPolling()
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)

            Button("Cancel") {
                cancelProvisioning()
            }
            .foregroundColor(.red)
            .font(.caption)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    // MARK: - Polling View

    private var pollingView: some View {
        VStack(spacing: 12) {
            Spacer()

            ProgressView()
                .scaleEffect(1.2)

            Text("Connecting...")
                .font(.headline)

            Text(pollingStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if pollingFailed {
                Button("Retry") {
                    pollingFailed = false
                    startPolling()
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Cancel") {
                cancelProvisioning()
            }
            .foregroundColor(.red)
            .font(.caption)

            Spacer()
        }
        .padding()
    }

    // MARK: - Paired View

    private var pairedView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("Pairing Complete")
                .font(.headline)

            Text("Watch is now provisioned and ready to collect health data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                if let config = receivedConfig {
                    appState.completeProvisioning(with: config)
                }
            } label: {
                Label("Continue", systemImage: "arrow.right")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }

    // MARK: - Server Polling

    private func startPolling() {
        Logger.provisioning.info("User tapped Done — starting polling for device: \(deviceCode)")
        isPolling = true
        pollingFailed = false
        pollingStatus = "Verifying with server..."

        pollTask = Task {
            let config = await poller.startPolling(deviceId: deviceCode)

            guard !Task.isCancelled else {
                Logger.provisioning.info("Poll task cancelled")
                return
            }

            await MainActor.run {
                if let config {
                    Logger.provisioning.info("Polling succeeded — pairing complete for device: \(deviceCode)")
                    receivedConfig = config
                    pairingComplete = true
                    isPolling = false
                } else {
                    Logger.provisioning.warning("Polling returned nil — server unreachable or timed out")
                    pollingStatus = "Could not reach server. Try again."
                    pollingFailed = true
                }
            }
        }
    }

    // MARK: - Keep Awake Session

    private func startKeepAwakeSession() {
        let session = WKExtendedRuntimeSession()
        session.start()
        runtimeSession = session
        Logger.provisioning.info("Started extended runtime session to keep screen active during QR display")
    }

    private func stopKeepAwakeSession() {
        runtimeSession?.invalidate()
        runtimeSession = nil
        Logger.provisioning.info("Stopped extended runtime session")
    }

    private func cancelProvisioning() {
        Logger.provisioning.info("User cancelled provisioning from QR view")
        poller.stopPolling()
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
        appState.cancelProvisioning()
    }
}

#Preview {
    WatchProvisionCodeView(deviceCode: "A3B79F2E")
        .environmentObject(WatchAppState.shared)
}
