import XCTest
@testable import Services
@testable import Models

final class AnonymizationServiceTests: XCTestCase {
    func testAnonymizeReturnsStableIdentifierAcrossCalls() {
        let service = AnonymizationService()
        let alice = Persoon(naam: "Alice", rol: "Developer", type: .intern)

        let first = service.anonymize(persoon: alice)
        let second = service.anonymize(persoon: alice)
        XCTAssertEqual(first, second)
    }

    func testAnonymizeIncrementsForNewPersonsOfSameType() {
        let service = AnonymizationService()
        let alice = Persoon(naam: "Alice", rol: "dev", type: .intern)
        let bob = Persoon(naam: "Bob", rol: "dev", type: .intern)

        let aliceAnon = service.anonymize(persoon: alice)
        let bobAnon = service.anonymize(persoon: bob)
        XCTAssertNotEqual(aliceAnon, bobAnon)
        XCTAssertTrue(aliceAnon.contains("intern"))
        XCTAssertTrue(bobAnon.contains("intern"))
    }

    func testResolveRoundTrip() {
        let service = AnonymizationService()
        let alice = Persoon(naam: "Alice", rol: "PM", type: .klant)
        let anon = service.anonymize(persoon: alice)
        XCTAssertEqual(service.resolve(anon: anon), alice.id)
    }

    func testResolveUnknownReturnsNil() {
        let service = AnonymizationService()
        XCTAssertNil(service.resolve(anon: "intern_dev_99"))
    }

    func testResetClearsMappings() {
        let service = AnonymizationService()
        let alice = Persoon(naam: "Alice", rol: "PM", type: .klant)
        let firstAnon = service.anonymize(persoon: alice)
        XCTAssertEqual(service.resolve(anon: firstAnon), alice.id)

        service.reset()
        XCTAssertNil(service.resolve(anon: firstAnon))

        // After reset, calling anonymize twice voor dezelfde persoon levert dezelfde nieuwe id.
        let afterAnon = service.anonymize(persoon: alice)
        XCTAssertEqual(afterAnon, service.anonymize(persoon: alice))
    }

    func testSanitizeStripsEmails() {
        let service = AnonymizationService()
        let result = service.sanitize("Stuur naar bob@klant.com voor review")
        XCTAssertFalse(result.contains("bob@klant.com"))
        XCTAssertTrue(result.contains("[email]"))
    }

    func testSanitizeStripsPhoneNumbers() {
        let service = AnonymizationService()
        let result = service.sanitize("Bel 06 12345678 als er issues zijn")
        XCTAssertFalse(result.contains("06 12345678"))
        XCTAssertTrue(result.contains("[phone]"))
    }

    func testLeverancierAnonPrefixesIgnoreRoleField() {
        let service = AnonymizationService()
        let webbouwer = Persoon(naam: "Y", rol: "Top secret klantnaam ABV", type: .leverancierWebbouwer)
        let anon = service.anonymize(persoon: webbouwer)
        XCTAssertTrue(anon.hasPrefix("leverancier_web"))
        XCTAssertFalse(anon.lowercased().contains("klant"))
    }
}
