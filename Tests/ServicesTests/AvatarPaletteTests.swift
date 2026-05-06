import XCTest
@testable import Styling

final class AvatarPaletteTests: XCTestCase {
    func testPairIsDeterministicPerName() {
        let p1 = AvatarPalette.pair(for: "Teun Kralt")
        let p2 = AvatarPalette.pair(for: "Teun Kralt")
        XCTAssertEqual(p1, p2)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(
            AvatarPalette.pair(for: "Marieke"),
            AvatarPalette.pair(for: "marieke")
        )
        XCTAssertEqual(
            AvatarPalette.pair(for: "  Pim  "),
            AvatarPalette.pair(for: "Pim")
        )
    }

    func testInitialsForCommonCases() {
        XCTAssertEqual(AvatarPalette.initials(for: "Teun Kralt"), "TK")
        XCTAssertEqual(AvatarPalette.initials(for: "Marieke"), "M")
        XCTAssertEqual(AvatarPalette.initials(for: "Pim van der Berg"), "PV")
        XCTAssertEqual(AvatarPalette.initials(for: ""), "?")
        XCTAssertEqual(AvatarPalette.initials(for: "  "), "?")
    }

    func testDifferentNamesGetDifferentColors() {
        // Niet hard-gegarandeerd door hashing maar wel met deze inputs.
        let names = ["Teun", "Marieke", "Pim", "Anna", "Bram", "Charlotte"]
        let pairs = Set(names.map { AvatarPalette.pair(for: $0) })
        XCTAssertGreaterThanOrEqual(pairs.count, 3, "Verwacht enige spreiding over palet")
    }
}
