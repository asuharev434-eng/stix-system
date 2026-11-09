import XCTest
@testable import SystemCore

final class ExternalVolumeTests: XCTestCase {
    func testUsedPercentageRoundsToNearestWholePercent() {
        XCTAssertEqual(ExternalVolumeMath.usedPercent(total: 100, available: 98), 2)
        XCTAssertEqual(ExternalVolumeMath.usedPercent(total: 3, available: 2), 33)
        XCTAssertEqual(ExternalVolumeMath.usedPercent(total: 100, available: 0), 100)
    }

    func testInvalidCapacityIsIgnored() {
        XCTAssertNil(ExternalVolumeMath.usedPercent(total: 0, available: 0))
        XCTAssertNil(ExternalVolumeMath.usedPercent(total: 100, available: 101))
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
