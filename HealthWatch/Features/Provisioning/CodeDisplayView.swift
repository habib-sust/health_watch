import SwiftUI
import Combine

struct CodeDisplayView: View {
    let code: String
    let expiresAt: Date

    @State private var timeRemaining: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Verification Code")
                .font(.title2.bold())

            // Display each digit in a box
            HStack(spacing: 12) {
                ForEach(Array(code), id: \.self) { digit in
                    Text(String(digit))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .frame(width: 56, height: 68)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray3), lineWidth: 1)
                        )
                }
            }

            Text("Enter this code on the Apple Watch")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Countdown timer
            if timeRemaining > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("Expires in \(Int(timeRemaining))s")
                }
                .font(.caption)
                .foregroundStyle(timeRemaining < 30 ? .red : .secondary)
            } else {
                Text("Code expired")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding()
        .onReceive(timer) { _ in
            timeRemaining = max(0, expiresAt.timeIntervalSinceNow)
        }
        .onAppear {
            timeRemaining = max(0, expiresAt.timeIntervalSinceNow)
        }
    }
}
