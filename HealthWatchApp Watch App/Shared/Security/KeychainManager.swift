import Foundation
import Security

struct ProvisioningConfig {
    let serverURL: String
    let individualId: String
    let authToken: String
}

struct KeychainManager {
    private let service: String

    private enum Keys {
        static let serverURL = "healthwatch.serverURL"
        static let individualId = "healthwatch.individualId"
        static let authToken = "healthwatch.authToken"
    }

    init(service: String = AppConstants.keychainService) {
        self.service = service
    }

    // MARK: - Generic Operations

    func save(_ data: Data, for key: String) throws {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    func load(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.loadFailed(status: status)
        }
    }

    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    // MARK: - Provisioning Convenience Methods

    func saveServerURL(_ url: String) throws {
        guard let data = url.data(using: .utf8) else { throw KeychainError.encodingFailed }
        try save(data, for: Keys.serverURL)
    }

    func saveIndividualId(_ id: String) throws {
        guard let data = id.data(using: .utf8) else { throw KeychainError.encodingFailed }
        try save(data, for: Keys.individualId)
    }

    func saveAuthToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else { throw KeychainError.encodingFailed }
        try save(data, for: Keys.authToken)
    }

    func loadProvisioningConfig() throws -> ProvisioningConfig? {
        guard let urlData = try load(for: Keys.serverURL),
              let idData = try load(for: Keys.individualId),
              let tokenData = try load(for: Keys.authToken),
              let url = String(data: urlData, encoding: .utf8),
              let id = String(data: idData, encoding: .utf8),
              let token = String(data: tokenData, encoding: .utf8)
        else {
            return nil
        }
        return ProvisioningConfig(serverURL: url, individualId: id, authToken: token)
    }

    func clearAll() throws {
        try delete(for: Keys.serverURL)
        try delete(for: Keys.individualId)
        try delete(for: Keys.authToken)
    }
}

enum KeychainError: Error, LocalizedError {
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed (status: \(status))."
        case .loadFailed(let status):
            return "Keychain load failed (status: \(status))."
        case .deleteFailed(let status):
            return "Keychain delete failed (status: \(status))."
        case .encodingFailed:
            return "Failed to encode data for Keychain."
        }
    }
}
