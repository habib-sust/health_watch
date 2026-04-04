import SwiftUI
import Charts

struct HealthMetricChartView: View {
    let title: String
    let samples: [HealthSample]
    let unit: String
    let color: Color
    let chartStyle: ChartStyle

    enum ChartStyle {
        case line
        case bar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if let latest = samples.last {
                    Text("\(formattedValue(latest.value)) \(unit)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if samples.isEmpty {
                Text("No data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(samples) { sample in
                    switch chartStyle {
                    case .line:
                        LineMark(
                            x: .value("Time", sample.startDate),
                            y: .value(title, sample.value)
                        )
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)
                    case .bar:
                        BarMark(
                            x: .value("Time", sample.startDate),
                            y: .value(title, sample.value)
                        )
                        .foregroundStyle(color.gradient)
                    }
                }
                .frame(height: 150)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func formattedValue(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
