import SwiftUI
import Charts

/// Full-screen heart rate detail with line chart and min/max/avg stats.
struct HeartRateDetailView: View {
    @ObservedObject var viewModel: WatchHealthDataViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                currentReading
                chartSection
                statsGrid
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Heart Rate")
    }

    // MARK: - Current Reading

    private var currentReading: some View {
        VStack(spacing: 2) {
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundStyle(.red)

            if let current = viewModel.heartRateStats.current {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(current))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("BPM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("--")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let updated = viewModel.heartRateStats.lastUpdated {
                Text(updated, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                + Text(" ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last 3 Hours")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            if viewModel.heartRateHistory.count >= 2 {
                Chart(viewModel.heartRateHistory) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("BPM", point.value)
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Time", point.date),
                        y: .value("BPM", point.value)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.red.opacity(0.3), .red.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))")
                                    .font(.system(size: 8))
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.hour().minute())
                                    .font(.system(size: 8))
                            }
                        }
                    }
                }
                .frame(height: 100)
            } else {
                Text("Not enough data to display chart")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .padding(10)
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today's Range")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                statItem(label: "Min", value: viewModel.heartRateStats.min, color: .blue)
                Divider().frame(height: 30)
                statItem(label: "Avg", value: viewModel.heartRateStats.avg, color: .yellow)
                Divider().frame(height: 30)
                statItem(label: "Max", value: viewModel.heartRateStats.max, color: .red)
            }
        }
        .padding(10)
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(12)
    }

    private func statItem(label: String, value: Double?, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(value.map { "\(Int($0))" } ?? "--")
                .font(.system(.body, design: .rounded).bold())
                .foregroundStyle(color)
            Text("BPM")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
