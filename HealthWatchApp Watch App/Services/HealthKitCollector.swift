import Foundation
import HealthKit
import os

final class HealthKitCollector {
    static let shared = HealthKitCollector()

    private let store = HKHealthStore()
    private let isAvailable = HKHealthStore.isHealthDataAvailable()
    private var observerQueries: [HKObserverQuery] = []
    private var anchors: [HKObjectType: HKQueryAnchor] = [:]

    /// Callback invoked when new samples arrive via observer queries
    nonisolated(unsafe) var onNewSamplesReceived: (([HealthSample]) -> Void)?

    // MARK: - Read Types

    static let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .restingHeartRate,
            .stepCount,
        ]
        for id in quantityTypes {
            if let t = HKQuantityType.quantityType(forIdentifier: id) {
                types.insert(t)
            }
        }
        types.insert(HKCategoryType(.sleepAnalysis))
        return types
    }()

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else {
            Logger.healthKit.error("HealthKit not available on this device")
            return
        }
        Logger.healthKit.info("Requesting HealthKit authorization for \(Self.readTypes.count) types")
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
        Logger.healthKit.info("HealthKit authorization completed")
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        store.authorizationStatus(for: type)
    }

    func deniedTypes() -> [HKObjectType] {
        Self.readTypes.filter { authorizationStatus(for: $0) == .sharingDenied }
    }

    // MARK: - Background Delivery & Observer Queries

    func enableBackgroundDelivery() {
        guard isAvailable else {
            Logger.healthKit.warning("Cannot enable background delivery — HealthKit unavailable")
            return
        }
        Logger.healthKit.info("Enabling background delivery for \(Self.readTypes.count) types")
        for type in Self.readTypes {
            guard authorizationStatus(for: type) != .sharingDenied else {
                Logger.healthKit.debug("Skipping \(type.identifier) — authorization denied")
                continue
            }

            store.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if let error {
                    Logger.healthKit.error("Background delivery error for \(type.identifier): \(error.localizedDescription)")
                } else {
                    Logger.healthKit.debug("Background delivery enabled for \(type.identifier)")
                }
            }

            let query = HKObserverQuery(sampleType: type as! HKSampleType, predicate: nil) {
                [weak self] _, completionHandler, error in
                guard error == nil else {
                    Logger.healthKit.error("Observer query error for \(type.identifier): \(error!.localizedDescription)")
                    completionHandler()
                    return
                }
                Task {
                    Logger.healthKit.info("Observer triggered for \(type.identifier)")
                    let samples = await self?.fetchNewSamples(for: type as! HKSampleType) ?? []
                    if !samples.isEmpty {
                        Logger.healthKit.info("Observer delivered \(samples.count) new samples for \(type.identifier)")
                        self?.onNewSamplesReceived?(samples)
                    } else {
                        Logger.healthKit.debug("Observer triggered for \(type.identifier) but no new samples")
                    }
                    completionHandler()
                }
            }
            store.execute(query)
            observerQueries.append(query)
        }
        Logger.healthKit.info("Background delivery and observer queries set up")
    }

    func stopObserverQueries() {
        Logger.healthKit.info("Stopping \(self.observerQueries.count) observer queries")
        for query in observerQueries {
            store.stop(query)
        }
        observerQueries.removeAll()
    }

    // MARK: - Anchored Object Queries

    func fetchNewSamples(for sampleType: HKSampleType) async -> [HealthSample] {
        let anchor = anchors[sampleType]
        Logger.healthKit.debug("Fetching new samples for \(sampleType.identifier), anchor: \(anchor != nil ? "present" : "nil")")

        return await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: sampleType,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, newSamples, _, newAnchor, error in
                guard let newSamples, error == nil else {
                    Logger.healthKit.error("Anchored query failed for \(sampleType.identifier): \(error?.localizedDescription ?? "unknown")")
                    continuation.resume(returning: [])
                    return
                }

                Logger.healthKit.debug("Anchored query returned \(newSamples.count) raw samples for \(sampleType.identifier)")

                if let newAnchor {
                    self?.anchors[sampleType] = newAnchor
                    self?.persistAnchors()
                }

                let healthSamples = newSamples.compactMap { sample -> HealthSample? in
                    self?.convertToHealthSample(sample)
                }

                let deduplicated = self?.deduplicateSamples(healthSamples) ?? healthSamples
                Logger.healthKit.info("Fetched \(deduplicated.count) unique samples for \(sampleType.identifier) (raw: \(newSamples.count), converted: \(healthSamples.count))")

                for sample in deduplicated {
                    Logger.healthKit.debug("  \(sample.typeIdentifier): \(sample.value) \(sample.unit) @ \(sample.startDate)")
                }

                continuation.resume(returning: deduplicated)
            }
            store.execute(query)
        }
    }

    /// Fetch new samples across all authorized types
    func fetchAllNewSamples() async -> [HealthSample] {
        guard isAvailable else {
            Logger.healthKit.warning("fetchAllNewSamples — HealthKit unavailable")
            return []
        }
        Logger.healthKit.info("Fetching new samples across all types")
        var allSamples: [HealthSample] = []
        for type in Self.readTypes {
            guard authorizationStatus(for: type) != .sharingDenied,
                  let sampleType = type as? HKSampleType else { continue }
            let samples = await fetchNewSamples(for: sampleType)
            allSamples.append(contentsOf: samples)
        }
        Logger.healthKit.info("Total new samples across all types: \(allSamples.count)")
        return allSamples
    }

    // MARK: - Sample Conversion

    private func convertToHealthSample(_ sample: HKSample) -> HealthSample? {
        let id = sample.uuid
        let source = sample.sourceRevision.source.bundleIdentifier

        if let quantitySample = sample as? HKQuantitySample {
            let (value, unit) = extractQuantity(quantitySample)
            return HealthSample(
                id: id, typeIdentifier: quantitySample.quantityType.identifier,
                value: value, unit: unit,
                startDate: sample.startDate, endDate: sample.endDate,
                sourceBundleId: source
            )
        }

        if let categorySample = sample as? HKCategorySample {
            return HealthSample(
                id: id, typeIdentifier: categorySample.categoryType.identifier,
                value: Double(categorySample.value), unit: "category",
                startDate: sample.startDate, endDate: sample.endDate,
                sourceBundleId: source
            )
        }

        return nil
    }

    /// Phase 1: extract heart rate (BPM) or step count
    private func extractQuantity(_ sample: HKQuantitySample) -> (Double, String) {
        let typeId = sample.quantityType.identifier

        switch typeId {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            let unit = HKUnit.count().unitDivided(by: .minute())
            return (sample.quantity.doubleValue(for: unit), "BPM")

        case HKQuantityTypeIdentifier.stepCount.rawValue:
            let unit = HKUnit.count()
            return (sample.quantity.doubleValue(for: unit), "steps")

        default:
            let unit = HKUnit.count()
            return (sample.quantity.doubleValue(for: unit), "count")
        }
    }

    // MARK: - De-duplication

    /// Track recently transmitted sample UUIDs to prevent duplicates
    private let dedupKey = "healthwatch.transmittedSampleUUIDs"

    private func deduplicateSamples(_ samples: [HealthSample]) -> [HealthSample] {
        var transmitted = loadTransmittedUUIDs()
        var unique: [HealthSample] = []

        for sample in samples {
            let uuidString = sample.id.uuidString
            if !transmitted.contains(uuidString) {
                unique.append(sample)
                transmitted.insert(uuidString)
            }
        }

        // Cap at deduplicationCacheSize, removing oldest entries
        if transmitted.count > AppConstants.deduplicationCacheSize {
            let excess = transmitted.count - AppConstants.deduplicationCacheSize
            let array = Array(transmitted)
            transmitted = Set(array.dropFirst(excess))
        }

        saveTransmittedUUIDs(transmitted)
        return unique
    }

    private func loadTransmittedUUIDs() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: dedupKey) ?? []
        return Set(array)
    }

    private func saveTransmittedUUIDs(_ uuids: Set<String>) {
        UserDefaults.standard.set(Array(uuids), forKey: dedupKey)
    }

    func clearDeduplicationCache() {
        UserDefaults.standard.removeObject(forKey: dedupKey)
    }

    // MARK: - Anchor Persistence

    private let anchorKey = "healthwatch.queryAnchors"

    private func persistAnchors() {
        var data: [String: Data] = [:]
        for (type, anchor) in anchors {
            if let encoded = try? NSKeyedArchiver.archivedData(
                withRootObject: anchor,
                requiringSecureCoding: true
            ) {
                data[type.identifier] = encoded
            }
        }
        UserDefaults.standard.set(data, forKey: anchorKey)
    }

    func restoreAnchors() {
        guard let data = UserDefaults.standard.dictionary(forKey: anchorKey) as? [String: Data] else { return }
        for (identifier, anchorData) in data {
            if let anchor = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: HKQueryAnchor.self,
                from: anchorData
            ) {
                // Find the matching type
                for type in Self.readTypes {
                    if type.identifier == identifier {
                        anchors[type] = anchor
                        break
                    }
                }
            }
        }
    }
}
