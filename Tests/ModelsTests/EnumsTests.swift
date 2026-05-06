import XCTest
@testable import Models

final class EnumsTests: XCTestCase {
    func testPersoonTypeRawValuesMatchSpec() {
        XCTAssertEqual(PersoonType.intern.rawValue, "intern")
        XCTAssertEqual(PersoonType.klant.rawValue, "klant")
        XCTAssertEqual(PersoonType.leverancierWebbouwer.rawValue, "leverancier_webbouwer")
        XCTAssertEqual(PersoonType.leverancierEditor.rawValue, "leverancier_editor")
    }

    func testActiviteitBronRawValuesMatchSpec() {
        XCTAssertEqual(ActiviteitBron.agenda.rawValue, "agenda")
        XCTAssertEqual(ActiviteitBron.importCsv.rawValue, "import_csv")
        XCTAssertEqual(ActiviteitBron.importXlsx.rawValue, "import_xlsx")
        XCTAssertEqual(ActiviteitBron.handmatig.rawValue, "handmatig")
        XCTAssertEqual(ActiviteitBron.aiVoorstel.rawValue, "ai_voorstel")
    }

    func testImportBronTypeRawValuesMatchSpec() {
        XCTAssertEqual(ImportBronType.ics.rawValue, "ics")
        XCTAssertEqual(ImportBronType.csv.rawValue, "csv")
        XCTAssertEqual(ImportBronType.xlsx.rawValue, "xlsx")
        XCTAssertEqual(ImportBronType.calendarSync.rawValue, "calendar_sync")
    }

    func testPersoonTypeMapsToGroep() {
        XCTAssertEqual(PersoonType.intern.groep, .intern)
        XCTAssertEqual(PersoonType.klant.groep, .klant)
        XCTAssertEqual(PersoonType.leverancierWebbouwer.groep, .leverancier)
        XCTAssertEqual(PersoonType.leverancierEditor.groep, .leverancier)
    }
}
