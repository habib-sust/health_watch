import SwiftUI

struct ProvisioningStatusView: View {
    let icon: String
    let title: String
    let subtitle: String
    var isLoading: Bool = false
    var iconColor: Color = .blue
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .padding(.bottom, 8)
            }

            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
    }
}
