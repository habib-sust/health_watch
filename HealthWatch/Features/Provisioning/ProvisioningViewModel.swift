import Foundation
import Combine
import Security

enum ProvisioningState: Equatable {
    case selectIndividual
    case checkingWatchConnection
    case watchNotReachable
    case displayingCode(code: String, expiresAt: Date)
    case waitingForCodeEntry
    case verifyingCode
    case codeAccepted
    case codeFailed(attemptsRemaining: Int)
    case sendingConfig
    case success
    case locked(unlockAt: Date)
    case error(String)

    static func == (lhs: ProvisioningState, rhs: ProvisioningState) -> Bool {
        switch (lhs, rhs) {
        case (.selectIndividual, .selectIndividual),
             (.checkingWatchConnection, .checkingWatchConnection),
             (.watchNotReachable, .watchNotReachable),
             (.waitingForCodeEntry, .waitingForCodeEntry),
             (.verifyingCode, .verifyingCode),
             (.codeAccepted, .codeAccepted),
             (.sendingConfig, .sendingConfig),
             (.success, .success):
            return true
        case (.displayingCode(let a, _), .displayingCode(let b, _)):
            return a == b
        case (.codeFailed(let a), .codeFailed(let b)):
            return a == b
        case (.locked(let a), .locked(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

@MainActor
final class ProvisioningViewModel: ObservableObject {
    @Published var state: ProvisioningState = .selectIndividual
    @Published var selectedIndividual: Individual?

    /// Demo: individuals loaded from mock data
    let availableIndividuals = MockIndividuals.all

    private let watchManager: WatchConnectivityManager
    private var generatedCode: String?
    private var codeGeneratedAt: Date?
    private var failedAttempts = 0
    private let maxAttempts = AppConstants.maxProvisioningAttempts
    private let codeExpirySeconds = AppConstants.provisioningCodeExpiry

    init(watchManager: WatchConnectivityManager) {
        self.watchManager = watchManager
        setupCallbacks()
    }

    private func setupCallbacks() {
        watchManager.onCodeReceived = { [weak self] code in
            Task { @MainActor in
                await self?.handleCodeFromWatch(code)
            }
        }

        watchManager.onAckReceived = { [weak self] in
            Task { @MainActor in
                self?.state = .success
            }
        }
    }

    // MARK: - Code Generation (using SecRandomCopyBytes)

    func generateCode() -> String {
        var randomBytes = [UInt8](repeating: 0, count: 2)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let number = (Int(randomBytes[0]) << 8 | Int(randomBytes[1])) % 10000
        let code = String(format: "%04d", number)
        generatedCode = code
        codeGeneratedAt = Date()
        return code
    }

    func verifyCode(_ enteredCode: String) -> Bool {
        guard let generated = generatedCode,
              let generatedAt = codeGeneratedAt,
              Date().timeIntervalSince(generatedAt) < codeExpirySeconds
        else {
            return false // expired
        }
        return enteredCode == generated
    }

    // MARK: - Provisioning Flow

    func initiateProvisioning() async {
        guard selectedIndividual != nil else { return }

        state = .checkingWatchConnection

        // In simulator, skip the reachability check for demo purposes
        #if !targetEnvironment(simulator)
        guard watchManager.isWatchReachable else {
            state = .watchNotReachable
            return
        }
        #endif

        let code = generateCode()
        state = .displayingCode(
            code: code,
            expiresAt: Date().addingTimeInterval(codeExpirySeconds)
        )

        // Send initiation message to watch — state stays on .displayingCode
        // so the user can see the code while the watch user enters it.
        // When the watch sends back a code, handleCodeFromWatch() transitions the state.
        let message = ProvisioningMessage(
            type: .initiate,
            individualName: selectedIndividual?.name
        )
        watchManager.send(message)
    }

    func handleCodeFromWatch(_ code: String) async {
        state = .verifyingCode

        if verifyCode(code) {
            state = .codeAccepted
            await sendConfiguration()
        } else {
            failedAttempts += 1
            if failedAttempts >= maxAttempts {
                state = .locked(
                    unlockAt: Date().addingTimeInterval(AppConstants.provisioningLockoutDuration)
                )
            } else {
                state = .codeFailed(attemptsRemaining: maxAttempts - failedAttempts)
            }
        }
    }

    func retryProvisioning() async {
        failedAttempts = 0
        generatedCode = nil
        codeGeneratedAt = nil
        state = .selectIndividual
    }

    // MARK: - Private

    private func sendConfiguration() async {
        state = .sendingConfig

        guard let individual = selectedIndividual else { return }

        // Demo: use hardcoded server URL and watch token
        let configMessage = ProvisioningMessage(
            type: .codeVerified,
            serverURL: DemoConfiguration.serverURL,
            individualId: individual.id,
            authToken: DemoConfiguration.watchAuthToken,
            individualName: individual.name
        )

        watchManager.send(configMessage)
        // ACK from watch will set state = .success via callback
    }
}
