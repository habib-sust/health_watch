import SwiftUI

struct StatusIndicator: View {
    let status: IndividualStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .accessibilityLabel("Status: \(status.rawValue)")
    }

    private var color: Color {
        switch status {
        case .normal:
            return .green
        case .attention:
            return .yellow
        case .offline:
            return .gray
        }
    }
}
