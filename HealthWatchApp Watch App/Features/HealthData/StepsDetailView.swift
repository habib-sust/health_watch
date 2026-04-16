import SwiftUI
import Charts

/// Full-screen steps detail with hourly bar chart, goal progress ring, and stats.
struct StepsDetailView: View {
    @ObservedObject var viewModel: WatchHealthDataViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                goalProgress
                chartSection
                statsSection
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Steps")
    }

    // MARK: - Goal Progress Ring

    private var goalProgress: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: viewModel.stepsStats.progress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: viewModel.stepsStats.progress)

                VStack(spacing: 0) {
                    Image(systemName: "figure.walk")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text(viewModel.stepsStats.formattedTotal)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("of \(Int(viewModel.stepsStats.goal))")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 90, height: 90)

            Text("\(Int(viewModel.stepsStats.progress * 100))% Complete")
                .font(.caption2)
                .foregroundStyle(viewModel.stepsStats.progress >= 1.0 ? .green : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: - Hourly Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hourly Breakdown")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            if !viewModel.hourlySteps.isEmpty {
                Chart(viewModel.hourlySteps) { bucket in
                    BarMark(
                        x: .value("Hour", bucket.hour),
                        y: .value("Steps", bucket.steps)
                    )
                    .foregroundStyle(
                        bucket.steps > 0
                            ? Color.green.opacity(0.8)
                            : Color.green.opacity(0.15)
                    )
                    .cornerRadius(2)
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatStepAxis(v))
                                    .font(.system(size: 8))
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 4)) { value in
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text(formatHour(hour))
                                    .font(.system(size: 8))
                            }
                        }
                    }
                }
                .frame(height: 100)
            } else {
                Text("No step data yet today")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .padding(10)
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today's Stats")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("Total")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text("\(Int(viewModel.stepsStats.totalToday))")
                        .font(.system(.caption, design: .rounded).bold())
                    Text("steps")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 30)

                VStack(spacing: 2) {
                    Text("Peak Hour")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    if let peak = viewModel.hourlySteps.max(by: { $0.steps < $1.steps }),
                       peak.steps > 0 {
                        Text(formatHour(peak.hour))
                            .font(.system(.caption, design: .rounded).bold())
                        Text("\(Int(peak.steps)) steps")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("--")
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 30)

                VStack(spacing: 2) {
                    Text("Active Hrs")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.hourlySteps.filter { $0.steps > 0 }.count)")
                        .font(.system(.caption, design: .rounded).bold())
                    Text("hours")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(10)
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "a" : "p"
        return "\(h)\(ampm)"
    }

    private func formatStepAxis(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0fk", value / 1000)
        }
        return "\(Int(value))"
    }
}
