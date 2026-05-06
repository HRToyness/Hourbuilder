import XCTest
@testable import Services
@testable import Models

final class CsvImportMapperTests: XCTestCase {
    private let mapper = CsvImportMapper()

    func testHourFormatColonStyle() {
        XCTAssertEqual(mapper.parseHours("1:30") ?? -1, 1.5, accuracy: 0.001)
        XCTAssertEqual(mapper.parseHours("8:15") ?? -1, 8.25, accuracy: 0.001)
    }

    func testHourFormatCommaDecimal() {
        XCTAssertEqual(mapper.parseHours("2,5") ?? -1, 2.5, accuracy: 0.001)
    }

    func testHourFormatDotDecimal() {
        XCTAssertEqual(mapper.parseHours("3.75") ?? -1, 3.75, accuracy: 0.001)
    }

    func testDateMultipleFormats() {
        XCTAssertNotNil(mapper.parseDate("2026-05-01"))
        XCTAssertNotNil(mapper.parseDate("2026/05/01"))
        XCTAssertNotNil(mapper.parseDate("01-05-2026"))
        XCTAssertNotNil(mapper.parseDate("01/05/2026"))
    }

    func testMapWithCompleteMappingProducesActivities() {
        let file = CsvFile(
            header: ["datum", "uren", "beschrijving"],
            rows: [
                ["2026-05-01", "4", "Sprint planning"],
                ["2026-05-02", "2,5", "Code review"],
            ],
            delimiter: ";",
            bestandsnaam: "leverancier.csv"
        )
        let mapping = CsvColumnMapping(datumColumn: 0, urenColumn: 1, beschrijvingColumn: 2)
        let projectId = UUID()
        let persoonId = UUID()

        let preview = mapper.map(
            file: file,
            mapping: mapping,
            projectId: projectId,
            persoonId: persoonId,
            bron: .importCsv
        )
        XCTAssertEqual(preview.activities.count, 2)
        XCTAssertTrue(preview.errors.isEmpty)
        XCTAssertEqual(preview.activities[0].uren, 4, accuracy: 0.001)
        XCTAssertEqual(preview.activities[1].uren, 2.5, accuracy: 0.001)
        XCTAssertEqual(preview.activities[0].bron, .importCsv)
        XCTAssertEqual(preview.activities[0].status, .concept)
        XCTAssertTrue(preview.activities[0].bronReferentie?.contains("leverancier.csv") ?? false)
    }

    func testMapReportsErrorsForUnparseableRows() {
        let file = CsvFile(
            header: ["datum", "uren"],
            rows: [
                ["NIET-EEN-DATUM", "4"],
                ["2026-05-02", "geen-getal"],
                ["2026-05-03", "5"],
            ],
            delimiter: ",",
            bestandsnaam: "bad.csv"
        )
        let mapping = CsvColumnMapping(datumColumn: 0, urenColumn: 1)
        let preview = mapper.map(
            file: file,
            mapping: mapping,
            projectId: UUID(),
            persoonId: UUID(),
            bron: .importCsv
        )
        XCTAssertEqual(preview.activities.count, 1)
        XCTAssertEqual(preview.errors.count, 2)
    }

    func testMapWithIncompleteMappingReturnsEmpty() {
        let file = CsvFile(
            header: ["datum"],
            rows: [["2026-05-01"]],
            delimiter: ",",
            bestandsnaam: nil
        )
        let mapping = CsvColumnMapping(datumColumn: 0, urenColumn: nil)
        let preview = mapper.map(
            file: file,
            mapping: mapping,
            projectId: UUID(),
            persoonId: UUID(),
            bron: .importCsv
        )
        XCTAssertTrue(preview.activities.isEmpty)
        XCTAssertTrue(preview.errors.isEmpty)
    }
}
