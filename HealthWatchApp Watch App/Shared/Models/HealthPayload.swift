import Foundation

struct HealthPayload: Codable {
    let individualId: String
    let deviceId: String
    let timestamp: Date
    let samples: [HealthSample]
    let batchId: UUID            // For idempotent server-side processing
}
