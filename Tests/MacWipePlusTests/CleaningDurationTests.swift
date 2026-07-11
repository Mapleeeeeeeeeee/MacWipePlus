import XCTest
@testable import MacWipePlus

final class CleaningDurationTests: XCTestCase {
    func testAcceptsConfiguredBoundaries() {
        XCTAssertEqual(CleaningDuration(seconds: 10), .seconds(10))
        XCTAssertEqual(CleaningDuration(seconds: 3_600), .seconds(3_600))
    }

    func testRejectsValuesOutsideConfiguredBounds() {
        XCTAssertNil(CleaningDuration(seconds: 9))
        XCTAssertNil(CleaningDuration(seconds: 3_601))
        XCTAssertNil(CleaningDuration(seconds: 0))
        XCTAssertNil(CleaningDuration(seconds: -1))
    }

    func testNilMeansNoAutomaticExit() {
        XCTAssertEqual(CleaningDuration(seconds: nil), .never)
    }
}
