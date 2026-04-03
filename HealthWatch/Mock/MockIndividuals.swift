import Foundation

/// Pre-loaded individual list for the demo build.
/// In production this comes from GET /api/v1/individuals.
struct MockIndividuals {
    static let all: [Individual] = [
        Individual(id: "ind-001", name: "Alice Johnson", status: .normal),
        Individual(id: "ind-002", name: "Bob Martinez", status: .normal),
        Individual(id: "ind-003", name: "Carol Chen", status: .attention),
        Individual(id: "ind-004", name: "David Park", status: .offline),
        Individual(id: "ind-005", name: "Eva Williams", status: .normal),
    ]
}
