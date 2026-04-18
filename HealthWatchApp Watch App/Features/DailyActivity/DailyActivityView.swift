import SwiftUI
import Charts

struct DailyActivityView: View {
    @StateObject private var viewModel = DailyActivityViewModel()

    var body: some View {
        NavigationStack {
            authorizedContent
                .navigationTitle("Activity")
                .task { await viewModel.onAppear() }
                .onDisappear { viewModel.onDisappear() }
        }
    }

    // MARK: - Authorized Content

    @ViewBuilder
    private var authorizedContent: some View {
        if viewModel.isLoading {
            skeletonView
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    stepsCard
                    heartRateCard
                    sleepCard
                    lastUpdatedFooter
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Skeleton Loading

    private var skeletonView: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.darkGray).opacity(0.3))
                        .frame(height: 80)
                        .redacted(reason: .placeholder)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Steps Card

    private var stepsCard: some View {
        NavigationLink {
            ActivityStepsDetailView(viewModel: viewModel)
        } label: {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(.green)
                    Text("Steps")
                        .font(.caption.bold())
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(viewModel.steps.formattedTotal)
                            .font(.system(.title3, design: .rounded).bold())
                        Text("steps")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Progress ring
                progressRing

                HStack {
                    Text("\(Int(viewModel.steps.progress * 100))% of goal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(viewModel.steps.goal))")
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

    private var progressRing: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.green.opacity(0.2))
                    .frame(height: 6)
                Capsule()
                    .fill(Color.green)
                    .frame(width: geo.size.width * viewModel.steps.progress, height: 6)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.steps.progress)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Heart Rate Card

    private var heartRateCard: some View {
        NavigationLink {
            ActivityHeartRateDetailView(viewModel: viewModel)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("Heart Rate")
                        .font(.caption.bold())
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(viewModel.heartRate.formattedCurrent)
                            .font(.system(.title3, design: .rounded).bold())
                        if viewModel.heartRate.current != nil {
                            Text("BPM")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack(spacing: 12) {
                    if let resting = viewModel.heartRate.resting {
                        miniStat(label: "Resting", value: "\(Int(resting))")
                    }
                    miniStat(label: "Range", value: viewModel.heartRate.rangeText)
                }

                if let date = viewModel.heartRate.lastReadingDate {
                    Text(date, style: .relative)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        + Text(" ago")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
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
            ActivitySleepDetailView(viewModel: viewModel)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "bed.double.fill")
                        .foregroundStyle(.indigo)
                    Text("Sleep")
                        .font(.caption.bold())
                    Spacer()
                    if let sleep = viewModel.sleep, sleep.hasSleepData {
                        Text(sleep.formattedTotal)
                            .font(.system(.title3, design: .rounded).bold())
                    } else {
                        Text("--")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                    }
                }

                if let sleep = viewModel.sleep, sleep.hasSleepData {
                    sleepStageBar(sleep)

                    HStack {
                        if let bed = sleep.bedtime {
                            Label(bed.formatted(.dateTime.hour().minute()), systemImage: "moon.fill")
                        }
                        Spacer()
                        if let wake = sleep.wakeTime {
                            Label(wake.formatted(.dateTime.hour().minute()), systemImage: "sun.max.fill")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    Text("Efficiency: \(sleep.formattedEfficiency)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("No sleep data recorded")
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

    private func sleepStageBar(_ sleep: SleepSession) -> some View {
        let total = sleep.totalSleep + sleep.awakeTime
        return GeometryReader { geo in
            HStack(spacing: 1) {
                if total > 0 {
                    stageBarSegment(width: geo.size.width * sleep.deepSleep / total, color: .purple)
                    stageBarSegment(width: geo.size.width * sleep.coreSleep / total, color: .indigo)
                    stageBarSegment(width: geo.size.width * sleep.remSleep / total, color: .cyan)
                    stageBarSegment(width: geo.size.width * sleep.awakeTime / total, color: .orange)
                }
            }
        }
        .frame(height: 6)
    }

    @ViewBuilder
    private func stageBarSegment(width: Double, color: Color) -> some View {
        if width > 0 {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: max(width - 1, 2))
        }
    }

    // MARK: - Helpers

    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(.caption2, design: .rounded).bold())
                .foregroundStyle(.secondary)
        }
    }

    private var lastUpdatedFooter: some View {
        Group {
            if let date = viewModel.lastRefreshDate {
                Text("Updated \(date, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
        }
    }

}
