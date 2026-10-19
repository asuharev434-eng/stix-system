import XCTest
@testable import SystemCore

final class FanModeTransitionTests: XCTestCase {
    func testTransientFirmwareRejectionsAreRetriedUntilReadBackConfirms() throws {
        var writes = 0
        try FanModeTransition.perform(attempts: 10, write: {
            writes += 1
            if writes < 4 { throw HardwareError.unavailable }
        }, confirmed: { writes == 4 }, wait: {})
        XCTAssertEqual(writes, 4)
    }
    func testPermanentRejectionIsBoundedAndSuccessfulWritesStillNeedReadBack() {
        var writes = 0
        XCTAssertThrowsError(try FanModeTransition.perform(attempts: 3, write: {
            writes += 1; throw HardwareError.unavailable
        }, confirmed: { false }, wait: {}))
        XCTAssertEqual(writes, 3)
        XCTAssertThrowsError(try FanModeTransition.perform(attempts: 3, write: {}, confirmed: { false }, wait: {}))
    }
}
