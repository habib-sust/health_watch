import Foundation

enum ProvisioningMessageType: String, Codable {
    case ack             // Watch -> iOS: acknowledgement
    case deprovision     // iOS -> Watch: remove provisioning
    case assistance      // Watch -> iOS: Assistance alert

    // Backward compatibility with older "sos" messages
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "sos", "assistance": self = .assistance
        default: self = ProvisioningMessageType(rawValue: rawValue) ?? .ack
        }
    }
}

struct ProvisioningMessage: Codable {
    let type: ProvisioningMessageType
    let timestamp: Date

    init(type: ProvisioningMessageType, timestamp: Date = Date()) {
        self.type = type
        self.timestamp = timestamp
    }
}
