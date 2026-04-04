import Testing
@testable import HealthWatch

struct DashboardViewModelTests {

    @Test("Initial state is pre-populated with mock individuals")
    @MainActor
    func initialState() {
        let vm = DashboardViewModel()
        #expect(vm.individuals.count == 5)
        #expect(!vm.isLoading)
        #expect(vm.error == nil)
    }

    @Test("Mock individuals have names from MockIndividuals")
    @MainActor
    func mockNames() {
        let vm = DashboardViewModel()
        let names = vm.individuals.map(\.name)
        #expect(names.contains("Alice Johnson"))
        #expect(names.contains("Bob Martinez"))
        #expect(names.contains("Carol Chen"))
    }

    @Test("Mock individuals have heart rates populated")
    @MainActor
    func mockHeartRates() {
        let vm = DashboardViewModel()
        for individual in vm.individuals {
            #expect(individual.latestHeartRate != nil)
        }
    }

    @Test("Mock individuals have sync dates populated")
    @MainActor
    func mockSyncDates() {
        let vm = DashboardViewModel()
        for individual in vm.individuals {
            #expect(individual.lastSyncDate != nil)
        }
    }

    @Test("stopPolling cancels polling task without crash")
    @MainActor
    func stopPolling() {
        let vm = DashboardViewModel()
        vm.startPolling()
        vm.stopPolling()
        // Should not crash
        #expect(true)
    }
}
