import Foundation
import HealthKit
import Combine
import SwiftUI
import os

// MARK: - Data Models

/// A single data point for charting (timestamp + value)
struct HealthDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

/// Hourly step bucket for the bar chart
struct HourlySteps: Identifiable {
    let id = UUID()
    let hour: Int
    let date: Date
    let steps: Double
}

/// Heart rate statistics for a time period
struct HeartRateStats {
    var current: Double?
    var min: Double?
    var max: Double?
    var avg: Double?
    var lastUpdated: Date?
}

/// Steps statistics for today
struct StepsStats {
    var totalToday: Double = 0
    var goal: Double = 10_000
    var lastUpdated: Date?

    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(totalToday / goal, 1.0)
    }

    var formattedTotal: String {
        if totalToday >= 10_000 {
            return String(format: "%.1fk", totalToday / 1000.0)
        }
        return String(Int(totalToday))
    }
}

/// Sleep stage for charting
enum SleepStage: String, CaseIterable {
    case awake = "Awake"
    case rem = "REM"
    case core = "Core"
    case deep = "Deep"
    case unspecified = "Asleep"

    var color: Color {
        switch self {
        case .awake: return .orange
        case .rem: return .cyan
        case .core: return .indigo
        case .deep: return .purple
        case .unspecified: return .blue
        }
    }

    var sortOrder: Int {
        switch self {
        case .deep: return 0
        case .core: return 1
        case .rem: return 2
        case .unspecified: return 3
        case .awake: return 4
        }
    }
}

/// A sleep segment for the timeline chart
struct SleepSegment: Identifiable {
    let id = UUID()
    let stage: SleepStage
    let startDate: Date
    let endDate: Date

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }
}

/// Summary of last night's sleep
struct SleepStats {
    var totalSleep: TimeInterval = 0
    var deepSleep: TimeInterval = 0
    var coreSleep: TimeInterval = 0
    var remSleep: TimeInterval = 0
    var awakeTime: TimeInterval = 0
    var bedtime: Date?
    var wakeTime: Date?

    var formattedTotal: String { formatDuration(totalSleep) }
    var formattedDeep: String { formatDuration(deepSleep) }
    var formattedCore: String { formatDuration(coreSleep) }
    var formattedREM: String { formatDuration(remSleep) }
    var formattedAwake: String { formatDuration(awakeTime) }

    var hasSleepData: Bool { totalSleep > 0 }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - ViewModel

@MainActor
final class WatchHealthDataViewModel: ObservableObject {
    // Summary
    @Published var heartRateStats = HeartRateStats()
    @Published var stepsStats = StepsStats()
    @Published var sleepStats = SleepStats()

    // Chart data
    @Published var heartRateHistory: [HealthDataPoint] = []
    @Published var hourlySteps: [HourlySteps] = []
    @Published var sleepSegments: [SleepSegment] = []

    // State
    @Published var isLoading = false
    @Published var lastRefreshDate: Date?

    private let store = HKHealthStore()
    private var refreshTask: Task<Void, Never>?

    // MARK: - Load All Data

    func loadAllData() async {
        Logger.healthKit.info("━━━ Loading health data (HR + Steps + Sleep) ━━━")
        isLoading = lastRefreshDate == nil

        async let hr: () = loadHeartRateData()
        async let steps: () = loadStepsData()
        async let sleep: () = loadSleepData()
        _ = await (hr, steps, sleep)

        isLoading = false
        lastRefreshDate = Date()
        logSummary()
    }

    // MARK: - Heart Rate

