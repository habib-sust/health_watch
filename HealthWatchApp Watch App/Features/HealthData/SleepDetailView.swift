import SwiftUI
import Charts

/// Full-screen sleep detail with stage breakdown, timeline, and stats.
struct SleepDetailView: View {
    @ObservedObject var viewModel: WatchHealthDataViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.sleepStats.hasSleepData {
                    totalSleepHeader
                    stageBreakdownChart
                    timelineSection
                    statsGrid
                } else {
                    noDataView
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Sleep")
    }

    // MARK: - Total Sleep Header

    private var totalSleepHeader: some View {
        VStack(spacing: 2) {
            Image(systemName: "bed.double.fill")
                .font(.title3)
                .foregroundStyle(.indigo)

            Text(viewModel.sleepStats.formattedTotal)
                .font(.system(size: 36, weight: .bold, design: .rounded))

            if let bedtime = viewModel.sleepStats.bedtime,
               let wake = viewModel.sleepStats.wakeTime {
                Text("\(bedtime, format: .dateTime.hour().minute()) - \(wake, format: .dateTime.hour().minute())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Stage Breakdown (Horizontal Bar)

    private var stageBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sleep Stages")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            let stages = stageData
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(stages, id: \.stage) { item in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.stage.color)
                            .frame(width: max(geo.size.width * item.fraction - 1, 2))
                    }
                }
            }
            .frame(height: 12)

            // Legend
            HStack(spacing: 8) {
                ForEach(stages, id: \.stage) { item in
                    if item.duration > 0 {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(item.stage.color)
                                .frame(width: 6, height: 6)
                            Text(item.stage.rawValue)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Timeline")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            if viewModel.sleepSegments.count >= 2 {
                Chart(viewModel.sleepSegments) { segment in
                    BarMark(
                        xStart: .value("Start", segment.startDate),
                        xEnd: .value("End", segment.endDate),
                        y: .value("Sleep", "Sleep")
                    )
                    .foregroundStyle(segment.stage.color)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.hour().minute())
                                    .font(.system(size: 8))
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 30)
            }
        }
        .padding(10)
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Breakdown")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                statItem(label: "Deep", value: viewModel.sleepStats.formattedDeep, color: .purple)
                Divider().frame(height: 30)
                statItem(label: "Core", value: viewModel.sleepStats.formattedCore, color: .indigo)
                Divider().frame(height: 30)
                statItem(label: "REM", value: viewModel.sleepStats.formattedREM, color: .cyan)
            }
        }
        .padding(10)
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(12)
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

    // MARK: - No Data

    private var noDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bed.double.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No Sleep Data")
                .font(.caption.bold())
            Text("Sleep data will appear after your next tracked sleep.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 30)
    }

    // MARK: - Helpers

    private struct StageItem {
        let stage: SleepStage
        let duration: TimeInterval
        let fraction: Double
    }

    private var stageData: [StageItem] {
        let stats = viewModel.sleepStats
        let total = stats.totalSleep + stats.awakeTime
        guard total > 0 else { return [] }

        let items: [(SleepStage, TimeInterval)] = [
            (.deep, stats.deepSleep),
            (.core, stats.coreSleep),
            (.rem, stats.remSleep),
            (.awake, stats.awakeTime),
        ]

        return items
            .filter { $0.1 > 0 }
            .map { StageItem(stage: $0.0, duration: $0.1, fraction: $0.1 / total) }
    }
}
