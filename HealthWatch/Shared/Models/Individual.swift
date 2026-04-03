import Foundation

enum IndividualStatus: String, Codable {
    case normal
    case attention
    case offline
}

struct Individual: Codable, Identifiable {
    let id: String
    let name: String
    let status: IndividualStatus
}

struct IndividualSummary: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let status: IndividualStatus
    let lastSyncDate: Date?
    let latestHeartRate: Double?
}

extension Individual {
    func toSummary(lastSyncDate: Date? = nil, latestHeartRate: Double? = nil) -> IndividualSummary {
        IndividualSummary(
            id: id,
            name: name,
            status: status,
            lastSyncDate: lastSyncDate,
            latestHeartRate: latestHeartRate
        )
    }
}
