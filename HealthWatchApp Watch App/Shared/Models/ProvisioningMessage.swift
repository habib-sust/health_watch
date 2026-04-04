import Foundation

enum ProvisioningMessageType: String, Codable {
    case initiate        // iOS -> Watch: start provisioning
    case codeEntry       // Watch -> iOS: user entered code
    case codeVerified    // iOS -> Watch: code accepted, here's config
    case codeFailed      // iOS -> Watch: code rejected
    case ack             // Watch -> iOS: config stored successfully
}

struct ProvisioningMessage: Codable {
    let type: ProvisioningMessageType
    let code: String?
    let serverURL: String?
    let individualId: String?
    let authToken: String?
    let individualName: String?  // For watch display/confirmation
    let timestamp: Date

    init(
        type: ProvisioningMessageType,
        code: String? = nil,
        serverURL: String? = nil,
        individualId: String? = nil,
        authToken: String? = nil,
        individualName: String? = nil,
        timestamp: Date = Date()
    ) {
        self.type = type
        self.code = code
        self.serverURL = serverURL
        self.individualId = individualId
        self.authToken = authToken
        self.individualName = individualName
        self.timestamp = timestamp
    }
}
