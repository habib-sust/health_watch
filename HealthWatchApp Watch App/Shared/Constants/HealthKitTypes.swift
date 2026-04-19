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
}
