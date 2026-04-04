import Foundation
import HealthKit

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
            .heartRate, .restingHeartRate,
            .heartRateVariabilitySDNN, .oxygenSaturation,
            .stepCount, .activeEnergyBurned,
            .respiratoryRate, .walkingHeartRateAverage
        ]
        for id in quantityTypes {
            if let t = HKQuantityType.quantityType(forIdentifier: id) {
                types.insert(t)
            }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }()

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else {
            print("[HealthKitCollector] HealthKit not available on this device")
            return
        }
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        store.authorizationStatus(for: type)
    }

    func deniedTypes() -> [HKObjectType] {
        Self.readTypes.filter { authorizationStatus(for: $0) == .sharingDenied }
    }

    // MARK: - Background Delivery & Observer Queries

    func enableBackgroundDelivery() {
        guard isAvailable else { return }
        for type in Self.readTypes {
            guard authorizationStatus(for: type) != .sharingDenied else { continue }

            store.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if let error {
                    print("[HealthKitCollector] BG delivery error for \(type): \(error)")
                }
            }

            let query = HKObserverQuery(sampleType: type as! HKSampleType, predicate: nil) {
                [weak self] _, completionHandler, error in
                guard error == nil else {
                    completionHandler()
                    return
                }
                Task {
                    let samples = await self?.fetchNewSamples(for: type as! HKSampleType) ?? []
                    if !samples.isEmpty {
                        self?.onNewSamplesReceived?(samples)
                    }
                    completionHandler()
                }
            }
            store.execute(query)
            observerQueries.append(query)
        }
    }

    func stopObserverQueries() {
        for query in observerQueries {
            store.stop(query)
        }
        observerQueries.removeAll()
    }

    // MARK: - Anchored Object Queries

    func fetchNewSamples(for sampleType: HKSampleType) async -> [HealthSample] {
        let anchor = anchors[sampleType]

        return await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: sampleType,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, newSamples, _, newAnchor, error in
                guard let newSamples, error == nil else {
                    continuation.resume(returning: [])
                    return
                }

                if let newAnchor {
                    self?.anchors[sampleType] = newAnchor
                    self?.persistAnchors()
                }

                let healthSamples = newSamples.compactMap { sample -> HealthSample? in
                    self?.convertToHealthSample(sample)
                }

                // De-duplicate before returning
                let deduplicated = self?.deduplicateSamples(healthSamples) ?? healthSamples
                continuation.resume(returning: deduplicated)
            }
            store.execute(query)
        }
    }

    /// Fetch new samples across all authorized types
    func fetchAllNewSamples() async -> [HealthSample] {
        guard isAvailable else { return [] }
        var allSamples: [HealthSample] = []
        for type in Self.readTypes {
            guard authorizationStatus(for: type) != .sharingDenied,
                  let sampleType = type as? HKSampleType else { continue }
            let samples = await fetchNewSamples(for: sampleType)
            allSamples.append(contentsOf: samples)
        }
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

    private func extractQuantity(_ sample: HKQuantitySample) -> (Double, String) {
        let typeId = sample.quantityType.identifier

        switch typeId {
        case HKQuantityTypeIdentifier.heartRate.rawValue,
             HKQuantityTypeIdentifier.restingHeartRate.rawValue,
             HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue:
            let unit = HKUnit.count().unitDivided(by: .minute())
            return (sample.quantity.doubleValue(for: unit), "count/min")

        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
            let unit = HKUnit.secondUnit(with: .milli)
            return (sample.quantity.doubleValue(for: unit), "ms")

        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            let unit = HKUnit.percent()
            return (sample.quantity.doubleValue(for: unit) * 100.0, "%")

        case HKQuantityTypeIdentifier.stepCount.rawValue:
            let unit = HKUnit.count()
            return (sample.quantity.doubleValue(for: unit), "count")

        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            let unit = HKUnit.kilocalorie()
            return (sample.quantity.doubleValue(for: unit), "kcal")

        case HKQuantityTypeIdentifier.respiratoryRate.rawValue:
            let unit = HKUnit.count().unitDivided(by: .minute())
            return (sample.quantity.doubleValue(for: unit), "breaths/min")

        default:
            // Fallback: try count
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
