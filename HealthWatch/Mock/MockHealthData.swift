import Foundation

/// Sample health data for populating charts in the demo build.
struct MockHealthData {
    /// Generate mock heart rate samples over the last 24 hours
    static func heartRateSamples(for individualId: String, hours: Int = 24) -> [HealthSample] {
        let now = Date()
        return (0..<hours * 4).map { index in
            let minutesAgo = Double(index) * 15
            let date = now.addingTimeInterval(-minutesAgo * 60)
            let baseRate = 72.0
            let variation = Double.random(in: -12...15)
            return HealthSample(
                id: UUID(),
                typeIdentifier: HealthKitTypes.heartRate,
                value: baseRate + variation,
                unit: "count/min",
                startDate: date,
                endDate: date,
                sourceBundleId: "com.apple.health"
            )
        }.reversed()
    }

    /// Generate mock SpO2 samples
    static func oxygenSaturationSamples(for individualId: String, hours: Int = 24) -> [HealthSample] {
        let now = Date()
        return (0..<hours).map { index in
            let hoursAgo = Double(index)
            let date = now.addingTimeInterval(-hoursAgo * 3600)
            let value = Double.random(in: 95...100)
            return HealthSample(
                id: UUID(),
                typeIdentifier: HealthKitTypes.oxygenSaturation,
                value: value,
                unit: "%",
                startDate: date,
                endDate: date,
                sourceBundleId: "com.apple.health"
            )
        }.reversed()
    }

    /// Generate mock step count samples (hourly totals)
    static func stepCountSamples(for individualId: String, hours: Int = 24) -> [HealthSample] {
        let now = Date()
        return (0..<hours).map { index in
            let hoursAgo = Double(index)
            let startDate = now.addingTimeInterval(-hoursAgo * 3600)
            let endDate = startDate.addingTimeInterval(3600)
            let steps = Double(Int.random(in: 0...1200))
            return HealthSample(
                id: UUID(),
                typeIdentifier: HealthKitTypes.stepCount,
                value: steps,
                unit: "count",
                startDate: startDate,
                endDate: endDate,
                sourceBundleId: "com.apple.health"
            )
        }.reversed()
    }

    /// Generate mock respiratory rate samples
    static func respiratoryRateSamples(for individualId: String, hours: Int = 24) -> [HealthSample] {
        let now = Date()
        return (0..<hours * 2).map { index in
            let minutesAgo = Double(index) * 30
            let date = now.addingTimeInterval(-minutesAgo * 60)
            let value = Double.random(in: 12...20)
            return HealthSample(
                id: UUID(),
                typeIdentifier: HealthKitTypes.respiratoryRate,
                value: value,
                unit: "count/min",
                startDate: date,
                endDate: date,
                sourceBundleId: "com.apple.health"
            )
        }.reversed()
    }

    /// Get all mock samples for a given individual
    static func allSamples(for individualId: String) -> [HealthSample] {
        heartRateSamples(for: individualId)
        + oxygenSaturationSamples(for: individualId)
        + stepCountSamples(for: individualId)
        + respiratoryRateSamples(for: individualId)
    }
}
