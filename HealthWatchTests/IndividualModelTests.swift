import Testing
import Foundation
@testable import HealthWatch

struct IndividualModelTests {

    @Test("Individual conforms to Codable")
    func individualCoding() throws {
        let individual = Individual(id: "ind-001", name: "Alice Johnson", status: .normal)
        let data = try JSONEncoder.healthWatch.encode(individual)
        let decoded = try JSONDecoder.healthWatch.decode(Individual.self, from: data)
        #expect(decoded.id == individual.id)
        #expect(decoded.name == individual.name)
        #expect(decoded.status == .normal)
    }

    @Test("toSummary creates correct IndividualSummary")
    func toSummary() {
        let individual = Individual(id: "ind-001", name: "Alice", status: .attention)
        let date = Date()
        let summary = individual.toSummary(lastSyncDate: date, latestHeartRate: 75.0)
        #expect(summary.id == "ind-001")
        #expect(summary.name == "Alice")
        #expect(summary.status == .attention)
        #expect(summary.lastSyncDate == date)
        #expect(summary.latestHeartRate == 75.0)
    }

    @Test("toSummary defaults optional fields to nil")
    func toSummaryDefaults() {
        let individual = Individual(id: "ind-001", name: "Bob", status: .offline)
        let summary = individual.toSummary()
        #expect(summary.lastSyncDate == nil)
        #expect(summary.latestHeartRate == nil)
    }

    @Test("IndividualSummary conforms to Hashable")
    func summaryHashable() {
        let a = IndividualSummary(id: "ind-001", name: "A", status: .normal, lastSyncDate: nil, latestHeartRate: nil)
        let b = IndividualSummary(id: "ind-002", name: "B", status: .normal, lastSyncDate: nil, latestHeartRate: nil)
        var set = Set<IndividualSummary>()
        set.insert(a)
        set.insert(b)
        #expect(set.count == 2)
    }

    @Test("IndividualStatus raw values match JSON expectations")
    func statusRawValues() {
        #expect(IndividualStatus.normal.rawValue == "normal")
        #expect(IndividualStatus.attention.rawValue == "attention")
        #expect(IndividualStatus.offline.rawValue == "offline")
    }

    @Test("MockIndividuals has 5 entries")
    func mockCount() {
        #expect(MockIndividuals.all.count == 5)
    }
}
