import Foundation

public struct OpenAIService: AISuggestionService {
    public enum OpenAIError: Error, LocalizedError {
        case missingAPIKey
        case httpError(Int, Data)
        case invalidResponse
        case decodeFailed(String)

        public var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "Geen API sleutel ingesteld."
            case .httpError(let code, _): return "OpenAI API gaf status \(code)."
            case .invalidResponse: return "Onverwacht antwoord van OpenAI API."
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
        model: String = AISettings.defaultOpenAIModel,
        session: URLSession = .shared,
        endpoint: URL = URL(string: "https://api.openai.com/v1/chat/completions")!
    ) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        self.endpoint = endpoint
    }

    public func suggestActivities(
        payload: AnonymizedReconstructionPayload
    ) async throws -> [ActivitySuggestion] {
        guard !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }

        let prompt = ClaudeService.buildPrompt(payload: payload)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw OpenAIError.httpError(http.statusCode, data)
        }

        return try Self.parseSuggestions(from: data)
    }

    static func parseSuggestions(from data: Data) throws -> [ActivitySuggestion] {
        struct Envelope: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw OpenAIError.decodeFailed("envelope: \(error.localizedDescription)")
        }
        let raw = envelope.choices.first?.message.content ?? ""
        // Hergebruik dezelfde array-extractie als Claude — beide geven array
        // terug, eventueel met markdown-fences.
        return try ClaudeService.parseSuggestionArray(raw)
    }
}
