import Foundation
import WatchConnectivity

final class WatchConnectivityHandler: NSObject {
    static let shared = WatchConnectivityHandler()

    private var session: WCSession?
    var onProvisioningInitiated: ((ProvisioningMessage) -> Void)?
    var onConfigReceived: ((ProvisioningMessage) -> Void)?
    var onCodeFailed: (() -> Void)?

    func activate() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func sendCodeToiOS(_ code: String) {
        let message = ProvisioningMessage(type: .codeEntry, code: code)
        guard let data = try? JSONEncoder().encode(message),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        session?.sendMessage(dict, replyHandler: nil, errorHandler: nil)
    }

    func sendAck() {
        let message = ProvisioningMessage(type: .ack)
        guard let data = try? JSONEncoder().encode(message),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        session?.sendMessage(dict, replyHandler: nil, errorHandler: nil)
    }
}

extension WatchConnectivityHandler: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let msg = try? JSONDecoder().decode(ProvisioningMessage.self, from: data)
        else { return }

        switch msg.type {
        case .initiate:
            DispatchQueue.main.async { self.onProvisioningInitiated?(msg) }

        case .codeVerified:
            // Store config in Keychain, then send ACK back to iOS
            if let url = msg.serverURL,
               let id = msg.individualId,
               let token = msg.authToken {
                do {
                    let keychain = KeychainManager()
                    try keychain.saveServerURL(url)
                    try keychain.saveIndividualId(id)
                    try keychain.saveAuthToken(token)
                    sendAck()
                    DispatchQueue.main.async { self.onConfigReceived?(msg) }
                } catch {
                    print("Keychain save failed: \(error.localizedDescription)")
                }
            }

        case .codeFailed:
            DispatchQueue.main.async { self.onCodeFailed?() }

        default:
            break
        }
    }
}
