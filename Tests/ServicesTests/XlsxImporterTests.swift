import XCTest
import CoreXLSX
@testable import Services

final class XlsxImporterTests: XCTestCase {
    private func col(_ s: String) throws -> ColumnReference {
        try XCTUnwrap(ColumnReference(s))
    }

    func testColumnIndexSingleLetter() throws {
        XCTAssertEqual(XlsxImporter.columnIndex(for: try col("A")), 0)
        XCTAssertEqual(XlsxImporter.columnIndex(for: try col("B")), 1)
        XCTAssertEqual(XlsxImporter.columnIndex(for: try col("Z")), 25)
    }

    func testColumnIndexDoubleLetter() throws {
        XCTAssertEqual(XlsxImporter.columnIndex(for: try col("AA")), 26)
        XCTAssertEqual(XlsxImporter.columnIndex(for: try col("AZ")), 51)
        XCTAssertEqual(XlsxImporter.columnIndex(for: try col("BA")), 52)
    }
}

final class CsvImportMapperExcelDateTests: XCTestCase {
    private let mapper = CsvImportMapper()

    func testParseExcelSerialDateInRange() {
        // 45000 ≈ 2023-03-15
        let date = mapper.parseExcelSerialDate("45000")
        XCTAssertNotNil(date)
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month], from: date ?? Date())
        XCTAssertEqual(comps.year, 2023)
        XCTAssertEqual(comps.month, 3)
    }

    func testParseExcelSerialDateRejectsSmallNumbers() {
        XCTAssertNil(mapper.parseExcelSerialDate("8"))
        XCTAssertNil(mapper.parseExcelSerialDate("8.5"))
        XCTAssertNil(mapper.parseExcelSerialDate("-100"))
    }

    func testParseExcelSerialDateRejectsHugeNumbers() {
        XCTAssertNil(mapper.parseExcelSerialDate("99999999"))
    }

    func testParseDateFallsThroughToExcelSerial() {
        // Test that parseDate uses the Excel-serial fallback
        let date = mapper.parseDate("45000")
        XCTAssertNotNil(date)
    }
}
