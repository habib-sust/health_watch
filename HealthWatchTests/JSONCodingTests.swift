import Testing
import Foundation
@testable import HealthWatch

struct JSONCodingTests {

    @Test("HealthSample encodes and decodes with snake_case keys")
    func healthSampleCoding() throws {
        let sample = HealthSample(
            id: UUID(),
            typeIdentifier: "HKQuantityTypeIdentifierHeartRate",
            value: 72.0,
            unit: "count/min",
            startDate: Date(),
            endDate: Date(),
            sourceBundleId: "com.apple.health"
        )

        let data = try JSONEncoder.healthWatch.encode(sample)
        let json = String(data: data, encoding: .utf8)!

        // Verify snake_case keys
        #expect(json.contains("type_identifier"))
        #expect(json.contains("start_date"))
        #expect(json.contains("end_date"))
        #expect(json.contains("source_bundle_id"))

        // Verify round-trip
        let decoded = try JSONDecoder.healthWatch.decode(HealthSample.self, from: data)
        #expect(decoded.id == sample.id)
        #expect(decoded.value == sample.value)
        #expect(decoded.typeIdentifier == sample.typeIdentifier)
    }

    @Test("HealthPayload encodes with snake_case keys")
    func healthPayloadCoding() throws {
        let payload = HealthPayload(
            individualId: "ind-001",
            deviceId: "device-123",
            timestamp: Date(),
            samples: [],
            batchId: UUID()
        )

        let data = try JSONEncoder.healthWatch.encode(payload)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("individual_id"))
        #expect(json.contains("device_id"))
        #expect(json.contains("batch_id"))

        let decoded = try JSONDecoder.healthWatch.decode(HealthPayload.self, from: data)
        #expect(decoded.individualId == payload.individualId)
        #expect(decoded.batchId == payload.batchId)
    }

    @Test("ProvisioningMessage encodes and decodes")
    func provisioningMessageCoding() throws {
        let message = ProvisioningMessage(type: .deprovision)

        let data = try JSONEncoder.healthWatch.encode(message)
        let decoded = try JSONDecoder.healthWatch.decode(ProvisioningMessage.self, from: data)

        #expect(decoded.type == .deprovision)
    }

    @Test("ISO8601 date encoding format")
    func dateEncoding() throws {
        let sample = HealthSample(
            id: UUID(),
            typeIdentifier: "test",
            value: 1.0,
            unit: "unit",
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 0),
            sourceBundleId: "test"
        )

        let data = try JSONEncoder.healthWatch.encode(sample)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("1970"))
    }
}
