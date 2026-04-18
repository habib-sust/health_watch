import Foundation
import WatchConnectivity

final class WatchConnectivityHandler: NSObject {
    static let shared = WatchConnectivityHandler()

    private var session: WCSession?

    func activate() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func sendAck() {
        let message = ProvisioningMessage(type: .ack)
        guard let data = try? JSONEncoder().encode(message),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        session?.sendMessage(dict, replyHandler: nil, errorHandler: nil)
    }

    func sendSOS() {
        let message = ProvisioningMessage(type: .sos)
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
        case .deprovision:
            DispatchQueue.main.async {
                WatchAppState.shared.resetToUnprovisioned()
            }
            sendAck()

        default:
            break
        }
    }
}
