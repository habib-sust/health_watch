import Foundation

/// HealthKit type identifiers used throughout the app.
/// Kept as strings so this code doesn't need to import HealthKit directly.
enum HealthKitTypes {
    static let heartRate = "HKQuantityTypeIdentifierHeartRate"
    static let restingHeartRate = "HKQuantityTypeIdentifierRestingHeartRate"
    static let heartRateVariabilitySDNN = "HKQuantityTypeIdentifierHeartRateVariabilitySDNN"
    static let oxygenSaturation = "HKQuantityTypeIdentifierOxygenSaturation"
    static let stepCount = "HKQuantityTypeIdentifierStepCount"
    static let activeEnergyBurned = "HKQuantityTypeIdentifierActiveEnergyBurned"
    static let respiratoryRate = "HKQuantityTypeIdentifierRespiratoryRate"
    static let walkingHeartRateAverage = "HKQuantityTypeIdentifierWalkingHeartRateAverage"
    static let sleepAnalysis = "HKCategoryTypeIdentifierSleepAnalysis"

    /// Human-readable display name for a HealthKit type identifier
    static func displayName(for identifier: String) -> String {
        switch identifier {
        case heartRate: return "Heart Rate"
        case restingHeartRate: return "Resting Heart Rate"
        case heartRateVariabilitySDNN: return "HRV (SDNN)"
        case oxygenSaturation: return "Blood Oxygen"
        case stepCount: return "Steps"
        case activeEnergyBurned: return "Active Energy"
        case respiratoryRate: return "Respiratory Rate"
        case walkingHeartRateAverage: return "Walking Heart Rate"
        case sleepAnalysis: return "Sleep"
        default: return identifier
        }
    }

    /// Unit string for a HealthKit type identifier
    static func unit(for identifier: String) -> String {
        switch identifier {
        case heartRate, restingHeartRate, walkingHeartRateAverage:
            return "BPM"
        case heartRateVariabilitySDNN:
            return "ms"
        case oxygenSaturation:
            return "%"
        case stepCount:
            return "steps"
        case activeEnergyBurned:
            return "kcal"
        case respiratoryRate:
            return "breaths/min"
        case sleepAnalysis:
            return "category"
        default:
            return ""
        }
    }
}
