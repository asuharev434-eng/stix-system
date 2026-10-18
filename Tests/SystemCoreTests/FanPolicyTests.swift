import XCTest
@testable import SystemCore
final class FanPolicyTests: XCTestCase {
    let fan = FanReading(id: 0, current: 2300, minimum: 1200, maximum: 6000, target: nil, manual: false)
    func testTargetsUseZeroThroughMaximum() throws {
        XCTAssertEqual(try FanPolicy.target(fan: fan, fraction: 0, thermalState: 0), 0)
        XCTAssertEqual(try FanPolicy.target(fan: fan, fraction: 1, thermalState: 0), 6000)
        XCTAssertEqual(try FanPolicy.target(fan: fan, fraction: 0.1, thermalState: 0), 600)
    }
    func testInvalidAndHotRequestsRejected() {
        for fraction in [Double.nan, .infinity, -0.1, 1.1] {
            XCTAssertThrowsError(try FanPolicy.target(fan: fan, fraction: fraction, thermalState: 0))
        }
        XCTAssertThrowsError(try FanPolicy.target(fan: fan, fraction: 0.5, thermalState: 2))
    }
    func testLeaseExpiresAtDeadline() {
        XCTAssertFalse(FanPolicy.expired(deadline: nil, now: 100))
        XCTAssertFalse(FanPolicy.expired(deadline: 112, now: 111.9))
        XCTAssertTrue(FanPolicy.expired(deadline: 112, now: 112))
        XCTAssertTrue(FanPolicy.expired(deadline: 112, now: 113))
    }
}
