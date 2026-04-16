import Foundation
import HealthKit
import Combine
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

// MARK: - ViewModel

@MainActor
final class WatchHealthDataViewModel: ObservableObject {
    // Summary
    @Published var heartRateStats = HeartRateStats()
    @Published var stepsStats = StepsStats()

    // Chart data
    @Published var heartRateHistory: [HealthDataPoint] = []
    @Published var hourlySteps: [HourlySteps] = []

    // State
    @Published var isLoading = false
    @Published var lastRefreshDate: Date?

    private let store = HKHealthStore()
    private var refreshTask: Task<Void, Never>?

    // MARK: - Load All Data

    func loadAllData() async {
        Logger.healthKit.info("━━━ Loading Phase 1 health data (HR + Steps) ━━━")
        isLoading = lastRefreshDate == nil

        async let hr: () = loadHeartRateData()
        async let steps: () = loadStepsData()
        _ = await (hr, steps)

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

    // MARK: - HealthKit Queries

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
        Logger.healthKit.info("━━━ Refresh complete ━━━")
    }
}
