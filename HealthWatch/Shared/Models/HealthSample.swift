import Foundation

struct HealthSample: Codable, Identifiable {
    let id: UUID
    let typeIdentifier: String   // e.g. "HKQuantityTypeIdentifierHeartRate"
    let value: Double
    let unit: String             // e.g. "count/min"
    let startDate: Date
    let endDate: Date
    let sourceBundleId: String
}
