import XCTest
@testable import SystemCore

final class ExternalVolumeTests: XCTestCase {
    func testUsedPercentageRoundsToNearestWholePercent() {
        XCTAssertEqual(ExternalVolumeMath.metrics(total: 100, available: 98)?.usedPercent, 2)
        XCTAssertEqual(ExternalVolumeMath.metrics(total: 3, available: 2)?.usedPercent, 33)
        XCTAssertEqual(ExternalVolumeMath.metrics(total: 100, available: 0)?.usedPercent, 100)
    }

    func testMetricsUseTheSameValidatedCapacityPair() {
        let metrics = ExternalVolumeMath.metrics(total: 3, available: 2)
        XCTAssertEqual(metrics?.usedFraction, 1.0 / 3.0)
        XCTAssertEqual(metrics?.usedPercent, 33)
    }

    func testInvalidCapacityIsIgnored() {
        XCTAssertNil(ExternalVolumeMath.metrics(total: 0, available: 0))
        XCTAssertNil(ExternalVolumeMath.metrics(total: 100, available: 101))
        XCTAssertNil(ExternalVolumeUsage(id: "disk", name: "Disk", totalBytes: 100, availableBytes: 101))
    }

    func testFixedUSBExternalDiskIsAccepted() {
        // External USB disks need not report as removable; internal=false is the relevant hardware boundary.
        XCTAssertTrue(ExternalVolumeMath.isExternalLocalHardware(isInternal: false, isNetwork: false, protocolName: "USB"))
    }

    func testInternalUnknownNetworkAndVirtualDevicesAreRejected() {
        XCTAssertFalse(ExternalVolumeMath.isExternalLocalHardware(isInternal: true, isNetwork: false, protocolName: "USB"))
        XCTAssertFalse(ExternalVolumeMath.isExternalLocalHardware(isInternal: nil, isNetwork: false, protocolName: "USB"))
        XCTAssertFalse(ExternalVolumeMath.isExternalLocalHardware(isInternal: false, isNetwork: true, protocolName: "USB"))
        XCTAssertFalse(ExternalVolumeMath.isExternalLocalHardware(isInternal: false, isNetwork: nil, protocolName: "USB"))
        XCTAssertFalse(ExternalVolumeMath.isExternalLocalHardware(isInternal: false, isNetwork: false, protocolName: "Disk Image"))
        XCTAssertFalse(ExternalVolumeMath.isExternalLocalHardware(isInternal: false, isNetwork: false, protocolName: nil))
    }
}
