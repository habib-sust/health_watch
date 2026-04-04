import SwiftUI

struct IndividualCardView: View {
    let individual: IndividualSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(individual.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                StatusIndicator(status: individual.status)
            }

            if let heartRate = individual.latestHeartRate {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text("\(Int(heartRate)) BPM")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let lastSync = individual.lastSyncDate {
                Text("Synced \(lastSync, style: .relative) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No data yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [individual.name, "Status: \(individual.status.rawValue)"]
        if let hr = individual.latestHeartRate {
            parts.append("Heart rate: \(Int(hr)) BPM")
        }
        if individual.lastSyncDate != nil {
            parts.append("Recently synced")
        } else {
            parts.append("No data yet")
        }
        return parts.joined(separator: ", ")
    }
}
