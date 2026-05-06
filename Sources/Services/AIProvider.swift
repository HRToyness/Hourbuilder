import Foundation

public enum AIProvider: String, Codable, CaseIterable, Sendable, Identifiable {
    case claude
    case openai

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .openai: return "OpenAI"
        }
    }

    public var shortLabel: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "OpenAI"
        }
    }
}

/// Centraal punt voor AI-instellingen die buiten de Keychain horen
/// (provider-keuze, model-override). Gebruikt UserDefaults — geen klantdata.
public enum AISettings {
    private static let providerKey = "ai.provider"
    private static let openaiModelKey = "ai.openai.model"
    private static let claudeModelKey = "ai.claude.model"

    public static let defaultClaudeModel = "claude-opus-4-7"
    public static let defaultOpenAIModel = "gpt-4o"

    // MARK: - Provider

    public static func loadProvider() -> AIProvider {
        guard let raw = UserDefaults.standard.string(forKey: providerKey),
              let provider = AIProvider(rawValue: raw) else {
            return .claude
        }
        return provider
    }

    public static func saveProvider(_ provider: AIProvider) {
        UserDefaults.standard.set(provider.rawValue, forKey: providerKey)
    }

    // MARK: - Model overrides

    public static func loadModel(for provider: AIProvider) -> String {
        switch provider {
        case .claude:
            let value = UserDefaults.standard.string(forKey: claudeModelKey) ?? ""
            return value.isEmpty ? defaultClaudeModel : value
        case .openai:
            let value = UserDefaults.standard.string(forKey: openaiModelKey) ?? ""
            return value.isEmpty ? defaultOpenAIModel : value
        }
    }

    public static func saveModel(_ model: String, for provider: AIProvider) {
        let key = (provider == .claude) ? claudeModelKey : openaiModelKey
        let trimmed = model.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(trimmed, forKey: key)
        }
    }
}
