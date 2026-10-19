import XCTest
@testable import SystemCore

final class GPUUsageTests: XCTestCase {
    func testDevicePercentMapsToFractionAndMultipleDevicesUseBusiest() {
        XCTAssertEqual(GPUUsage.fraction(percentages: [79]), 0.79)
        XCTAssertEqual(GPUUsage.fraction(percentages: [0]), 0)
        XCTAssertEqual(GPUUsage.fraction(percentages: [25, 100]), 1)
    }
    func testUnavailableAndInvalidTelemetryIsNotReportedAsIdle() {
        XCTAssertNil(GPUUsage.fraction(percentages: []))
        XCTAssertNil(GPUUsage.fraction(percentages: [.nan, .infinity, -1, 101]))
        XCTAssertEqual(GPUUsage.fraction(percentages: [.nan, 42]), 0.42)
    }
}
