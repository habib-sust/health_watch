import Foundation

enum ProvisioningMessageType: String, Codable {
    case ack             // Watch -> iOS: acknowledgement
    case deprovision     // iOS -> Watch: remove provisioning
    case sos             // Watch -> iOS: SOS alert
}

struct ProvisioningMessage: Codable {
    let type: ProvisioningMessageType
    let timestamp: Date

    init(type: ProvisioningMessageType, timestamp: Date = Date()) {
        self.type = type
        self.timestamp = timestamp
    }
}
