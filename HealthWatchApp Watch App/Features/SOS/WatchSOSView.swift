import SwiftUI
import WatchKit

struct WatchAssistanceView: View {
    @State private var isSending = false
    @State private var alertSent = false

    var body: some View {
        VStack(spacing: 16) {
            if alertSent {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                Text("Alert Sent")
                    .font(.headline)
                Text("Staff has been notified")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button {
                    sendAssistance()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 36))
                        Text("Request Assistance")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isSending)

                Text("If emergency, call 911")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Assistance")
    }

    private func sendAssistance() {
        isSending = true
        WKInterfaceDevice.current().play(.notification)
        WatchConnectivityHandler.shared.sendAssistance()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSending = false
            alertSent = true
        }

        // Reset after 5 seconds so user can send again
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            alertSent = false
        }
    }
}
