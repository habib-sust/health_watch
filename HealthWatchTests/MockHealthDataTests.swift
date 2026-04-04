import Testing
@testable import HealthWatch

struct MockHealthDataTests {

    @Test("Heart rate samples generate correct count for 24 hours")
    func heartRateCount() {
        let samples = MockHealthData.heartRateSamples(for: "ind-001", hours: 24)
        // 4 samples per hour * 24 hours = 96
        #expect(samples.count == 96)
    }

    @Test("Heart rate samples have correct type identifier")
    func heartRateType() {
        let samples = MockHealthData.heartRateSamples(for: "ind-001", hours: 1)
        for sample in samples {
            #expect(sample.typeIdentifier == HealthKitTypes.heartRate)
            #expect(sample.unit == "count/min")
        }
    }

    @Test("Heart rate values are in reasonable range")
    func heartRateRange() {
        let samples = MockHealthData.heartRateSamples(for: "ind-001", hours: 24)
        for sample in samples {
            #expect(sample.value >= 60.0 && sample.value <= 87.0)
        }
    }

    @Test("SpO2 samples generate correct count for 24 hours")
    func oxygenCount() {
        let samples = MockHealthData.oxygenSaturationSamples(for: "ind-001", hours: 24)
        #expect(samples.count == 24)
    }

    @Test("SpO2 values are in valid range")
    func oxygenRange() {
        let samples = MockHealthData.oxygenSaturationSamples(for: "ind-001", hours: 24)
        for sample in samples {
            #expect(sample.value >= 95.0 && sample.value <= 100.0)
        }
    }

    @Test("Step count samples generate correct count for 24 hours")
    func stepCount() {
        let samples = MockHealthData.stepCountSamples(for: "ind-001", hours: 24)
        #expect(samples.count == 24)
    }

    @Test("Respiratory rate samples generate correct count for 24 hours")
    func respiratoryCount() {
        let samples = MockHealthData.respiratoryRateSamples(for: "ind-001", hours: 24)
        // 2 samples per hour * 24 hours = 48
        #expect(samples.count == 48)
    }

    @Test("allSamples combines all types")
    func allSamples() {
        let samples = MockHealthData.allSamples(for: "ind-001")
        // 96 HR + 24 SpO2 + 24 steps + 48 resp = 192
        #expect(samples.count == 192)
    }

    @Test("Samples are sorted chronologically (oldest first)")
    func chronologicalOrder() {
        let samples = MockHealthData.heartRateSamples(for: "ind-001", hours: 2)
        for i in 1..<samples.count {
            #expect(samples[i].startDate >= samples[i - 1].startDate)
        }
    }
}
