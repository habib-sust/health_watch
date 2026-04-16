import Foundation
import Combine
import os

enum ProvisioningState: Equatable {
    case selectIndividual
    case scanningQR
    case scannedQR
    case enteringCode
    case registeringDevice
    case success
    case error(String)
}

@MainActor
final class ProvisioningViewModel: ObservableObject {
    @Published var state: ProvisioningState = .selectIndividual
    @Published var selectedIndividual: Individual?
    @Published var provisionedIndividualId: String?
    @Published var showRemoveConfirmation = false
    @Published var deviceCodeInput = ""

    let availableIndividuals = MockIndividuals.all

    private static let provisionedIdKey = "provisionedIndividualId"
    private static let provisionedNameKey = "provisionedIndividualName"
    private static let provisionedDeviceCodeKey = "provisionedDeviceCode"

    private let watchManager: WatchConnectivityManager
    private let apiClient: APIClient

    init(watchManager: WatchConnectivityManager) {
        self.watchManager = watchManager

        let url = URL(string: DemoConfiguration.serverURL)!
        let tokenStore = StaticTokenStore(token: DemoConfiguration.apiToken)
        self.apiClient = APIClient(baseURL: url, tokenStore: tokenStore)

        self.provisionedIndividualId = UserDefaults.standard.string(forKey: Self.provisionedIdKey)
        Logger.provisioning.info("ProvisioningViewModel initialized, existing provisioned ID: \(self.provisionedIndividualId ?? "none")")
    }

    // MARK: - QR Scanning Flow

    func beginScanning() {
        guard let individual = selectedIndividual else {
            Logger.provisioning.warning("beginScanning called with no individual selected")
            return
        }
        Logger.provisioning.info("Beginning QR scan for individual: \(individual.name) (\(individual.id))")
        state = .scanningQR
    }

    /// Parse a scanned QR payload, show confirmation, then register the device
    func handleScannedQR(payload: String) async {
        Logger.provisioning.info("Handling scanned QR payload: \(payload)")

        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deviceCode = json["deviceId"] as? String else {
            Logger.provisioning.error("Invalid QR code format — could not extract deviceId from payload")
            state = .error("Invalid QR code format")
            return
        }

        Logger.provisioning.info("QR scan successful — deviceId: \(deviceCode)")
        state = .scannedQR
        try? await Task.sleep(for: .seconds(1.5))
        await registerDevice(deviceCode: deviceCode)
    }

    // MARK: - Code Entry Flow

    func beginCodeEntry() {
        guard selectedIndividual != nil else {
            Logger.provisioning.warning("beginCodeEntry called with no individual selected")
            return
        }
        Logger.provisioning.info("Beginning manual code entry")
        deviceCodeInput = ""
        state = .enteringCode
    }

    /// Validate and submit the entered device code
    func submitDeviceCode() async {
        let cleaned = deviceCodeInput
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        Logger.provisioning.info("Submitting manual device code (length: \(cleaned.count))")

        guard cleaned.count == 8,
              cleaned.allSatisfy({ $0.isHexDigit }) else {
            Logger.provisioning.error("Invalid manual code: expected 8 hex chars, got \(cleaned.count) chars")
            state = .error("Invalid code. Enter the 8-character code shown on the Apple Watch.")
            return
        }

        Logger.provisioning.info("Manual code validated — deviceCode: \(cleaned)")
        await registerDevice(deviceCode: cleaned)
    }

    // MARK: - Device Registration

    private func registerDevice(deviceCode: String) async {
        guard let individual = selectedIndividual else {
            Logger.provisioning.error("registerDevice called with no individual selected")
            return
        }

        Logger.provisioning.info("Registering device \(deviceCode) for individual \(individual.name) (\(individual.id))")
        state = .registeringDevice

        do {
            let _: DeviceRegistrationResponse = try await apiClient.send(
                .registerDevice(deviceId: deviceCode, individualId: individual.id)
            )
            Logger.provisioning.info("Device registration API call succeeded")
            saveProvisioning(individualId: individual.id, individualName: individual.name, deviceCode: deviceCode)
            state = .success
        } catch {
            Logger.provisioning.warning("Registration API failed: \(error.localizedDescription) — using demo fallback")
            saveProvisioning(individualId: individual.id, individualName: individual.name, deviceCode: deviceCode)
            state = .success
        }
    }

    private func saveProvisioning(individualId: String, individualName: String, deviceCode: String) {
        UserDefaults.standard.set(individualId, forKey: Self.provisionedIdKey)
        UserDefaults.standard.set(individualName, forKey: Self.provisionedNameKey)
        UserDefaults.standard.set(deviceCode, forKey: Self.provisionedDeviceCodeKey)
        provisionedIndividualId = individualId
        Logger.provisioning.info("Provisioning saved — individualId: \(individualId), name: \(individualName), deviceCode: \(deviceCode)")
    }

    // MARK: - Remove Provisioning

    func removeProvisioning() async {
        let deviceCode = UserDefaults.standard.string(forKey: Self.provisionedDeviceCodeKey)
        Logger.provisioning.info("Removing provisioning — deviceCode: \(deviceCode ?? "none")")

        if let deviceCode {
            do {
                try await apiClient.sendIgnoringResponse(.removeDevice(deviceId: deviceCode))
                Logger.provisioning.info("Device removal API call succeeded")
            } catch {
                Logger.provisioning.error("Device removal API failed: \(error.localizedDescription)")
            }
        }

        let message = ProvisioningMessage(type: .deprovision)
        watchManager.send(message)
        Logger.provisioning.info("Deprovision message sent to watch")

        UserDefaults.standard.removeObject(forKey: Self.provisionedIdKey)
        UserDefaults.standard.removeObject(forKey: Self.provisionedNameKey)
        UserDefaults.standard.removeObject(forKey: Self.provisionedDeviceCodeKey)
        provisionedIndividualId = nil
        state = .selectIndividual
        Logger.provisioning.info("Provisioning data cleared, returned to selectIndividual state")
    }

    func startOver() {
        Logger.provisioning.info("Starting over — resetting to selectIndividual")
        deviceCodeInput = ""
        state = .selectIndividual
    }
}
