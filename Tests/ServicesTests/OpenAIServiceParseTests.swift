import XCTest
@testable import Services

final class OpenAIServiceParseTests: XCTestCase {
    func testParseSuggestionsFromOpenAIEnvelope() throws {
        let envelopeJSON = """
        {
          "id": "chatcmpl-1",
          "object": "chat.completion",
          "choices": [
            {
              "index": 0,
              "message": {
                "role": "assistant",
                "content": "[{\\"anon_persoon\\":\\"intern_dev_1\\",\\"week\\":4,\\"uren\\":6,\\"categorie\\":\\"meeting\\",\\"onderbouwing\\":\\"Standup\\"}]"
              }
            }
          ]
        }
        """
        let data = envelopeJSON.data(using: .utf8)!
        let suggestions = try OpenAIService.parseSuggestions(from: data)
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[0].anonPersoon, "intern_dev_1")
        XCTAssertEqual(suggestions[0].uren, 6)
        XCTAssertEqual(suggestions[0].categorie, "meeting")
    }

    func testParseSuggestionsHandlesMarkdownFencesInContent() throws {
        let envelopeJSON = """
        {
          "choices": [
            {
              "message": {
                "content": "Here you go:\\n```json\\n[{\\"anon_persoon\\":\\"klant_pm_1\\",\\"week\\":2,\\"uren\\":4,\\"categorie\\":\\"meeting\\",\\"onderbouwing\\":\\"Kickoff\\"}]\\n```"
              }
            }
          ]
        }
        """
        let data = envelopeJSON.data(using: .utf8)!
        let suggestions = try OpenAIService.parseSuggestions(from: data)
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[0].anonPersoon, "klant_pm_1")
    }

    func testParseSuggestionsThrowsOnMalformedEnvelope() {
        let bad = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try OpenAIService.parseSuggestions(from: bad))
    }
}

final class AISettingsTests: XCTestCase {
    private let providerKey = "ai.provider"
    private let openaiModelKey = "ai.openai.model"
    private let claudeModelKey = "ai.claude.model"

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: providerKey)
        UserDefaults.standard.removeObject(forKey: openaiModelKey)
        UserDefaults.standard.removeObject(forKey: claudeModelKey)
    }

    func testDefaultProviderIsClaude() {
        UserDefaults.standard.removeObject(forKey: providerKey)
        XCTAssertEqual(AISettings.loadProvider(), .claude)
    }

    func testSaveAndLoadProvider() {
        AISettings.saveProvider(.openai)
        XCTAssertEqual(AISettings.loadProvider(), .openai)
    }

    func testDefaultModelsWhenUnset() {
        XCTAssertEqual(AISettings.loadModel(for: .claude), AISettings.defaultClaudeModel)
        XCTAssertEqual(AISettings.loadModel(for: .openai), AISettings.defaultOpenAIModel)
    }

    func testSaveAndLoadModelOverride() {
        AISettings.saveModel("gpt-5", for: .openai)
        XCTAssertEqual(AISettings.loadModel(for: .openai), "gpt-5")
    }

    func testEmptyModelOverrideRevertsToDefault() {
        AISettings.saveModel("custom", for: .openai)
        AISettings.saveModel("  ", for: .openai)
        XCTAssertEqual(AISettings.loadModel(for: .openai), AISettings.defaultOpenAIModel)
    }
}
