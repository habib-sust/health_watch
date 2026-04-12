import SwiftUI

struct WatchUnprovisionedView: View {
    @EnvironmentObject var appState: WatchAppState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "qrcode")
                .font(.system(size: 36))
                .foregroundStyle(.blue)

            Text("HealthWatch")
                .font(.headline)

            Text("Tap below to generate a pairing code, then enter it in the HealthWatch iPhone app.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                appState.beginProvisioning()
            } label: {
                Label("Provision", systemImage: "link.badge.plus")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }
}
