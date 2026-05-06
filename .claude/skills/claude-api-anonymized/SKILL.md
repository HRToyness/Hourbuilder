---
name: claude-api-anonymized
description: How to call the Claude API safely from this app. Read before any code that calls Anthropic, handles API keys, or processes data that might leave the device. Covers the AnonymizationService, Keychain key storage, the URLSession client, request/response shapes, and streaming.
---

# Claude API with Anonymization

This is the **only** outbound network path in the app. Every byte that leaves the device passes through here, and every byte must be anonymized first. Treat this skill as a privacy contract.

## The privacy contract

The Claude API receives:
- ✅ Project structure (number of weeks, fase names, role types)
- ✅ Quantitative data (hours, dates relative to project start)
- ✅ Anonymized identifiers (`intern_dev_1`, `klant_pm`, `leverancier_editor`)

The Claude API never receives:
- ❌ Real person names
- ❌ Real client names or company names
- ❌ Email addresses, phone numbers, addresses
- ❌ Free-text descriptions that may contain identifying info (sanitize first)
- ❌ Calendar event titles verbatim (sanitize first)
- ❌ File paths, machine identifiers

When in doubt, **don't send it**.

## Architecture

Three components, each with a single responsibility:

```
┌─────────────────┐    ┌──────────────────────┐    ┌──────────────────┐
│ ClaudeService   │───▶│ AnonymizationService │───▶│ KeychainHelper   │
│ (HTTP client)   │    │ (de/re-identify map) │    │ (API key vault)  │
└─────────────────┘    └──────────────────────┘    └──────────────────┘
```

## KeychainHelper

```swift
// Services/KeychainHelper.swift
import Security
import Foundation

enum KeychainHelper {
    private static let service = "nl.toynessit.urenreconstructie"
    private static let account = "anthropic_api_key"

    static func saveAPIKey(_ key: String) throws {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary) // upsert
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    static func loadAPIKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.notFound
        }
        return key
    }

    enum KeychainError: Error { case saveFailed(OSStatus), notFound }
}
```

Key is asked for on first launch, stored in Keychain, never logged.

## AnonymizationService

Maintains a per-session bidirectional mapping. Real → anonymous before sending; anonymous → real on receive.

```swift
// Services/AnonymizationService.swift
final class AnonymizationService {
    private var realToAnon: [String: String] = [:]
    private var anonToReal: [String: String] = [:]
    private var counters: [String: Int] = [:]

    /// Map a Persoon to a stable anonymous identifier for this session.
    func anonymize(persoon: Persoon) -> String {
        if let existing = realToAnon[persoon.id.uuidString] { return existing }
        let prefix = anonPrefix(for: persoon.type)
        counters[prefix, default: 0] += 1
        let anon = "\(prefix)_\(counters[prefix]!)"
        realToAnon[persoon.id.uuidString] = anon
        anonToReal[anon] = persoon.id.uuidString
        return anon
    }

    /// Resolve an anonymous identifier from an API response back to a real Persoon ID.
    func resolve(anon: String) -> UUID? {
        guard let idString = anonToReal[anon] else { return nil }
        return UUID(uuidString: idString)
    }

    /// Reset between sessions / projects.
    func reset() {
        realToAnon.removeAll()
        anonToReal.removeAll()
        counters.removeAll()
    }

    private func anonPrefix(for type: PersoonType) -> String {
        switch type {
        case .intern: return "intern"
        case .klant: return "klant"
        case .leverancierWebbouwer: return "leverancier_web"
        case .leverancierEditor: return "leverancier_editor"
        }
    }

    /// Strip identifying information from free text (event titles, descriptions).
    /// Conservative: removes anything that looks like an email, phone, or capitalized name pair.
    func sanitize(_ text: String) -> String {
        var result = text
        // Strip emails
        result = result.replacingOccurrences(
            of: #"[\w.+-]+@[\w-]+\.[\w.-]+"#,
            with: "[email]",
            options: .regularExpression
        )
        // Strip phone-like sequences
        result = result.replacingOccurrences(
            of: #"\+?\d[\d\s-]{7,}"#,
            with: "[phone]",
            options: .regularExpression
        )
        return result
    }
}
```

The `sanitize` function is a defense in depth, not a guarantee. **Prefer not sending free text at all.** Categorize first (e.g., "meeting", "development", "review") and send the category.

## ClaudeService

```swift
// Services/ClaudeService.swift
import Foundation

struct ClaudeService {
    let apiKey: String
    let model: String = "claude-opus-4-7"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func suggestActivities(payload: AnonymizedReconstructionPayload) async throws -> [ActivitySuggestion] {
        let prompt = buildPrompt(payload)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [["role": "user", "content": prompt]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClaudeError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1, data)
        }

        return try parseSuggestions(from: data)
    }

    private func buildPrompt(_ payload: AnonymizedReconstructionPayload) -> String {
        // Ask for JSON-only response to avoid parsing prose
        """
        You are helping reconstruct an hour registration for a consulting project.
        Project context (anonymized):
        \(payload.toJSONString())

        Suggest realistic activities to fill the gaps. Respond with ONLY a JSON array of suggestions:
        [{"anon_persoon": "intern_dev_1", "week": 5, "uren": 8, "categorie": "development", "onderbouwing": "..."}]
        No prose, no markdown fences, just JSON.
        """
    }

    enum ClaudeError: Error { case httpError(Int, Data), invalidResponse }
}
```

## Configuration safety

- `URLSession.shared` is fine for outbound calls — system-default TLS pinning to public CA.
- If you ever add domain pinning, do it via `URLSessionDelegate.urlSession(_:didReceive:completionHandler:)` checking the cert chain — but for `api.anthropic.com` over public CAs this is overkill.
- Never disable certificate validation. Not even for development.

## Rate limiting and errors

- 429 responses: back off and retry once with delay; surface to user on second failure.
- 401: invalid API key — clear from Keychain, prompt re-entry.
- Network unavailable: app should still work for everything except AI suggestions. AI is additive, never blocking.

## Testing

For tests, inject a `ClaudeServiceProtocol` and provide a stub that returns canned suggestions. Never hit the real API in tests.

```swift
protocol ClaudeServiceProtocol {
    func suggestActivities(payload: AnonymizedReconstructionPayload) async throws -> [ActivitySuggestion]
}
```

## Logging

Log the **request shape** (counts, structure) but never the **payload contents**. Example:
```swift
logger.info("Claude API call: \(payload.activityCount) activities, \(payload.personCount) persons")
```
Not:
```swift
logger.info("Claude API payload: \(payload)")  // ❌ might contain anonymized but still sensitive structure
```
