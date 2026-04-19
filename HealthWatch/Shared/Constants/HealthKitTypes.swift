import Foundation

/// HealthKit type identifiers used throughout the app.
/// Kept as strings so this code doesn't need to import HealthKit directly.
enum HealthKitTypes {
    static let heartRate = "HKQuantityTypeIdentifierHeartRate"
    static let restingHeartRate = "HKQuantityTypeIdentifierRestingHeartRate"
    static let stepCount = "HKQuantityTypeIdentifierStepCount"
    static let sleepAnalysis = "HKCategoryTypeIdentifierSleepAnalysis"

    /// Human-readable display name for a HealthKit type identifier
    static func displayName(for identifier: String) -> String {
        switch identifier {
        case heartRate: return "Heart Rate"
        case restingHeartRate: return "Resting Heart Rate"
        case stepCount: return "Steps"
        case sleepAnalysis: return "Sleep"
        default: return identifier
        }
    }

    /// Unit string for a HealthKit type identifier
    static func unit(for identifier: String) -> String {
        switch identifier {
        case heartRate, restingHeartRate:
            return "BPM"
        case stepCount:
            return "steps"
        case sleepAnalysis:
            return "category"
        default:
            return ""
        }
    }

    // MARK: - Sleep Stage Values

    /// Raw values from HKCategoryValueSleepAnalysis
    enum SleepStage: Int {
        case inBed = 0
        case asleepUnspecified = 1
        case awake = 2
        case asleepCore = 3
        case asleepDeep = 4
        case asleepREM = 5

        var displayName: String {
            switch self {
            case .inBed: return "In Bed"
            case .asleepUnspecified: return "Asleep"
            case .awake: return "Awake"
            case .asleepCore: return "Core"
            case .asleepDeep: return "Deep"
            case .asleepREM: return "REM"
            }
        }

        var isAsleep: Bool {
            switch self {
            case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
                return true
            default:
                return false
            }
        }
    }
}
