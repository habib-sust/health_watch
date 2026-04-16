import Foundation
import HealthKit
import Combine
import os

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
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withFullTime, .withFractionalSeconds]

        Logger.healthKit.info("━━━ Loading latest health values ━━━")
        Logger.healthKit.info("Metrics to fetch: \(Self.displayedMetrics.map(\.name).joined(separator: ", "))")
        isLoading = lastRefreshDate == nil

        for (index, config) in Self.displayedMetrics.enumerated() {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: config.identifier) else {
                Logger.healthKit.warning("Could not create quantity type for \(config.identifier.rawValue)")
                continue
            }

            let authStatus = store.authorizationStatus(for: quantityType)
            let authString: String
            switch authStatus {
            case .notDetermined: authString = "notDetermined"
            case .sharingDenied: authString = "denied"
            case .sharingAuthorized: authString = "authorized"
            @unknown default: authString = "unknown"
            }

            Logger.healthKit.info("[\(config.name)] type: \(config.identifier.rawValue), HKUnit: \(config.unit.unitString), displayUnit: \(config.displayUnit), auth: \(authString)")

            if let sample = await fetchMostRecentSample(for: quantityType) {
                var value = sample.quantity.doubleValue(for: config.unit)
                if config.identifier == .oxygenSaturation {
                    value *= 100.0
                }
                metrics[index].latestValue = value
                metrics[index].lastUpdated = sample.startDate

                Logger.healthKit.info("[\(config.name)] latest: \(String(format: "%.2f", value)) \(config.displayUnit)")
                Logger.healthKit.info("[\(config.name)] startDate: \(dateFormatter.string(from: sample.startDate))")
                Logger.healthKit.info("[\(config.name)] endDate: \(dateFormatter.string(from: sample.endDate))")
                Logger.healthKit.info("[\(config.name)] source: \(sample.sourceRevision.source.name) (\(sample.sourceRevision.source.bundleIdentifier))")
                Logger.healthKit.info("[\(config.name)] device: \(sample.device?.name ?? "unknown") (\(sample.device?.model ?? "unknown"))")
                Logger.healthKit.info("[\(config.name)] uuid: \(sample.uuid.uuidString)")
            } else {
                Logger.healthKit.info("[\(config.name)] latest: nil — no sample available")
            }

            let recentSamples = await fetchRecentSamples(for: quantityType, limit: 6)
            metrics[index].recentValues = recentSamples.map { sample in
                var value = sample.quantity.doubleValue(for: config.unit)
                if config.identifier == .oxygenSaturation {
                    value *= 100.0
                }
                return value
            }

            if !recentSamples.isEmpty {
                let valuesStr = recentSamples.enumerated().map { i, sample in
                    var v = sample.quantity.doubleValue(for: config.unit)
                    if config.identifier == .oxygenSaturation { v *= 100.0 }
                    return "  [\(i)] \(String(format: "%.2f", v)) \(config.displayUnit) @ \(dateFormatter.string(from: sample.startDate)) src=\(sample.sourceRevision.source.name)"
                }.joined(separator: "\n")
                Logger.healthKit.info("[\(config.name)] recent (\(recentSamples.count) samples):\n\(valuesStr)")
            } else {
                Logger.healthKit.info("[\(config.name)] recent: no samples")
            }
        }

        if let stepIndex = Self.displayedMetrics.firstIndex(where: { $0.identifier == .stepCount }),
           let todaySteps = await fetchTodayCumulativeSteps() {
            metrics[stepIndex].latestValue = todaySteps
            metrics[stepIndex].lastUpdated = Date()
            Logger.healthKit.info("[Steps] today cumulative: \(Int(todaySteps)) steps")
        } else {
            Logger.healthKit.info("[Steps] today cumulative: unavailable")
        }

        isLoading = false
        lastRefreshDate = Date()

        Logger.healthKit.info("━━━ Refresh summary ━━━")
        for metric in metrics {
            let valueStr = metric.latestValue.map { String(format: "%.2f", $0) } ?? "nil"
            let dateStr = metric.lastUpdated.map { dateFormatter.string(from: $0) } ?? "never"
            Logger.healthKit.info("  \(metric.displayName): \(valueStr) \(metric.unit) (updated: \(dateStr), history: \(metric.recentValues.count) pts)")
        }
        Logger.healthKit.info("━━━ Refresh complete ━━━")
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
        Logger.healthKit.info("Auto-refresh started (60s interval)")
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled else { break }
                Logger.healthKit.debug("Auto-refresh triggered")
                await loadLatestValues()
            }
        }
    }

    func stopAutoRefresh() {
        Logger.healthKit.info("Auto-refresh stopped")
        refreshTask?.cancel()
        refreshTask = nil
    }
}