    private func loadHeartRateData() async {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        // Today's statistics (min/max/avg)
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let stats = await fetchStatistics(for: hrType, predicate: predicate, options: [.discreteMin, .discreteMax, .discreteAverage])
        heartRateStats.min = stats?.minimumQuantity()?.doubleValue(for: bpmUnit)
        heartRateStats.max = stats?.maximumQuantity()?.doubleValue(for: bpmUnit)
        heartRateStats.avg = stats?.averageQuantity()?.doubleValue(for: bpmUnit)

        Logger.healthKit.info("[HeartRate] today — min: \(self.heartRateStats.min.map { String(format: "%.0f", $0) } ?? "nil"), max: \(self.heartRateStats.max.map { String(format: "%.0f", $0) } ?? "nil"), avg: \(self.heartRateStats.avg.map { String(format: "%.0f", $0) } ?? "nil")")

        // Most recent reading
        if let sample = await fetchMostRecentSample(for: hrType) {
            let value = sample.quantity.doubleValue(for: bpmUnit)
            heartRateStats.current = value
            heartRateStats.lastUpdated = sample.startDate
            Logger.healthKit.info("[HeartRate] current: \(String(format: "%.0f", value)) BPM from \(sample.startDate)")
        }

        // Last 3 hours of HR samples for line chart
        let threeHoursAgo = Date().addingTimeInterval(-3 * 3600)
        let recentPredicate = HKQuery.predicateForSamples(withStart: threeHoursAgo, end: Date(), options: .strictStartDate)
        let samples = await fetchSamples(for: hrType, predicate: recentPredicate, limit: 100)
        heartRateHistory = samples.map { sample in
            HealthDataPoint(date: sample.startDate, value: sample.quantity.doubleValue(for: bpmUnit))
        }
        Logger.healthKit.info("[HeartRate] chart: \(self.heartRateHistory.count) data points (last 3h)")
    }

    // MARK: - Steps

    private func loadStepsData() async {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let countUnit = HKUnit.count()

        // Today's cumulative steps
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let stats = await fetchStatistics(for: stepType, predicate: predicate, options: .cumulativeSum)
        if let sum = stats?.sumQuantity()?.doubleValue(for: countUnit) {
            stepsStats.totalToday = sum
            stepsStats.lastUpdated = Date()
            Logger.healthKit.info("[Steps] today total: \(Int(sum)) steps")
        }

        // Hourly breakdown for bar chart
        let hourlyData = await fetchHourlySteps(from: startOfDay, to: Date())
        hourlySteps = hourlyData
        Logger.healthKit.info("[Steps] hourly: \(hourlyData.count) buckets")
        for bucket in hourlyData where bucket.steps > 0 {
            Logger.healthKit.debug("[Steps]   hour \(bucket.hour): \(Int(bucket.steps)) steps")
        }
    }

    // MARK: - Sleep

    private func loadSleepData() async {
        let sleepType = HKCategoryType(.sleepAnalysis)

        // Look for sleep data from the last 24 hours
        let now = Date()
        let yesterday = now.addingTimeInterval(-24 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)

        let samples = await fetchCategorySamples(for: sleepType, predicate: predicate)
        Logger.healthKit.info("[Sleep] fetched \(samples.count) raw sleep samples")

        var segments: [SleepSegment] = []
        var stats = SleepStats()

        for sample in samples {
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }

            let stage: SleepStage
            switch value {
            case .awake:
                stage = .awake
                stats.awakeTime += sample.endDate.timeIntervalSince(sample.startDate)
            case .asleepCore:
                stage = .core
                stats.coreSleep += sample.endDate.timeIntervalSince(sample.startDate)
            case .asleepDeep:
                stage = .deep
                stats.deepSleep += sample.endDate.timeIntervalSince(sample.startDate)
            case .asleepREM:
                stage = .rem
                stats.remSleep += sample.endDate.timeIntervalSince(sample.startDate)
            case .asleepUnspecified:
                stage = .unspecified
                stats.coreSleep += sample.endDate.timeIntervalSince(sample.startDate)
            case .inBed:
                // Track bedtime/wake time from inBed samples but don't add as sleep segment
                if stats.bedtime == nil || sample.startDate < stats.bedtime! {
                    stats.bedtime = sample.startDate
                }
                if stats.wakeTime == nil || sample.endDate > stats.wakeTime! {
                    stats.wakeTime = sample.endDate
                }
                continue
            @unknown default:
                continue
            }

            segments.append(SleepSegment(stage: stage, startDate: sample.startDate, endDate: sample.endDate))
        }

        stats.totalSleep = stats.deepSleep + stats.coreSleep + stats.remSleep

