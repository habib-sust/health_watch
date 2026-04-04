import SwiftUI

struct WatchCodeEntryView: View {
    let individualName: String?
    @EnvironmentObject var appState: WatchAppState
    @State private var enteredCode = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 8) {
            if let name = individualName {
                Text("Setup for")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(name)
                    .font(.headline)
                    .lineLimit(1)
            }

            Text("Enter 4-digit code")
                .font(.caption)

            SecureField("Code", text: $enteredCode)
                .multilineTextAlignment(.center)
                .font(.title2.monospacedDigit())

            Button("Confirm") {
                submitCode()
            }
            .disabled(enteredCode.count != 4 || isSubmitting)
        }
        .padding()
    }

    private func submitCode() {
        isSubmitting = true
        WatchConnectivityHandler.shared.sendCodeToiOS(enteredCode)
    }
}
