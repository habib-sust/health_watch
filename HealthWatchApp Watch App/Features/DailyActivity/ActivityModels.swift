import SwiftUI
import HealthKit

// MARK: - Heart Rate

struct HeartRateData: Sendable {
    var current: Double?
    var resting: Double?
    var min: Double?
    var max: Double?
    var avg: Double?
    var lastReadingDate: Date?

    var formattedCurrent: String {
        current.map { "\(Int($0))" } ?? "--"
    }

    var rangeText: String {
        guard let lo = min, let hi = max else { return "--" }
        return "\(Int(lo))–\(Int(hi))"
    }
}

// MARK: - Steps

struct StepsData: Sendable {
    var totalToday: Double = 0
    var goal: Double = 5_000
    var lastUpdated: Date?

    var progress: Double {
        guard goal > 0 else { return 0 }
        return Swift.min(totalToday / goal, 1.0)
    }

    var formattedTotal: String {
        if totalToday >= 10_000 {
            return String(format: "%.1fk", totalToday / 1000)
        }
        return "\(Int(totalToday))"
    }
}

struct HourlyStepBucket: Identifiable, Sendable {
    let id = UUID()
    let hour: Int
    let date: Date
    let steps: Double
    let source: String
    let souceBundle: String
}

// MARK: - Sleep

enum SleepStageType: String, CaseIterable, Sendable {
    case deep = "Deep"
    case core = "Core"
    case rem = "REM"
    case awake = "Awake"
    case unspecified = "Asleep"

    var color: Color {
        switch self {
        case .deep: .purple
        case .core: .indigo
        case .rem: .cyan
        case .awake: .orange
        case .unspecified: .blue
        }
    }

    var sortOrder: Int {
        switch self {
        case .deep: 0
        case .core: 1
        case .rem: 2
        case .unspecified: 3
        case .awake: 4
        }
    }
}

struct ActivitySleepSegment: Identifiable, Sendable {
    let id = UUID()
    let stage: SleepStageType
    let startDate: Date
    let endDate: Date

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }
}

struct SleepSession: Sendable {
    var segments: [ActivitySleepSegment] = []
    var bedtime: Date?
    var wakeTime: Date?

    var totalSleep: TimeInterval { deepSleep + coreSleep + remSleep + unspecifiedSleep }
    var deepSleep: TimeInterval { total(for: .deep) }
    var coreSleep: TimeInterval { total(for: .core) }
    var remSleep: TimeInterval { total(for: .rem) }
    var awakeTime: TimeInterval { total(for: .awake) }
    var unspecifiedSleep: TimeInterval { total(for: .unspecified) }

    var timeInBed: TimeInterval {
        guard let bed = bedtime, let wake = wakeTime else { return totalSleep + awakeTime }
        return wake.timeIntervalSince(bed)
    }

    var efficiency: Double {
        let inBed = timeInBed
        guard inBed > 0 else { return 0 }
        return totalSleep / inBed
    }

    var hasSleepData: Bool { totalSleep > 0 }

    var formattedTotal: String { Self.formatDuration(totalSleep) }
    var formattedDeep: String { Self.formatDuration(deepSleep) }
    var formattedCore: String { Self.formatDuration(coreSleep) }
    var formattedREM: String { Self.formatDuration(remSleep) }
    var formattedAwake: String { Self.formatDuration(awakeTime) }
    var formattedEfficiency: String { "\(Int(efficiency * 100))%" }

    static func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func total(for stage: SleepStageType) -> TimeInterval {
        segments.filter { $0.stage == stage }.reduce(0) { $0 + $1.duration }
    }
}

// MARK: - Chart Data Point

struct ActivityDataPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Authorization

enum HealthAuthStatus: Sendable {
    case notDetermined
    case authorized
    case denied
}

// MARK: - Snapshot for UI

struct DailyActivitySnapshot: Sendable {
    var heartRate: HeartRateData
    var steps: StepsData
    var sleep: SleepSession?
    var heartRateHistory: [ActivityDataPoint]
    var hourlySteps: [HourlyStepBucket]

    static let empty = DailyActivitySnapshot(
        heartRate: HeartRateData(),
        steps: StepsData(),
        sleep: nil,
        heartRateHistory: [],
        hourlySteps: []
    )
}
