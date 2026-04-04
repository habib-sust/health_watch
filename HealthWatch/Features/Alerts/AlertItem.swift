import Foundation

enum AlertSeverity: String, Codable {
    case critical
    case warning
    case info
}

struct AlertItem: Codable, Identifiable {
    let id: String
    let individualId: String
    let individualName: String
    let metric: String
    let value: Double
    let threshold: Double
    let severity: AlertSeverity
    let message: String
    let timestamp: Date
    let acknowledged: Bool
}
