import HealthKit
import os

/// Actor-isolated HealthKit service for Daily Activity foreground queries.
/// Separate from HealthKitCollector, which handles background delivery for provisioning sync.
actor HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        if let rhr = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) { types.insert(rhr) }
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        types.insert(HKCategoryType(.sleepAnalysis))
        return types
    }()

    // MARK: - Authorization

    var authorizationStatus: HealthAuthStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .denied }
        // Check a representative type — if heart rate is determined, we've asked
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return .denied }
        switch store.authorizationStatus(for: hrType) {
        case .notDetermined: return .notDetermined
        case .sharingDenied: return .denied
        case .sharingAuthorized: return .authorized
        @unknown default: return .notDetermined
        }
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            Logger.healthKit.error("[HealthKitService] HealthKit not available")
            return
        }
        Logger.healthKit.info("[HealthKitService] Requesting authorization for \(self.readTypes.count) types")
        try await store.requestAuthorization(toShare: [], read: readTypes)
        Logger.healthKit.info("[HealthKitService] Authorization request completed")
    }

    // MARK: - Fetch All

    func fetchDailySnapshot() async -> DailyActivitySnapshot {
        Logger.healthKit.info("[HealthKitService] Fetching daily snapshot")

        async let hr = fetchHeartRateData()
        async let steps = fetchStepsData()
        async let hourly = fetchHourlySteps()
        async let hrHistory = fetchHeartRateHistory()
        async let sleep = fetchLastSleepSession()

        let snapshot = await DailyActivitySnapshot(
            heartRate: hr,
            steps: steps,
            sleep: sleep,
            heartRateHistory: hrHistory,
            hourlySteps: hourly
        )

        Logger.healthKit.info("[HealthKitService] Snapshot complete — HR: \(snapshot.heartRate.formattedCurrent), steps: \(snapshot.steps.formattedTotal), sleep: \(snapshot.sleep?.formattedTotal ?? "none")")
        return snapshot
    }

    // MARK: - Heart Rate

    private func fetchHeartRateData() async -> HeartRateData {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return HeartRateData() }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        var data = HeartRateData()

        // Today's stats
        let stats = await fetchStatistics(for: hrType, predicate: predicate, options: [.discreteMin, .discreteMax, .discreteAverage])
        data.min = stats?.minimumQuantity()?.doubleValue(for: bpmUnit)
        data.max = stats?.maximumQuantity()?.doubleValue(for: bpmUnit)
        data.avg = stats?.averageQuantity()?.doubleValue(for: bpmUnit)

        // Most recent reading
        if let sample = await fetchMostRecentSample(for: hrType) {
            data.current = sample.quantity.doubleValue(for: bpmUnit)
            data.lastReadingDate = sample.startDate
        }

        // Resting heart rate
        if let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            if let rhrSample = await fetchMostRecentSample(for: rhrType) {
                data.resting = rhrSample.quantity.doubleValue(for: bpmUnit)
            }
        }

        return data
    }

    private func fetchHeartRateHistory() async -> [ActivityDataPoint] {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let threeHoursAgo = Date().addingTimeInterval(-3 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: threeHoursAgo, end: Date(), options: .strictStartDate)

        let samples = await fetchQuantitySamples(for: hrType, predicate: predicate, limit: 100)
        return samples.map { ActivityDataPoint(date: $0.startDate, value: $0.quantity.doubleValue(for: bpmUnit)) }
    }

    // MARK: - Steps

    private func fetchStepsData() async -> StepsData {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return StepsData() }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        var data = StepsData()
        let stats = await fetchStatistics(for: stepType, predicate: predicate, options: .cumulativeSum)
        if let sum = stats?.sumQuantity()?.doubleValue(for: .count()) {
            data.totalToday = sum
            data.lastUpdated = Date()
        }
        return data
    }

    private func fetchHourlySteps() async -> [HourlyStepBucket] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startOfDay,
                intervalComponents: DateComponents(hour: 1)
            )

            query.initialResultsHandler = { _, collection, error in
                guard let collection else {
                    if let error { Logger.healthKit.error("[HealthKitService] Hourly steps error: \(error.localizedDescription)") }
                    continuation.resume(returning: [])
                    return
                }

                var buckets: [HourlyStepBucket] = []
                collection.enumerateStatistics(from: startOfDay, to: now) { stats, _ in
                    let hour = calendar.component(.hour, from: stats.startDate)
                    let steps = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    buckets.append(HourlyStepBucket(hour: hour, date: stats.startDate, steps: steps))
                }
                continuation.resume(returning: buckets)
            }
            self.store.execute(query)
        }
    }

    // MARK: - Sleep

    /// Query the last 18 hours of sleep data, group contiguous samples into sessions
    /// (gaps < 30 min), and return the most recent session.
    func fetchLastSleepSession() async -> SleepSession? {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let now = Date()
        let eighteenHoursAgo = now.addingTimeInterval(-18 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: eighteenHoursAgo, end: now, options: .strictStartDate)

        let samples = await fetchCategorySamples(for: sleepType, predicate: predicate)
        guard !samples.isEmpty else {
            Logger.healthKit.info("[HealthKitService] No sleep samples in last 18h")
            return nil
        }

        Logger.healthKit.info("[HealthKitService] Found \(samples.count) raw sleep samples")

        // Separate inBed from stage samples
        var stageSamples: [(stage: SleepStageType, start: Date, end: Date)] = []
        var inBedStart: Date?
        var inBedEnd: Date?

        for sample in samples {
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }

            switch value {
            case .inBed:
                if inBedStart == nil || sample.startDate < inBedStart! { inBedStart = sample.startDate }
                if inBedEnd == nil || sample.endDate > inBedEnd! { inBedEnd = sample.endDate }
            case .awake:
                stageSamples.append((.awake, sample.startDate, sample.endDate))
            case .asleepCore:
                stageSamples.append((.core, sample.startDate, sample.endDate))
            case .asleepDeep:
                stageSamples.append((.deep, sample.startDate, sample.endDate))
            case .asleepREM:
                stageSamples.append((.rem, sample.startDate, sample.endDate))
            case .asleepUnspecified:
                stageSamples.append((.unspecified, sample.startDate, sample.endDate))
            @unknown default:
                continue
            }
        }

        guard !stageSamples.isEmpty else {
            Logger.healthKit.info("[HealthKitService] Only inBed samples, no sleep stages")
            return nil
        }

        // Sort by start time
        let sorted = stageSamples.sorted { $0.start < $1.start }

        // Group into sessions — gap > 30 min starts a new session
        let maxGap: TimeInterval = 30 * 60
        var sessions: [[( stage: SleepStageType, start: Date, end: Date)]] = [[sorted[0]]]

        for i in 1..<sorted.count {
            let prev = sessions[sessions.count - 1].last!
            if sorted[i].start.timeIntervalSince(prev.end) > maxGap {
                sessions.append([sorted[i]])
            } else {
                sessions[sessions.count - 1].append(sorted[i])
            }
        }

        // Take the most recent (longest) session
        guard let lastSession = sessions.last else { return nil }

        let segments = lastSession.map { ActivitySleepSegment(stage: $0.stage, startDate: $0.start, endDate: $0.end) }

        var session = SleepSession(segments: segments)
        session.bedtime = inBedStart ?? segments.first?.startDate
        session.wakeTime = inBedEnd ?? segments.last?.endDate

        Logger.healthKit.info("[HealthKitService] Sleep session: \(session.formattedTotal), efficiency: \(session.formattedEfficiency), segments: \(segments.count)")
        return session
    }

    // MARK: - Generic HealthKit Query Helpers

    private func fetchStatistics(for type: HKQuantityType, predicate: NSPredicate?, options: HKStatisticsOptions) async -> HKStatistics? {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: options) { _, stats, error in
                if let error { Logger.healthKit.error("[HealthKitService] Statistics error for \(type.identifier): \(error.localizedDescription)") }
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

    private func fetchQuantitySamples(for type: HKQuantityType, predicate: NSPredicate?, limit: Int) async -> [HKQuantitySample] {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [sort]) { _, results, _ in
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
    }

    private func fetchCategorySamples(for type: HKCategoryType, predicate: NSPredicate?) async -> [HKCategorySample] {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, _ in
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
    }

    // MARK: - Observer Query Support

    /// Create an HKObserverQuery for the given type. The caller is responsible for
    /// executing and retaining the query. Returns nil if the type isn't available.
    nonisolated func makeObserverQuery(
        for typeIdentifier: HKQuantityTypeIdentifier,
        updateHandler: @escaping @Sendable () -> Void
    ) -> HKObserverQuery? {
        guard let sampleType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else { return nil }
        return HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
            if let error {
                Logger.healthKit.error("[HealthKitService] Observer error for \(typeIdentifier.rawValue): \(error.localizedDescription)")
            } else {
                updateHandler()
            }
            completionHandler()
        }
    }

    /// Create an HKObserverQuery for sleep analysis.
    nonisolated func makeSleepObserverQuery(
        updateHandler: @escaping @Sendable () -> Void
    ) -> HKObserverQuery {
        let sleepType = HKCategoryType(.sleepAnalysis)
        return HKObserverQuery(sampleType: sleepType, predicate: nil) { _, completionHandler, error in
            if let error {
                Logger.healthKit.error("[HealthKitService] Sleep observer error: \(error.localizedDescription)")
            } else {
                updateHandler()
            }
            completionHandler()
        }
    }

    /// Execute a query on the HealthKit store.
    func execute(_ query: HKQuery) {
        store.execute(query)
    }

    /// Stop a query on the HealthKit store.
    func stop(_ query: HKQuery) {
        store.stop(query)
    }
}
