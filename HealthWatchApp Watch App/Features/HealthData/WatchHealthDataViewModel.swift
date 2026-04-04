import Foundation
import HealthKit
import Combine

/// A single displayable health metric with its latest value and metadata.
struct WatchHealthMetric: Identifiable {
    let id: String
    let displayName: String
    let icon: String
    let color: String
    var latestValue: Double?
    var unit: String
    var lastUpdated: Date?
    var recentValues: [Double]
}

@MainActor
final class WatchHealthDataViewModel: ObservableObject {
    @Published var metrics: [WatchHealthMetric] = []
    @Published var isLoading = false
    @Published var lastRefreshDate: Date?

    private let store = HKHealthStore()
    private var refreshTask: Task<Void, Never>?

    private static let displayedMetrics: [(identifier: HKQuantityTypeIdentifier, name: String, icon: String, color: String, unit: HKUnit, displayUnit: String)] = [
        (.heartRate, "Heart Rate", "heart.fill", "red",
         HKUnit.count().unitDivided(by: .minute()), "BPM"),
        (.oxygenSaturation, "Blood Oxygen", "lungs.fill", "blue",
         HKUnit.percent(), "%"),
        (.stepCount, "Steps", "figure.walk", "orange",
         HKUnit.count(), "steps"),
        (.respiratoryRate, "Resp. Rate", "wind", "teal",
         HKUnit.count().unitDivided(by: .minute()), "br/min"),
    ]

    init() {
        metrics = Self.displayedMetrics.map { config in
            WatchHealthMetric(
                id: config.identifier.rawValue,
                displayName: config.name,
                icon: config.icon,
                color: config.color,
                latestValue: nil,
                unit: config.displayUnit,
                lastUpdated: nil,
                recentValues: []
            )
        }
    }

    func loadLatestValues() async {
        isLoading = lastRefreshDate == nil
        for (index, config) in Self.displayedMetrics.enumerated() {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: config.identifier) else { continue }

            if let sample = await fetchMostRecentSample(for: quantityType) {
                var value = sample.quantity.doubleValue(for: config.unit)
                if config.identifier == .oxygenSaturation {
                    value *= 100.0
                }
                metrics[index].latestValue = value
                metrics[index].lastUpdated = sample.startDate
            }

            let recentSamples = await fetchRecentSamples(for: quantityType, limit: 6)
            metrics[index].recentValues = recentSamples.map { sample in
                var value = sample.quantity.doubleValue(for: config.unit)
                if config.identifier == .oxygenSaturation {
                    value *= 100.0
                }
                return value
            }
        }

        // Replace steps latest value with today's cumulative total
        if let stepIndex = Self.displayedMetrics.firstIndex(where: { $0.identifier == .stepCount }),
           let todaySteps = await fetchTodayCumulativeSteps() {
            metrics[stepIndex].latestValue = todaySteps
            metrics[stepIndex].lastUpdated = Date()
        }

        isLoading = false
        lastRefreshDate = Date()
    }

    // MARK: - HealthKit Queries

    private func fetchMostRecentSample(for quantityType: HKQuantityType) async -> HKQuantitySample? {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, results, _ in
                continuation.resume(returning: results?.first as? HKQuantitySample)
            }
            store.execute(query)
        }
    }

    private func fetchRecentSamples(for quantityType: HKQuantityType, limit: Int) async -> [HKQuantitySample] {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                let samples = (results as? [HKQuantitySample]) ?? []
                continuation.resume(returning: samples.reversed())
            }
            store.execute(query)
        }
    }

    private func fetchTodayCumulativeSteps() async -> Double? {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let sum = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count())
                continuation.resume(returning: sum)
            }
            store.execute(query)
        }
    }

    // MARK: - Auto Refresh

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled else { break }
                await loadLatestValues()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