        // If no inBed samples, derive bedtime/wake from sleep segments
        if stats.bedtime == nil, let earliest = segments.min(by: { $0.startDate < $1.startDate }) {
            stats.bedtime = earliest.startDate
        }
        if stats.wakeTime == nil, let latest = segments.max(by: { $0.endDate < $1.endDate }) {
            stats.wakeTime = latest.endDate
        }

        sleepSegments = segments.sorted { $0.startDate < $1.startDate }
        sleepStats = stats

        Logger.healthKit.info("[Sleep] total: \(stats.formattedTotal), deep: \(stats.formattedDeep), core: \(stats.formattedCore), REM: \(stats.formattedREM), awake: \(stats.formattedAwake)")
    }

    // MARK: - HealthKit Queries

    private func fetchCategorySamples(for type: HKCategoryType, predicate: NSPredicate?) async -> [HKCategorySample] {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, _ in
                let samples = (results as? [HKCategorySample]) ?? []
                continuation.resume(returning: samples)
            }
            store.execute(query)
        }
    }

    private func fetchStatistics(for type: HKQuantityType, predicate: NSPredicate?, options: HKStatisticsOptions) async -> HKStatistics? {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: options) { _, stats, error in
                if let error {
                    Logger.healthKit.error("Statistics query failed for \(type.identifier): \(error.localizedDescription)")
                }
                continuation.resume(returning: stats)
            }
            store.execute(query)
        }
    }

    private func fetchMostRecentSample(for type: HKQuantityType) async -> HKQuantitySample? {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, results, _ in
                continuation.resume(returning: results?.first as? HKQuantitySample)
            }
            store.execute(query)
        }
    }

    private func fetchSamples(for type: HKQuantityType, predicate: NSPredicate?, limit: Int) async -> [HKQuantitySample] {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [sort]) { _, results, _ in
                let samples = (results as? [HKQuantitySample]) ?? []
                continuation.resume(returning: samples)
            }
            store.execute(query)
        }
    }

    private func fetchHourlySteps(from start: Date, to end: Date) async -> [HourlySteps] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        let countUnit = HKUnit.count()
        let calendar = Calendar.current
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let interval = DateComponents(hour: 1)
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                guard let collection else {
                    if let error {
                        Logger.healthKit.error("Hourly steps query failed: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: [])
                    return
                }

                var buckets: [HourlySteps] = []
                collection.enumerateStatistics(from: start, to: end) { stats, _ in
                    let hour = calendar.component(.hour, from: stats.startDate)
                    let steps = stats.sumQuantity()?.doubleValue(for: countUnit) ?? 0
                    buckets.append(HourlySteps(hour: hour, date: stats.startDate, steps: steps))
                }
                continuation.resume(returning: buckets)
            }
            store.execute(query)
        }
    }

    // MARK: - Auto Refresh

    func startAutoRefresh() {
        stopAutoRefresh()
        Logger.healthKit.info("Auto-refresh started (60s interval)")
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled else { break }
                Logger.healthKit.debug("Auto-refresh triggered")
                await loadAllData()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Logging

    private func logSummary() {
        Logger.healthKit.info("━━━ Refresh summary ━━━")
        Logger.healthKit.info("  Heart Rate — current: \(self.heartRateStats.current.map { String(format: "%.0f", $0) } ?? "nil") BPM, min: \(self.heartRateStats.min.map { String(format: "%.0f", $0) } ?? "-"), max: \(self.heartRateStats.max.map { String(format: "%.0f", $0) } ?? "-"), avg: \(self.heartRateStats.avg.map { String(format: "%.0f", $0) } ?? "-"), chart pts: \(self.heartRateHistory.count)")
        Logger.healthKit.info("  Steps — total: \(Int(self.stepsStats.totalToday))/\(Int(self.stepsStats.goal)) (\(Int(self.stepsStats.progress * 100))%), hourly buckets: \(self.hourlySteps.count)")
        Logger.healthKit.info("  Sleep — total: \(self.sleepStats.formattedTotal), segments: \(self.sleepSegments.count)")
        Logger.healthKit.info("━━━ Refresh complete ━━━")
    }
}
