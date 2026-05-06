import XCTest
@testable import Models

final class RecordsCodableTests: XCTestCase {
    func testProjectRoundTrip() throws {
        let original = Project(
            naam: "Acme launch",
            klantNaam: "Acme",
            startDatum: Date(timeIntervalSince1970: 1_700_000_000),
            eindDatum: Date(timeIntervalSince1970: 1_710_000_000),
            status: .lopend,
            factuurNummer: "INV-2024-001",
            doelTotaalKlantUren: 180,
            doelTotaalInternUren: 200,
            notities: "Eerste oplevering"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testActiviteitRoundTrip() throws {
        let original = Activiteit(
            projectId: UUID(),
            faseId: UUID(),
            persoonId: UUID(),
            datum: Date(timeIntervalSince1970: 1_700_000_000),
            uren: 4.5,
            beschrijving: "Sprint planning",
            bron: .handmatig,
            bronReferentie: nil,
            status: .bevestigd,
            bewijs: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Activiteit.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
