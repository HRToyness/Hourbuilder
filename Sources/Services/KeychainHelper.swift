import Foundation
import Security

public enum KeychainHelper {
    public enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)
        case notFound
        case invalidData

        public var errorDescription: String? {
            switch self {
            case .saveFailed(let status): return "Keychain opslag mislukt (status: \(status))"
            case .notFound: return "API sleutel niet gevonden in Keychain"
            case .invalidData: return "Keychain data niet leesbaar als string"
            }
        }
    }

    /// Keychain service-identifier — volgt de bundle-ID zodat keys per
    /// deployment uniek zijn. Fallback dekt tests/CLI waar Bundle.main.bundleIdentifier
    /// niet beschikbaar is.
    public static let service = Bundle.main.bundleIdentifier ?? "nl.toynessit.urenreconstructie"

    public static func account(for provider: AIProvider) -> String {
        switch provider {
        case .claude: return "anthropic_api_key"
        case .openai: return "openai_api_key"
        }
    }

    // MARK: - Provider-aware API

    public static func saveAPIKey(_ key: String, for provider: AIProvider) throws {
        try save(account: account(for: provider), value: key)
    }

    public static func loadAPIKey(for provider: AIProvider) throws -> String {
        try load(account: account(for: provider))
    }

    public static func deleteAPIKey(for provider: AIProvider) throws {
        try delete(account: account(for: provider))
    }

    public static func hasAPIKey(for provider: AIProvider) -> Bool {
        (try? load(account: account(for: provider))) != nil
    }

    // MARK: - Backward-compat (defaults op Claude/Anthropic)

    public static let apiKeyAccount = "anthropic_api_key"

    public static func saveAPIKey(_ key: String) throws {
        try saveAPIKey(key, for: .claude)
    }

    public static func loadAPIKey() throws -> String {
        try loadAPIKey(for: .claude)
    }

    public static func deleteAPIKey() throws {
        try deleteAPIKey(for: .claude)
    }

    public static func hasAPIKey() -> Bool {
        hasAPIKey(for: .claude)
    }

    // MARK: - Lower level helpers

    private static func save(account: String, value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary) // upsert
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func load(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw KeychainError.notFound
        }
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return value
    }

    private static func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.saveFailed(status)
        }
    }
}
