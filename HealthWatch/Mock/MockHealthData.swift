import Foundation

/// Sample health data for populating charts in the demo build.
struct MockHealthData {
    /// Generate mock heart rate samples over the given hours
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

    /// Generate mock sleep samples for the last night
    static func sleepSamples(for individualId: String, hours: Int = 24) -> [HealthSample] {
        // Generate a single night's sleep session (roughly 7-8 hours)
        let calendar = Calendar.current
        let now = Date()

        // Bedtime: last night around 11 PM
        var bedtimeComponents = calendar.dateComponents([.year, .month, .day], from: now.addingTimeInterval(-24 * 3600))
        bedtimeComponents.hour = 23
        bedtimeComponents.minute = Int.random(in: 0...30)
        let bedtime = calendar.date(from: bedtimeComponents) ?? now.addingTimeInterval(-8 * 3600)

        var samples: [HealthSample] = []
        var current = bedtime

        // Sleep stages cycle: Core → Deep → Core → REM → repeat, with occasional awake
        let stages: [(HealthKitTypes.SleepStage, Int)] = [
            (.asleepCore, 45),
            (.asleepDeep, 30),
            (.asleepCore, 40),
            (.asleepREM, 20),
            (.awake, 5),
            (.asleepCore, 50),
            (.asleepDeep, 25),
            (.asleepCore, 35),
            (.asleepREM, 25),
            (.asleepCore, 40),
            (.asleepREM, 30),
            (.awake, 3),
            (.asleepCore, 30),
            (.asleepREM, 20),
        ]

        for (stage, minutes) in stages {
            let end = current.addingTimeInterval(Double(minutes) * 60)
            samples.append(HealthSample(
                id: UUID(),
                typeIdentifier: HealthKitTypes.sleepAnalysis,
                value: Double(stage.rawValue),
                unit: "category",
                startDate: current,
                endDate: end,
                sourceBundleId: "com.apple.health"
            ))
            current = end
        }

        return samples
    }

    /// Get all mock samples for a given individual
    static func allSamples(for individualId: String) -> [HealthSample] {
        heartRateSamples(for: individualId)
        + stepCountSamples(for: individualId)
        + sleepSamples(for: individualId)
    }
}
