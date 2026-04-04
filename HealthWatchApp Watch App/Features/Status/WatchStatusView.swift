import SwiftUI

struct WatchStatusView: View {
    @EnvironmentObject var appState: WatchAppState

    var body: some View {
        VStack(spacing: 12) {
            syncIcon
                .font(.system(size: 32))

            if let name = appState.individualName {
                Text(name)
                    .font(.headline)
            }

            Text(syncLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let lastSync = appState.lastSyncDate {
                Text("Last sync: \(lastSync, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [syncLabel]
        if let name = appState.individualName {
            parts.insert("Monitoring \(name)", at: 0)
        }
        return parts.joined(separator: ". ")
    }

    @ViewBuilder
    private var syncIcon: some View {
        switch appState.syncStatus {
        case .idle:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.green)
        case .syncing:
            ProgressView()
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
    }

    private var syncLabel: String {
        switch appState.syncStatus {
        case .idle:
            return "Monitoring Active"
        case .syncing:
            return "Syncing..."
        case .success:
            return "Sync Complete"
        case .failed:
            return "Sync Failed — Will Retry"
        }
    }
}
