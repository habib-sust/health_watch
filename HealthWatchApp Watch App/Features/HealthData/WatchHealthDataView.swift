import SwiftUI
import Charts

/// Main health dashboard — shows summary cards for Heart Rate and Steps.
/// Tapping each card navigates to a detail view with charts.
struct WatchHealthDataView: View {
    @StateObject private var viewModel = WatchHealthDataViewModel()
    @EnvironmentObject var appState: WatchAppState

    var body: some View {
        NavigationStack {
            ScrollView {
                if viewModel.isLoading && viewModel.lastRefreshDate == nil {
                    ProgressView("Loading...")
                        .padding(.top, 20)
                } else {
                    VStack(spacing: 10) {
                        heartRateCard
                        stepsCard
                        sleepCard
                        dailySummaryCard
                        syncFooter
                    }
                    .padding(.horizontal, 4)
                }
            }
            .navigationTitle("Health")
            .task {
                await viewModel.loadAllData()
                viewModel.startAutoRefresh()
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
            }
        }
    }

    // MARK: - Heart Rate Card

    private var heartRateCard: some View {
        NavigationLink {
            HeartRateDetailView(viewModel: viewModel)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("Heart Rate")
                        .font(.caption.bold())
                    Spacer()
                    if let current = viewModel.heartRateStats.current {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(current))")
                                .font(.system(.title3, design: .rounded).bold())
                            Text("BPM")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("--")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                    }
                }

                if viewModel.heartRateHistory.count >= 2 {
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
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartLegend(.hidden)
                    .frame(height: 36)
                }

                if let min = viewModel.heartRateStats.min,
                   let max = viewModel.heartRateStats.max {
                    HStack {
                        Label("\(Int(min))", systemImage: "arrow.down")
                        Spacer()
                        Label("\(Int(max))", systemImage: "arrow.up")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(Color(.darkGray).opacity(0.3))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Steps Card

    private var stepsCard: some View {
        NavigationLink {
            StepsDetailView(viewModel: viewModel)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(.green)
                    Text("Steps")
                        .font(.caption.bold())
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(viewModel.stepsStats.formattedTotal)
                            .font(.system(.title3, design: .rounded).bold())
                        Text("steps")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.green.opacity(0.2))
                            .frame(height: 6)
                        Capsule()
                            .fill(Color.green)
                            .frame(width: geo.size.width * viewModel.stepsStats.progress, height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(Int(viewModel.stepsStats.progress * 100))% of goal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(viewModel.stepsStats.goal))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.hourlySteps.isEmpty {
                    Chart(viewModel.hourlySteps) { bucket in
                        BarMark(
                            x: .value("Hour", bucket.hour),
                            y: .value("Steps", bucket.steps)
                        )
                        .foregroundStyle(.green.opacity(0.7))
                        .cornerRadius(2)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartLegend(.hidden)
                    .frame(height: 30)
                }
            }
            .padding(10)
            .background(Color(.darkGray).opacity(0.3))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sleep Card

    private var sleepCard: some View {
        NavigationLink {
            SleepDetailView(viewModel: viewModel)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "bed.double.fill")
                        .foregroundStyle(.indigo)
                    Text("Sleep")
                        .font(.caption.bold())
                    Spacer()
                    if viewModel.sleepStats.hasSleepData {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(viewModel.sleepStats.formattedTotal)
                                .font(.system(.title3, design: .rounded).bold())
                        }
                    } else {
                        Text("--")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                    }
                }

                if viewModel.sleepStats.hasSleepData {
                    // Stage breakdown bar
                    sleepStageBar

                    if let bedtime = viewModel.sleepStats.bedtime,
                       let wake = viewModel.sleepStats.wakeTime {
                        HStack {
                            Label(bedtime.formatted(.dateTime.hour().minute()), systemImage: "moon.fill")
                            Spacer()
                            Label(wake.formatted(.dateTime.hour().minute()), systemImage: "sun.max.fill")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.darkGray).opacity(0.3))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var sleepStageBar: some View {
        GeometryReader { geo in
            let stats = viewModel.sleepStats
            let total = stats.totalSleep + stats.awakeTime
            HStack(spacing: 1) {
                if total > 0 {
                    if stats.deepSleep > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.purple)
                            .frame(width: max(geo.size.width * stats.deepSleep / total - 1, 2))
                    }
                    if stats.coreSleep > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.indigo)
                            .frame(width: max(geo.size.width * stats.coreSleep / total - 1, 2))
                    }
                    if stats.remSleep > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.cyan)
                            .frame(width: max(geo.size.width * stats.remSleep / total - 1, 2))
                    }
                    if stats.awakeTime > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.orange)
                            .frame(width: max(geo.size.width * stats.awakeTime / total - 1, 2))
                    }
                }
            }
        }
        .frame(height: 6)
    }

    // MARK: - Daily Summary Card

    private var dailySummaryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                summaryItem(
                    icon: "heart.fill",
                    color: .red,
                    value: viewModel.heartRateStats.avg.map { "\(Int($0))" } ?? "--",
                    label: "Avg BPM"
                )
                summaryItem(
                    icon: "figure.walk",
                    color: .green,
                    value: viewModel.stepsStats.formattedTotal,
                    label: "Steps"
                )
                summaryItem(
                    icon: "bed.double.fill",
                    color: .indigo,
                    value: viewModel.sleepStats.hasSleepData ? viewModel.sleepStats.formattedTotal : "--",
                    label: "Sleep"
                )
            }
        }
        .padding(10)
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(12)
    }

    private func summaryItem(icon: String, color: Color, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(.caption, design: .rounded).bold())
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sync Footer

    private var syncFooter: some View {
        VStack(spacing: 2) {
            if let name = appState.individualName {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let lastSync = appState.lastSyncDate {
                Text("Synced \(lastSync, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}
