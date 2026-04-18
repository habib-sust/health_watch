import SwiftUI
import Charts

struct ActivitySleepDetailView: View {
    @ObservedObject var viewModel: DailyActivityViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let sleep = viewModel.sleep, sleep.hasSleepData {
                    totalSleepHeader(sleep)
                    stageBreakdownChart(sleep)
                    statsGrid(sleep)
                } else {
                    noDataView
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Sleep")
    }

    // MARK: - Header

    private func totalSleepHeader(_ sleep: SleepSession) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "bed.double.fill")
                .font(.title3)
                .foregroundStyle(.indigo)
            Text(sleep.formattedTotal)
                .font(.system(size: 36, weight: .bold, design: .rounded))

            if let bed = sleep.bedtime, let wake = sleep.wakeTime {
                Text("\(bed, format: .dateTime.hour().minute()) – \(wake, format: .dateTime.hour().minute())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("Efficiency: \(sleep.formattedEfficiency)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Stage Breakdown

    private func stageBreakdownChart(_ sleep: SleepSession) -> some View {
        let stages = stageData(for: sleep)
        return VStack(alignment: .leading, spacing: 4) {
            Text("Sleep Stages")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

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
        .padding(10)
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Stats Grid

    private func statsGrid(_ sleep: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Breakdown")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                statItem(label: "Deep", value: sleep.formattedDeep, color: .purple)
                Divider().frame(height: 30)
                statItem(label: "Core", value: sleep.formattedCore, color: .indigo)
                Divider().frame(height: 30)
                statItem(label: "REM", value: sleep.formattedREM, color: .cyan)
            }

            HStack(spacing: 0) {
                statItem(label: "Awake", value: sleep.formattedAwake, color: .orange)
                Divider().frame(height: 30)
                statItem(label: "Efficiency", value: sleep.formattedEfficiency, color: .blue)
                Divider().frame(height: 30)
                Spacer()
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
        let stage: SleepStageType
        let duration: TimeInterval
        let fraction: Double
    }

    private func stageData(for sleep: SleepSession) -> [StageItem] {
        let total = sleep.totalSleep + sleep.awakeTime
        guard total > 0 else { return [] }

        let items: [(SleepStageType, TimeInterval)] = [
            (.deep, sleep.deepSleep),
            (.core, sleep.coreSleep),
            (.rem, sleep.remSleep),
            (.awake, sleep.awakeTime),
        ]

        return items
            .filter { $0.1 > 0 }
            .map { StageItem(stage: $0.0, duration: $0.1, fraction: $0.1 / total) }
    }
}
