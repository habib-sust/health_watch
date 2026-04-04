import SwiftUI
import Charts

struct WatchMetricCardView: View {
    let metric: WatchHealthMetric

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: metric.icon)
                .font(.body)
                .foregroundStyle(metricColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(metric.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let value = metric.latestValue {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(formattedValue(value))
                            .font(.system(.body, design: .rounded).bold())
                        Text(metric.unit)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("--")
                        .font(.body.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if #available(watchOS 9.0, *), metric.recentValues.count >= 2 {
                sparkline
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Sparkline

    @available(watchOS 9.0, *)
    private var sparkline: some View {
        Chart {
            ForEach(Array(metric.recentValues.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(metricColor)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(width: 40, height: 24)
    }

    // MARK: - Helpers

    private var metricColor: Color {
        switch metric.color {
        case "red": return .red
        case "blue": return .blue
        case "orange": return .orange
        case "teal": return .teal
        default: return .primary
        }
    }

    private func formattedValue(_ value: Double) -> String {
        if metric.id.contains("StepCount") {
            if value >= 10_000 {
                return String(format: "%.1fk", value / 1000.0)
            }
            return String(Int(value))
        }
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private var accessibilityDescription: String {
        if let value = metric.latestValue {
            return "\(metric.displayName): \(formattedValue(value)) \(metric.unit)"
        }
        return "\(metric.displayName): No data available"
    }
}
