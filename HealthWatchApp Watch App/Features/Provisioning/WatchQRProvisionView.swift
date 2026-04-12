import SwiftUI

/// Displays a QR code containing the device ID and polls the server for provisioning config.
/// The QR payload matches the format expected by the iOS scanner:
/// {"app":"healthwatch","version":1,"deviceId":"XXXXXXXX"}
struct WatchProvisionCodeView: View {
    let deviceCode: String
    @EnvironmentObject var appState: WatchAppState

    @State private var isPolling = false
    @State private var pollingStatus = "Waiting for pairing..."
    @State private var pollTask: Task<Void, Never>?
    @State private var qrMatrix: [[Bool]]?

    private let poller = DeviceConfigPoller()

    /// JSON payload encoded in the QR code
    private var qrPayload: String {
        "{\"app\":\"healthwatch\",\"version\":1,\"deviceId\":\"\(deviceCode)\"}"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let matrix = qrMatrix {
                    QRMatrixView(matrix: matrix)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .padding(.horizontal, 4)
                } else {
                    ProgressView("Generating QR...")
                        .frame(height: 120)
                }

                Text(WatchAppState.formattedDeviceCode(deviceCode))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)

                if isPolling {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text(pollingStatus)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Cancel") {
                    cancelProvisioning()
                }
                .foregroundColor(.red)
                .font(.caption)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .onAppear {
            generateQR()
            startPolling()
        }
        .onDisappear {
            cancelProvisioning()
        }
    }

    // MARK: - QR Generation

    private func generateQR() {
        qrMatrix = QRCodeGenerator.generate(from: qrPayload)
    }

    // MARK: - Server Polling

    private func startPolling() {
        isPolling = true
        pollingStatus = "Waiting for pairing..."

        pollTask = Task {
            let config = await poller.startPolling(deviceId: deviceCode)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                isPolling = false
                if let config {
                    appState.completeProvisioning(with: config)
                } else {
                    pollingStatus = "Timed out. Try again."
                }
            }
        }
    }

    private func cancelProvisioning() {
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

// MARK: - QR Matrix Renderer

/// Renders a boolean QR matrix using Canvas, with a quiet zone border.
private struct QRMatrixView: View {
    let matrix: [[Bool]]
    private let quietZone = 2

    var body: some View {
        Canvas { context, size in
            let modules = matrix.count + quietZone * 2
            let moduleSize = min(size.width, size.height) / CGFloat(modules)
            let totalSize = moduleSize * CGFloat(modules)
            let offsetX = (size.width - totalSize) / 2
            let offsetY = (size.height - totalSize) / 2

            // White background
            context.fill(
                Path(CGRect(x: offsetX, y: offsetY, width: totalSize, height: totalSize)),
                with: .color(.white)
            )

            // Dark modules
            let qzOffset = CGFloat(quietZone) * moduleSize
            for row in 0..<matrix.count {
                for col in 0..<matrix[row].count {
                    guard matrix[row][col] else { continue }
                    let rect = CGRect(
                        x: offsetX + qzOffset + CGFloat(col) * moduleSize,
                        y: offsetY + qzOffset + CGFloat(row) * moduleSize,
                        width: ceil(moduleSize),
                        height: ceil(moduleSize)
                    )
                    context.fill(Path(rect), with: .color(.black))
                }
            }
        }
    }
}
