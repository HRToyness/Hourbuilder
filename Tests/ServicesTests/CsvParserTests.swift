import XCTest
@testable import Services

final class CsvParserTests: XCTestCase {
    func testDetectDelimiterPrefersSemicolonWhenMore() {
        let text = "datum;uren;beschrijving\n2026-05-01;4;Sprint"
        XCTAssertEqual(CsvParser.detectDelimiter(in: text), ";")
    }

    func testDetectDelimiterDefaultsToComma() {
        let text = "datum,uren\n2026-05-01,4"
        XCTAssertEqual(CsvParser.detectDelimiter(in: text), ",")
    }

    func testDetectDelimiterTab() {
        let text = "datum\turen\n2026-05-01\t4"
        XCTAssertEqual(CsvParser.detectDelimiter(in: text), "\t")
    }

    func testParseHeaderAndRows() {
        let text = """
        datum;uren;beschrijving
        2026-05-01;4;Sprint planning
        2026-05-02;2,5;Code review
        """
        let parsed = CsvParser.parse(text: text, bestandsnaam: "test.csv")
        XCTAssertEqual(parsed.delimiter, ";")
        XCTAssertEqual(parsed.header, ["datum", "uren", "beschrijving"])
        XCTAssertEqual(parsed.rows.count, 2)
        XCTAssertEqual(parsed.rows[0], ["2026-05-01", "4", "Sprint planning"])
        XCTAssertEqual(parsed.rows[1], ["2026-05-02", "2,5", "Code review"])
    }

    func testSplitLineHandlesQuotedFields() {
        let line = "\"Hello, world\";4;\"Sprint, planning\""
        let fields = CsvParser.splitLine(line, delimiter: ";")
        XCTAssertEqual(fields, ["Hello, world", "4", "Sprint, planning"])
    }

    func testSkipsEmptyLines() {
        let text = "a,b\n\n1,2\n\n"
        let parsed = CsvParser.parse(text: text)
        XCTAssertEqual(parsed.rows.count, 1)
    }

    func testHandlesCRLFLineEndings() {
        let text = "datum,uren\r\n2026-05-01,4\r\n"
        let parsed = CsvParser.parse(text: text)
        XCTAssertEqual(parsed.header, ["datum", "uren"])
        XCTAssertEqual(parsed.rows.first, ["2026-05-01", "4"])
    }
}
