import SwiftUI

struct HealthOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    var onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "heart.text.clipboard")
                    .font(.system(size: 36))
                    .foregroundStyle(.red)
                    .padding(.top, 8)

                Text("Health Data Access")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    featureRow(
                        icon: "figure.walk",
                        color: .green,
                        title: "Steps",
                        description: "Track daily step count toward your goal"
                    )
                    featureRow(
                        icon: "heart.fill",
                        color: .red,
                        title: "Heart Rate",
                        description: "Monitor current and resting heart rate"
                    )
                    featureRow(
                        icon: "bed.double.fill",
                        color: .indigo,
                        title: "Sleep",
                        description: "Review sleep duration and quality"
                    )
                }

                Text("Therap uses this data to help staff monitor your well-being. Your data stays on this device and is never shared without your knowledge.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)

                Button {
                    dismiss()
                    onContinue()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(.horizontal, 8)
        }
    }

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
