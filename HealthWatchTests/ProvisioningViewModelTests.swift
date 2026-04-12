import Testing
@testable import HealthWatch

struct ProvisioningViewModelTests {

    @Test("Initial state is selectIndividual")
    @MainActor
    func initialState() {
        let vm = ProvisioningViewModel(watchManager: WatchConnectivityManager())
        if case .selectIndividual = vm.state {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected selectIndividual state")
        }
    }

    @Test("Available individuals are loaded from mock data")
    @MainActor
    func availableIndividuals() {
        let vm = ProvisioningViewModel(watchManager: WatchConnectivityManager())
        #expect(vm.availableIndividuals.count == 5)
        #expect(vm.availableIndividuals[0].name == "Alice Johnson")
    }

    @Test("Begin code entry requires selected individual")
    @MainActor
    func beginCodeEntryRequiresSelection() {
        let vm = ProvisioningViewModel(watchManager: WatchConnectivityManager())
        vm.beginCodeEntry()
        // Should stay in selectIndividual since no individual selected
        #expect(vm.state == .selectIndividual)
    }

    @Test("Begin code entry transitions to enteringCode")
    @MainActor
    func beginCodeEntryTransitions() {
        let vm = ProvisioningViewModel(watchManager: WatchConnectivityManager())
        vm.selectedIndividual = vm.availableIndividuals[0]
        vm.beginCodeEntry()
        #expect(vm.state == .enteringCode)
    }

    @Test("Submit invalid device code produces error")
    @MainActor
    func submitInvalidCode() async {
        let vm = ProvisioningViewModel(watchManager: WatchConnectivityManager())
        vm.selectedIndividual = vm.availableIndividuals[0]
        vm.deviceCodeInput = "XYZ"
        await vm.submitDeviceCode()
        if case .error = vm.state {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected error state for invalid code")
        }
    }

    @Test("Submit valid device code triggers registration")
    @MainActor
    func submitValidCode() async {
        let vm = ProvisioningViewModel(watchManager: WatchConnectivityManager())
        vm.selectedIndividual = vm.availableIndividuals[0]
        vm.deviceCodeInput = "A3B7-9F2E"
        await vm.submitDeviceCode()
        // In demo mode, registration falls back to success
        #expect(vm.state == .success)
        #expect(vm.provisionedIndividualId == vm.availableIndividuals[0].id)
    }

    @Test("Begin scanning requires selected individual")
    @MainActor
    func beginScanningRequiresSelection() {
        let vm = ProvisioningViewModel(watchManager: WatchConnectivityManager())
        vm.beginScanning()
        #expect(vm.state == .selectIndividual)
    }

    @Test("Begin scanning transitions to scanningQR")
    @MainActor
    func beginScanningTransitions() {
        let vm = ProvisioningViewModel(watchManager: WatchConnectivityManager())
        vm.selectedIndividual = vm.availableIndividuals[0]
        vm.beginScanning()
        #expect(vm.state == .scanningQR)
    }

    @Test("Handle invalid QR payload produces error")
    @MainActor
    func handleInvalidQR() async {
        let vm = ProvisioningViewModel(watchManager: WatchConnectivityManager())
        vm.selectedIndividual = vm.availableIndividuals[0]
        await vm.handleScannedQR(payload: "not-json")
        #expect(vm.state == .error("Invalid QR code format"))
    }

    @Test("Handle valid QR payload triggers registration")
    @MainActor
    func handleValidQR() async {
        let vm = ProvisioningViewModel(watchManager: WatchConnectivityManager())
        vm.selectedIndividual = vm.availableIndividuals[0]
        let payload = """
        {"app":"healthwatch","version":1,"deviceId":"A3B79F2E"}
        """
        await vm.handleScannedQR(payload: payload)
        // In demo mode, registration falls back to success
        #expect(vm.state == .success)
        #expect(vm.provisionedIndividualId == vm.availableIndividuals[0].id)
    }

    @Test("Start over resets state")
    @MainActor
    func startOver() {
        let vm = ProvisioningViewModel(watchManager: WatchConnectivityManager())
        vm.state = .error("test")
        vm.startOver()
        #expect(vm.state == .selectIndividual)
    }
}
