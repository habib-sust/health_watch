import Testing
@testable import HealthWatch

struct KeychainManagerTests {
    let keychain = KeychainManager(service: "com.company.healthwatch.test")

    @Test("Save and load data")
    func saveAndLoad() throws {
        let data = "test-value".data(using: .utf8)!
        try keychain.save(data, for: "test-key")
        let loaded = try keychain.load(for: "test-key")
        #expect(loaded == data)
        // Cleanup
        try keychain.delete(for: "test-key")
    }

    @Test("Load returns nil for missing key")
    func loadMissing() throws {
        let result = try keychain.load(for: "nonexistent-key")
        #expect(result == nil)
    }

    @Test("Delete succeeds for existing key")
    func deleteExisting() throws {
        let data = "to-delete".data(using: .utf8)!
        try keychain.save(data, for: "delete-key")
        try keychain.delete(for: "delete-key")
        let result = try keychain.load(for: "delete-key")
        #expect(result == nil)
    }

    @Test("Delete succeeds for missing key (no error)")
    func deleteMissing() throws {
        try keychain.delete(for: "does-not-exist")
    }

    @Test("Save provisioning config and load it back")
    func provisioningConfig() throws {
        try keychain.saveServerURL("https://example.com")
        try keychain.saveIndividualId("ind-001")
        try keychain.saveAuthToken("token-123")

        let config = try keychain.loadProvisioningConfig()
        #expect(config != nil)
        #expect(config?.serverURL == "https://example.com")
        #expect(config?.individualId == "ind-001")
        #expect(config?.authToken == "token-123")

        // Cleanup
        try keychain.clearAll()
    }

    @Test("loadProvisioningConfig returns nil when incomplete")
    func incompleteConfig() throws {
        try keychain.clearAll()
        try keychain.saveServerURL("https://example.com")
        // Missing individualId and authToken
        let config = try keychain.loadProvisioningConfig()
        #expect(config == nil)
        try keychain.clearAll()
    }

    @Test("clearAll removes all keys")
    func clearAll() throws {
        try keychain.saveServerURL("https://example.com")
        try keychain.saveIndividualId("ind-001")
        try keychain.saveAuthToken("token-123")
        try keychain.clearAll()
        let config = try keychain.loadProvisioningConfig()
        #expect(config == nil)
    }
}
