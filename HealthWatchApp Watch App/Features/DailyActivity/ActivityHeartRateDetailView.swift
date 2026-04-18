import SwiftUI
import Charts

struct ActivityHeartRateDetailView: View {
    @ObservedObject var viewModel: DailyActivityViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                VStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                    Text(viewModel.heartRate.formattedCurrent)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    if viewModel.heartRate.current != nil {
                        Text("BPM")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                // Stats row
                HStack(spacing: 0) {
                    statItem(label: "Resting", value: viewModel.heartRate.resting.map { "\(Int($0))" } ?? "--", color: .pink)
                    Divider().frame(height: 30)
                    statItem(label: "Range", value: viewModel.heartRate.rangeText, color: .red)
                }
                .padding(10)
                .background(Color(.darkGray).opacity(0.3))
                .cornerRadius(12)

                // Line chart
                if viewModel.heartRateHistory.count >= 2 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last 3 Hours")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Chart(viewModel.heartRateHistory) { point in
                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("BPM", point.value)
                            )
                            .foregroundStyle(.red.opacity(0.8))
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Time", point.date),
                                y: .value("BPM", point.value)
                            )
                            .foregroundStyle(.red.opacity(0.15))
                            .interpolationMethod(.catmullRom)
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
                        .chartYAxis(.hidden)
                        .frame(height: 60)
                    }
                    .padding(10)
                    .background(Color(.darkGray).opacity(0.3))
                    .cornerRadius(12)
                }

                if let date = viewModel.heartRate.lastReadingDate {
                    Text("Last reading: \(date, format: .dateTime.hour().minute())")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Heart Rate")
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .rounded).bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}
