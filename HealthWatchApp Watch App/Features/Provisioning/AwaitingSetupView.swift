import SwiftUI

struct AwaitingSetupView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "applewatch.and.arrow.forward")
                .font(.system(size: 36))
                .foregroundStyle(.blue)

            Text("HealthWatch")
                .font(.headline)

            Text("Open the HealthWatch app on iPhone to set up this watch.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    AwaitingSetupView()
}
