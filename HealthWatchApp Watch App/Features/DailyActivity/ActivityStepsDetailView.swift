import SwiftUI
import Charts

struct ActivityStepsDetailView: View {
    @ObservedObject var viewModel: DailyActivityViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                VStack(spacing: 2) {
                    Image(systemName: "figure.walk")
                        .font(.title3)
                        .foregroundStyle(.green)
                    Text(viewModel.steps.formattedTotal)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("of \(Int(viewModel.steps.goal)) goal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                // Hourly bar chart
                if !viewModel.hourlySteps.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hourly Steps")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Chart(viewModel.hourlySteps) { bucket in
                            BarMark(
                                x: .value("Hour", bucket.hour),
                                y: .value("Steps", bucket.steps)
                            )
                            .foregroundStyle(.green.opacity(0.7))
                            .cornerRadius(2)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: 6)) { value in
                                AxisValueLabel {
                                    if let hour = value.as(Int.self) {
                                        Text("\(hour)")
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
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Steps")
    }
}
