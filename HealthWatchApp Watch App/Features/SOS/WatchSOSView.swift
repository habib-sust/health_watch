import SwiftUI
import WatchKit

struct WatchSOSView: View {
    @State private var isSending = false
    @State private var sosSent = false

    var body: some View {
        VStack(spacing: 16) {
            if sosSent {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                Text("SOS Sent")
                    .font(.headline)
                Text("Staff has been notified")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button {
                    sendSOS()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "sos")
                            .font(.system(size: 36))
                        Text("Send SOS")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isSending)
            }
        }
        .navigationTitle("SOS")
    }

    private func sendSOS() {
        isSending = true
        WKInterfaceDevice.current().play(.notification)
        WatchConnectivityHandler.shared.sendSOS()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSending = false
            sosSent = true
        }

        // Reset after 5 seconds so user can send again
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            sosSent = false
        }
    }
}
