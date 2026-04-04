import SwiftUI

struct AlertsView: View {
    @StateObject private var viewModel = AlertsViewModel()

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.criticalAlerts.isEmpty {
                    Section("Critical") {
                        ForEach(viewModel.criticalAlerts) { alert in
                            AlertRowView(alert: alert)
                        }
                    }
                }

                if !viewModel.warningAlerts.isEmpty {
                    Section("Warning") {
                        ForEach(viewModel.warningAlerts) { alert in
                            AlertRowView(alert: alert)
                        }
                    }
                }

                if !viewModel.infoAlerts.isEmpty {
                    Section("Info") {
                        ForEach(viewModel.infoAlerts) { alert in
                            AlertRowView(alert: alert)
                        }
                    }
                }

                if viewModel.alerts.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Alerts",
                        systemImage: "checkmark.circle",
                        description: Text("All individuals are within normal parameters.")
                    )
                }
            }
            .navigationTitle("Alerts")
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }
}

private struct AlertRowView: View {
    let alert: AlertItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(alert.individualName)
                    .font(.headline)
                Text(alert.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(alert.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if alert.acknowledged {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
        .opacity(alert.acknowledged ? 0.6 : 1.0)
    }

    private var iconName: String {
        switch alert.severity {
        case .critical: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch alert.severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

#Preview {
    AlertsView()
}
