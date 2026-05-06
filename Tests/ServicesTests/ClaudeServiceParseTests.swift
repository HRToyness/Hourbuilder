import XCTest
@testable import Services

final class ClaudeServiceParseTests: XCTestCase {
    func testParseSuggestionsFromAnthropicEnvelope() throws {
        let envelopeJSON = """
        {
          "content": [
            {"type":"text","text":"[{\\"anon_persoon\\":\\"intern_dev_1\\",\\"week\\":3,\\"uren\\":8,\\"categorie\\":\\"development\\",\\"onderbouwing\\":\\"Sprint X\\"}]"}
          ]
        }
        """
        let data = envelopeJSON.data(using: .utf8)!
        let suggestions = try ClaudeService.parseSuggestions(from: data)
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[0].anonPersoon, "intern_dev_1")
        XCTAssertEqual(suggestions[0].uren, 8)
        XCTAssertEqual(suggestions[0].categorie, "development")
    }

    func testParseSuggestionArrayHandlesMarkdownFences() throws {
        let raw = """
        Here are the suggestions:
        ```json
        [
          {"anon_persoon":"klant_pm_1","week":2,"uren":4,"categorie":"meeting","onderbouwing":"Kickoff"}
        ]
        ```
        """
        let suggestions = try ClaudeService.parseSuggestionArray(raw)
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[0].anonPersoon, "klant_pm_1")
    }

    func testBuildPromptIncludesPayload() {
        let payload = AnonymizedReconstructionPayload(
            projectContext: .init(duurWeken: 12, fases: ["analyse"], rolTypen: ["intern_dev_1"]),
            bekendeActiviteiten: [.init(week: 1, rol: "intern_dev_1", uren: 8, categorie: "meeting")],
            doelTotalen: .init(klant: 100, intern: 200),
            vraag: "test"
        )
        let prompt = ClaudeService.buildPrompt(payload: payload)
        XCTAssertTrue(prompt.contains("intern_dev_1"))
        XCTAssertTrue(prompt.contains("JSON"))
    }
}
