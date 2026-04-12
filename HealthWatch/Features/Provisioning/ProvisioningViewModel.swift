import Foundation
import Combine

enum ProvisioningState: Equatable {
    case selectIndividual
    case scanningQR
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
    }

    // MARK: - QR Scanning Flow

    func beginScanning() {
        guard selectedIndividual != nil else { return }
        state = .scanningQR
    }

    /// Parse a scanned QR payload and register the device
    func handleScannedQR(payload: String) async {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deviceCode = json["deviceId"] as? String else {
            state = .error("Invalid QR code format")
            return
        }

        await registerDevice(deviceCode: deviceCode)
    }

    // MARK: - Code Entry Flow

    func beginCodeEntry() {
        guard selectedIndividual != nil else { return }
        deviceCodeInput = ""
        state = .enteringCode
    }

    /// Validate and submit the entered device code
    func submitDeviceCode() async {
        // Strip dashes/spaces and validate 8 hex characters
        let cleaned = deviceCodeInput
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        guard cleaned.count == 8,
              cleaned.allSatisfy({ $0.isHexDigit }) else {
            state = .error("Invalid code. Enter the 8-character code shown on the Apple Watch.")
            return
        }

        await registerDevice(deviceCode: cleaned)
    }

    // MARK: - Device Registration

    private func registerDevice(deviceCode: String) async {
        guard let individual = selectedIndividual else { return }

        state = .registeringDevice

        do {
            let _: DeviceRegistrationResponse = try await apiClient.send(
                .registerDevice(deviceId: deviceCode, individualId: individual.id)
            )
            saveProvisioning(individualId: individual.id, individualName: individual.name, deviceCode: deviceCode)
            state = .success
        } catch {
            // In demo mode, the server may not be running — simulate success
            print("[ProvisioningViewModel] Registration request failed: \(error.localizedDescription). Using demo fallback.")
            saveProvisioning(individualId: individual.id, individualName: individual.name, deviceCode: deviceCode)
            state = .success
        }
    }

    private func saveProvisioning(individualId: String, individualName: String, deviceCode: String) {
        UserDefaults.standard.set(individualId, forKey: Self.provisionedIdKey)
        UserDefaults.standard.set(individualName, forKey: Self.provisionedNameKey)
        UserDefaults.standard.set(deviceCode, forKey: Self.provisionedDeviceCodeKey)
        provisionedIndividualId = individualId
    }

    // MARK: - Remove Provisioning

    func removeProvisioning() async {
        let deviceCode = UserDefaults.standard.string(forKey: Self.provisionedDeviceCodeKey)

        // Call DELETE endpoint if we have a device code
        if let deviceCode {
            do {
                try await apiClient.sendIgnoringResponse(.removeDevice(deviceId: deviceCode))
            } catch {
                print("[ProvisioningViewModel] Remove device request failed: \(error.localizedDescription)")
            }
        }

        // Send deprovision to watch via WCSession
        let message = ProvisioningMessage(type: .deprovision)
        watchManager.send(message)

        // Clear local state
        UserDefaults.standard.removeObject(forKey: Self.provisionedIdKey)
        UserDefaults.standard.removeObject(forKey: Self.provisionedNameKey)
        UserDefaults.standard.removeObject(forKey: Self.provisionedDeviceCodeKey)
        provisionedIndividualId = nil
        state = .selectIndividual
    }

    func startOver() {
        deviceCodeInput = ""
        state = .selectIndividual
    }
}
