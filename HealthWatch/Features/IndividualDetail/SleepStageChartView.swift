import SwiftUI
import Charts

struct SleepStageChartView: View {
    let samples: [HealthSample]
    let totalSleep: String
    let bedtime: Date?
    let wakeTime: Date?
    let deepMinutes: Double
    let coreMinutes: Double
    let remMinutes: Double
    let awakeMinutes: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Sleep")
                    .font(.headline)
                Spacer()
                if !samples.isEmpty {
                    Text(totalSleep)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if samples.isEmpty {
                Text("No sleep data recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                // Stage breakdown bar
                stageBar

                // Bedtime / Wake time
                HStack {
                    if let bed = bedtime {
                        Label(bed.formatted(.dateTime.hour().minute()), systemImage: "moon.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let wake = wakeTime {
                        Label(wake.formatted(.dateTime.hour().minute()), systemImage: "sun.max.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Stage timeline chart
                Chart(samples) { sample in
                    let stage = HealthKitTypes.SleepStage(rawValue: Int(sample.value)) ?? .asleepUnspecified
                    BarMark(
                        xStart: .value("Start", sample.startDate),
                        xEnd: .value("End", sample.endDate),
                        y: .value("Stage", stage.displayName)
                    )
                    .foregroundStyle(stageColor(for: stage))
                }
                .frame(height: 120)
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }

                // Stats grid
                HStack(spacing: 16) {
                    stageStat("Deep", minutes: deepMinutes, color: .purple)
                    stageStat("Core", minutes: coreMinutes, color: .indigo)
                    stageStat("REM", minutes: remMinutes, color: .cyan)
                    stageStat("Awake", minutes: awakeMinutes, color: .orange)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Stage Bar

    private var stageBar: some View {
        let total = deepMinutes + coreMinutes + remMinutes + awakeMinutes
        return GeometryReader { geo in
            HStack(spacing: 2) {
                if total > 0 {
                    stageBarSegment(width: geo.size.width * deepMinutes / total, color: .purple)
                    stageBarSegment(width: geo.size.width * coreMinutes / total, color: .indigo)
                    stageBarSegment(width: geo.size.width * remMinutes / total, color: .cyan)
                    stageBarSegment(width: geo.size.width * awakeMinutes / total, color: .orange)
                }
            }
        }
        .frame(height: 8)
    }

    @ViewBuilder
    private func stageBarSegment(width: Double, color: Color) -> some View {
        if width > 0 {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: max(width - 2, 3))
        }
    }

    // MARK: - Helpers

    private func stageStat(_ label: String, minutes: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formatMinutes(minutes))
                .font(.caption.bold())
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    private func stageColor(for stage: HealthKitTypes.SleepStage) -> Color {
        switch stage {
        case .asleepDeep: return .purple
        case .asleepCore, .asleepUnspecified: return .indigo
        case .asleepREM: return .cyan
        case .awake: return .orange
        case .inBed: return .gray
        }
    }
}
