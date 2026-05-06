import Foundation

// MARK: - Payload (anonymized) gestuurd naar Claude

public struct AnonymizedActiviteit: Codable, Sendable, Hashable {
    public let week: Int
    public let rol: String          // anon identifier, bv. "intern_dev_1"
    public let uren: Double
    public let categorie: String    // bv. "meeting", "development", "review"

    public init(week: Int, rol: String, uren: Double, categorie: String) {
        self.week = week
        self.rol = rol
        self.uren = uren
        self.categorie = categorie
    }
}

public struct AnonymizedReconstructionPayload: Codable, Sendable {
    public struct Context: Codable, Sendable {
        public let duurWeken: Int
        public let fases: [String]
        public let rolTypen: [String]

        public init(duurWeken: Int, fases: [String], rolTypen: [String]) {
            self.duurWeken = duurWeken
            self.fases = fases
            self.rolTypen = rolTypen
        }
    }

    public struct DoelTotalen: Codable, Sendable {
        public let klant: Double?
        public let intern: Double?

        public init(klant: Double?, intern: Double?) {
            self.klant = klant
            self.intern = intern
        }
    }

    public let projectContext: Context
    public let bekendeActiviteiten: [AnonymizedActiviteit]
    public let doelTotalen: DoelTotalen
    public let vraag: String

    public init(
        projectContext: Context,
        bekendeActiviteiten: [AnonymizedActiviteit],
        doelTotalen: DoelTotalen,
        vraag: String
    ) {
        self.projectContext = projectContext
        self.bekendeActiviteiten = bekendeActiviteiten
        self.doelTotalen = doelTotalen
        self.vraag = vraag
    }

    public var activityCount: Int { bekendeActiviteiten.count }
    public var personCount: Int { Set(bekendeActiviteiten.map(\.rol)).count }

    public func toJSONString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        guard let data = try? encoder.encode(self),
              let s = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return s
    }
}

// MARK: - Suggestie (anonymized) terug van Claude

public struct ActivitySuggestion: Codable, Sendable, Hashable {
    public let anonPersoon: String
    public let week: Int
    public let uren: Double
    public let categorie: String
    public let onderbouwing: String

    public init(anonPersoon: String, week: Int, uren: Double, categorie: String, onderbouwing: String) {
        self.anonPersoon = anonPersoon
        self.week = week
        self.uren = uren
        self.categorie = categorie
        self.onderbouwing = onderbouwing
    }

    private enum CodingKeys: String, CodingKey {
        case anonPersoon = "anon_persoon"
        case week
        case uren
        case categorie
        case onderbouwing
    }
}

// MARK: - Service contract

/// Provider-onafhankelijk contract voor AI-suggesties. Zowel `ClaudeService`
/// als `OpenAIService` voldoen hieraan.
public protocol AISuggestionService: Sendable {
    func suggestActivities(
        payload: AnonymizedReconstructionPayload
    ) async throws -> [ActivitySuggestion]
}

/// Backward-compat alias voor bestaande call-sites.
public typealias ClaudeServiceProtocol = AISuggestionService

// MARK: - Implementation

public struct ClaudeService: AISuggestionService {
    public enum ClaudeError: Error, LocalizedError {
        case missingAPIKey
        case httpError(Int, Data)
        case invalidResponse
        case decodeFailed(String)

        public var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "Geen API sleutel ingesteld."
            case .httpError(let code, _): return "Claude API gaf status \(code)."
            case .invalidResponse: return "Onverwacht antwoord van Claude API."
            case .decodeFailed(let msg): return "JSON parsing mislukt: \(msg)"
            }
        }
    }

    public let apiKey: String
    public let model: String
    public let session: URLSession
    public let endpoint: URL

    public init(
        apiKey: String,
        model: String = "claude-opus-4-7",
        session: URLSession = .shared,
        endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!
    ) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        self.endpoint = endpoint
    }

    public func suggestActivities(
        payload: AnonymizedReconstructionPayload
    ) async throws -> [ActivitySuggestion] {
        guard !apiKey.isEmpty else { throw ClaudeError.missingAPIKey }

        let prompt = Self.buildPrompt(payload: payload)

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

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ClaudeError.httpError(http.statusCode, data)
        }

        return try Self.parseSuggestions(from: data)
    }

    static func buildPrompt(payload: AnonymizedReconstructionPayload) -> String {
        """
        Je helpt bij het reconstrueren van een urenregistratie voor een consultancy project.
        Project context (geanonimiseerd):
        \(payload.toJSONString())

        Stel realistische activiteiten voor om de gaten te vullen, rekening houdend met de doel-totalen.
        Antwoord met UITSLUITEND een JSON array van voorstellen, geen markdown, geen toelichting:
        [{"anon_persoon":"intern_dev_1","week":5,"uren":8,"categorie":"development","onderbouwing":"..."}]
        """
    }

    static func parseSuggestions(from data: Data) throws -> [ActivitySuggestion] {
        // Anthropic responses: { "content": [{ "type": "text", "text": "..." }] }
        struct AnthropicEnvelope: Decodable {
            struct Content: Decodable { let type: String; let text: String? }
            let content: [Content]
        }
        let envelope: AnthropicEnvelope
        do {
            envelope = try JSONDecoder().decode(AnthropicEnvelope.self, from: data)
        } catch {
            throw ClaudeError.decodeFailed("envelope: \(error.localizedDescription)")
        }
        let raw = envelope.content
            .compactMap { $0.text }
            .joined()
        return try parseSuggestionArray(raw)
    }

    /// Probeert het eerste JSON-array fragment uit de tekst te plukken en
    /// te decoderen. Tolerant voor markdown-fences die het model toch laat
    /// staan.
    static func parseSuggestionArray(_ text: String) throws -> [ActivitySuggestion] {
        guard let openIdx = text.firstIndex(of: "["),
              let closeIdx = text.lastIndex(of: "]"),
              openIdx < closeIdx else {
            throw ClaudeError.decodeFailed("geen JSON array gevonden")
        }
        let json = String(text[openIdx...closeIdx])
        guard let data = json.data(using: .utf8) else {
            throw ClaudeError.decodeFailed("kon array niet als bytes lezen")
        }
        do {
            return try JSONDecoder().decode([ActivitySuggestion].self, from: data)
        } catch {
            throw ClaudeError.decodeFailed("array decode: \(error.localizedDescription)")
        }
    }
}
