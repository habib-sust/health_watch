import Foundation
import Combine
import WatchConnectivity
import UserNotifications

extension Notification.Name {
    static let watchDidDeprovision = Notification.Name("watchDidDeprovision")
    static let provisioningDidChange = Notification.Name("provisioningDidChange")
}

final class WatchConnectivityManager: NSObject, ObservableObject {
    @Published var isReachable = false
    private var session: WCSession?
    var onAckReceived: (() -> Void)?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    var isWatchReachable: Bool {
        session?.isReachable ?? false
    }

    func send(_ message: ProvisioningMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        session?.sendMessage(dict, replyHandler: nil) { error in
            print("WCSession send error: \(error.localizedDescription)")
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let msg = try? JSONDecoder().decode(ProvisioningMessage.self, from: data)
        else { return }

        switch msg.type {
        case .ack:
            DispatchQueue.main.async { self.onAckReceived?() }
        case .assistance:
            scheduleAssistanceNotification()
        case .deprovision:
            DispatchQueue.main.async { self.handleDeprovisionFromWatch() }
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        if !session.isWatchAppInstalled {
            DispatchQueue.main.async { self.handleDeprovisionFromWatch() }
        }
    }

    // Required stubs for iOS
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    private func handleDeprovisionFromWatch() {
        UserDefaults.standard.removeObject(forKey: "provisionedIndividualId")
        UserDefaults.standard.removeObject(forKey: "provisionedIndividualName")
        UserDefaults.standard.removeObject(forKey: "provisionedDeviceCode")
        NotificationCenter.default.post(name: .watchDidDeprovision, object: nil)
    }

    private func scheduleAssistanceNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Assistance Alert"
        content.body = "An individual has requested assistance from their watch. Please respond promptly."
        content.sound = .defaultCritical
        content.interruptionLevel = .critical

        let request = UNNotificationRequest(
            identifier: "assistance-\(UUID().uuidString)",
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }
}
