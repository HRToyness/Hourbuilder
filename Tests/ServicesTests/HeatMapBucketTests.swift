import XCTest
@testable import Styling

final class HeatMapBucketTests: XCTestCase {
    func testBucketBoundaries() {
        XCTAssertEqual(HeatMapBucket.bucket(for: 0), .empty)
        XCTAssertEqual(HeatMapBucket.bucket(for: 0.5), .low)
        XCTAssertEqual(HeatMapBucket.bucket(for: 4.99), .low)
        XCTAssertEqual(HeatMapBucket.bucket(for: 5), .medium)
        XCTAssertEqual(HeatMapBucket.bucket(for: 12.99), .medium)
        XCTAssertEqual(HeatMapBucket.bucket(for: 13), .high)
        XCTAssertEqual(HeatMapBucket.bucket(for: 24.99), .high)
        XCTAssertEqual(HeatMapBucket.bucket(for: 25), .veryHigh)
        XCTAssertEqual(HeatMapBucket.bucket(for: 100), .veryHigh)
    }

    func testNegativeAndZeroAreEmpty() {
        XCTAssertEqual(HeatMapBucket.bucket(for: -1), .empty)
        XCTAssertEqual(HeatMapBucket.bucket(for: 0), .empty)
    }
}
