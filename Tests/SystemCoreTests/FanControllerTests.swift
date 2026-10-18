import XCTest
@testable import SystemCore
private final class FakeFans: FanHardware {
    var restores = 0
    var writes: [(Int, Double)] = []
    var partialRestores: [Int] = []
    var fanCount = 1
    var cpu: Double?
    var gpu: Double?
    var failWrite = false
    var failRestore = false
    func snapshot() -> ThermalReading {
        ThermalReading(fans: (0..<fanCount).map { FanReading(id: $0, current: 3000, minimum: 1200, maximum: 6000, target: nil, manual: false) }, temperature: cpu, temperatures: [TemperatureReading(id: "gpu", title: "GPU", celsius: gpu, sensorCount: 1, detail: "")], error: nil)
    }
    func setManual(id: Int, rpm: Double) throws {
        writes.append((id, rpm))
        if failWrite { throw HardwareError.unavailable }
    }
    func restoreAutomatic(id: Int) throws { partialRestores.append(id) }
    func restoreAutomatic() throws {
        restores += 1
        if failRestore { throw HardwareError.unavailable }
    }
}
final class FanControllerTests: XCTestCase {
    func testHardwareMinimumIsAvailableBelowCurrentRPM() throws {
        let hardware = FakeFans()
        let controller = FanController(hardware: hardware, thermal: { 0 })
        try controller.manual(fraction: 0, owner: "a")
        XCTAssertEqual(hardware.writes.last?.1, 1200)
        try controller.manualRPM(rpm: 1200, owner: "a")
        XCTAssertEqual(hardware.writes.last?.1, 1200)
    }
    func testHotCPURejectsManualWhileSystemStateIsNominal() {
        let hardware = FakeFans(); hardware.cpu = 95
        let controller = FanController(hardware: hardware, thermal: { 0 })
        XCTAssertThrowsError(try controller.manual(fraction: 0, owner: "a"))
        XCTAssertTrue(hardware.writes.isEmpty)
    }
    func testHotGPURestoresManualFromWatchdogAndRenewal() throws {
        for renew in [false, true] {
            let hardware = FakeFans(); hardware.gpu = 94
            let controller = FanController(hardware: hardware, thermal: { 0 })
            try controller.manual(fraction: 0.5, owner: "a")
            hardware.gpu = 95
            if renew { XCTAssertThrowsError(try controller.renew(owner: "a")) }
            else { try controller.tick() }
            XCTAssertFalse(controller.active)
            XCTAssertEqual(hardware.restores, 1)
        }
    }
    func testExpiredLeaseActuallyRestoresHardware() throws {
        let hardware = FakeFans(); var time = 0.0
        let controller = FanController(hardware: hardware, clock: { time }, thermal: { 0 })
        try controller.manual(fraction: 0.5, owner: "a")
        XCTAssertEqual(hardware.writes.first?.1, 3600)
        time = 11; try controller.tick(); XCTAssertEqual(hardware.restores, 0)
        time = 12; try controller.tick(); XCTAssertEqual(hardware.restores, 1)
        XCTAssertFalse(controller.active)
    }
    func testOnlyOwnerCanRenewAndDisconnectRestores() throws {
        let hardware = FakeFans()
        let controller = FanController(hardware: hardware, thermal: { 0 })
        try controller.manual(fraction: 0, owner: "a")
        XCTAssertThrowsError(try controller.renew(owner: "b"))
        XCTAssertThrowsError(try controller.manual(fraction: 1, owner: "b"))
        try controller.release(owner: "b"); XCTAssertTrue(controller.active)
        try controller.release(owner: "a"); XCTAssertEqual(hardware.restores, 1)
    }
    func testFailedWriteRestoresAndFailedRestoreIsRetried() throws {
        let hardware = FakeFans(); hardware.failWrite = true; hardware.failRestore = true
        let controller = FanController(hardware: hardware, thermal: { 0 })
        XCTAssertThrowsError(try controller.manual(fraction: 0.5, owner: "a"))
        XCTAssertTrue(controller.active)
        hardware.failRestore = false
        try controller.tick(); XCTAssertFalse(controller.active)
        XCTAssertEqual(hardware.restores, 2)
    }
    func testThermalEmergencyAndCrashRecovery() throws {
        let hardware = FakeFans(); var state = 0
        let controller = FanController(hardware: hardware, thermal: { state })
        try controller.manual(fraction: 0.5, owner: "a")
        state = 2; try controller.tick(); XCTAssertFalse(controller.active)
        let recovery = FanController(hardware: hardware, recoveryNeeded: true, thermal: { 0 })
        try recovery.tick(); XCTAssertEqual(hardware.restores, 2)
    }
    func testJournalFailurePreventsAnyHardwareWrite() {
        let hardware = FakeFans()
        let controller = FanController(hardware: hardware, thermal: { 0 }, markActive: { throw HardwareError.unavailable })
        XCTAssertThrowsError(try controller.manual(fraction: 0.5, owner: "a"))
        XCTAssertTrue(hardware.writes.isEmpty)
    }
    func testIndependentFansAndPartialAutomaticKeepOtherFanOwned() throws {
        let hardware = FakeFans(); hardware.fanCount = 2
        let controller = FanController(hardware: hardware, thermal: { 0 })
        try controller.manual(fraction: 0.4, owner: "a", fanID: 0)
        XCTAssertEqual(hardware.writes.map(\.0), [0])
        try controller.manual(fraction: 0.7, owner: "a", fanID: 1)
        XCTAssertEqual(hardware.writes.map(\.0), [0, 1])
        try controller.automatic(fanID: 0, owner: "a")
        XCTAssertEqual(hardware.partialRestores, [0]); XCTAssertTrue(controller.active)
        XCTAssertEqual(hardware.restores, 0)
        try controller.automatic(fanID: 1, owner: "a")
        XCTAssertFalse(controller.active); XCTAssertEqual(hardware.restores, 1)
    }
    func testSyncWritesBothFansAndUnknownFanIsRejected() throws {
        let hardware = FakeFans(); hardware.fanCount = 2
        let controller = FanController(hardware: hardware, thermal: { 0 })
        XCTAssertThrowsError(try controller.manual(fraction: 0.5, owner: "a", fanID: 9))
        XCTAssertTrue(hardware.writes.isEmpty)
        try controller.manual(fraction: 0.5, owner: "a")
        XCTAssertEqual(hardware.writes.map(\.0), [0, 1])
    }

    func testExactRPMIsPreservedThroughControllerAndValidatedBeforeWrites() throws {
        let hardware = FakeFans(); hardware.fanCount = 2
        let controller = FanController(hardware: hardware, thermal: { 0 })
        XCTAssertThrowsError(try controller.manualRPM(rpm: 1199, owner: "a"))
        XCTAssertTrue(hardware.writes.isEmpty)
        try controller.manualRPM(rpm: 4567, owner: "a", fanID: 1)
        XCTAssertEqual(hardware.writes.first?.0, 1)
        XCTAssertEqual(hardware.writes.first?.1, 4567)
        try controller.release(owner: "a")
        XCTAssertEqual(hardware.restores, 1)
    }

}
