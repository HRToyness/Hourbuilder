import XCTest
@testable import Services
@testable import Models

final class ExportServiceTests: XCTestCase {
    private let service = ExportService()

    private func sampleInput(partij: PersoonGroep? = nil) -> ExportInput {
        let project = Project(
            naam: "Acme launch",
            klantNaam: "Acme",
            startDatum: Date(timeIntervalSince1970: 1_700_000_000),
            eindDatum: Date(timeIntervalSince1970: 1_710_000_000),
            status: .lopend,
            factuurNummer: "INV-2024-001"
        )
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        let bob = Persoon(naam: "Bob", rol: "PM", type: .klant)
        let activiteiten = [
            Activiteit(
                projectId: project.id,
                persoonId: alice.id,
                datum: Date(timeIntervalSince1970: 1_700_000_000),
                uren: 8,
                beschrijving: "Sprint planning",
                bron: .handmatig,
                status: .bevestigd
            ),
            Activiteit(
                projectId: project.id,
                persoonId: bob.id,
                datum: Date(timeIntervalSince1970: 1_700_086_400),
                uren: 4,
                beschrijving: "Review",
                bron: .handmatig,
                status: .bevestigd
            ),
        ]
        return ExportInput(
            project: project,
            activiteiten: activiteiten,
            personen: [alice, bob],
            fases: [],
            partij: partij
        )
    }

    func testGeneratePDFProducesValidPDFData() throws {
        let data = try service.generatePDFData(sampleInput())
        XCTAssertGreaterThan(data.count, 1000, "PDF data lijkt te klein")
        // PDF magic header is "%PDF-"
        let prefix = data.prefix(5)
        XCTAssertEqual(prefix, Data("%PDF-".utf8))
    }

    func testGenerateCSVIncludesHeaderAndTotals() {
        let csv = service.generateCSV(sampleInput())
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.first, "datum;persoon;type;rol;fase;uren;beschrijving;bron")
        XCTAssertTrue(lines.contains(where: { $0.contains("Alice") }))
        XCTAssertTrue(lines.contains(where: { $0.contains("Bob") }))
        XCTAssertTrue(lines.contains(where: { $0.lowercased().contains("totalen per groep") }))
    }

    func testCSVFiltersByPartij() {
        let csvIntern = service.generateCSV(sampleInput(partij: .intern))
        XCTAssertTrue(csvIntern.contains("Alice"))
        XCTAssertFalse(csvIntern.contains(";Bob;"))
    }

    func testCSVEscapesSemicolonsInDescription() {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        let p = Persoon(naam: "X", rol: "Y", type: .intern)
        let act = Activiteit(
            projectId: project.id,
            persoonId: p.id,
            datum: Date(),
            uren: 1,
            beschrijving: "Test; with semicolon",
            bron: .handmatig,
            status: .bevestigd
        )
        let csv = service.generateCSV(ExportInput(
            project: project,
            activiteiten: [act],
            personen: [p],
            fases: [],
            partij: nil
        ))
        XCTAssertTrue(csv.contains("\"Test; with semicolon\""))
    }
}
