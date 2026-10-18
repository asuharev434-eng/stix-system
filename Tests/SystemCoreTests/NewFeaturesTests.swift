import XCTest
@testable import SystemCore
final class NewFeaturesTests: XCTestCase {
    func testProcessCPUUsesMonotonicDeltasAndRejectsPIDReuse() {
        let initial = ProcessCounter(startedSeconds: 1, startedMicros: 2, cpuTicks: 1_000_000_000, uptime: 10)
        let next = ProcessCounter(startedSeconds: 1, startedMicros: 2, cpuTicks: 5_000_000_000, uptime: 12)
        XCTAssertEqual(next.percent(since: initial), 200)
        XCTAssertNil(next.percent(since: nil))
        XCTAssertNil(ProcessCounter(startedSeconds: 3, startedMicros: 2, cpuTicks: 5_000_000_000, uptime: 12).percent(since: initial))
        XCTAssertNil(ProcessCounter(startedSeconds: 1, startedMicros: 2, cpuTicks: 1, uptime: 12).percent(since: initial))
    }
    func testAppleSiliconMachTicksAreConvertedUsingTimebase() {
        let initial = ProcessCounter(startedSeconds: 1, startedMicros: 0, cpuTicks: 24_000_000, uptime: 1, nanosecondsPerTick: 125.0 / 3)
        let next = ProcessCounter(startedSeconds: 1, startedMicros: 0, cpuTicks: 48_000_000, uptime: 2, nanosecondsPerTick: 125.0 / 3)
        XCTAssertEqual(next.percent(since: initial)!, 100, accuracy: 0.001)
    }
    func testCPURankingPreservesHighCPUProcessOutsideMemoryTopFive() {
        let rows = (1...10).map { ProcessUsage(id: Int32($0), name: "p", residentBytes: UInt64($0 * 100), cpuPercent: Double(11 - $0)) }
        XCTAssertEqual(ProcessUsage.top(rows).map(\.id), [10,9,8,7,6])
        XCTAssertEqual(ProcessUsage.top(rows, by: .cpu).map(\.id), [1,2,3,4,5])
    }
    func testAlertsRequireSustainedConditionAndDoNotRepeat() {
        var policy = AlertPolicy()
        for time in stride(from: 0.0, to: 60, by: 2) { XCTAssertTrue(policy.evaluate(active: [.heat], now: time).isEmpty) }
        XCTAssertEqual(policy.evaluate(active: [.heat], now: 60), [.heat])
        policy.delivered(.heat, now: 60)
        XCTAssertTrue(policy.evaluate(active: [.heat], now: 62).isEmpty)
        _ = policy.evaluate(active: [], now: 64)
        for time in stride(from: 66.0, through: 130, by: 2) { XCTAssertTrue(policy.evaluate(active: [.heat], now: time).isEmpty) }
    }
    func testSleepGapDoesNotCountAsSustainedHeat() {
        var policy = AlertPolicy()
        _ = policy.evaluate(active: [.heat], now: 0)
        XCTAssertTrue(policy.evaluate(active: [.heat], now: 120).isEmpty)
    }
    func testDiskHasLongerDelayAndConditionsAreIndependent() {
        var policy = AlertPolicy()
        for time in stride(from: 0.0, to: 60, by: 2) { _ = policy.evaluate(active: [.disk, .memory], now: time) }
        XCTAssertEqual(policy.evaluate(active: [.disk, .memory], now: 60), [.memory])
        policy.delivered(.memory, now: 60)
        for time in stride(from: 62.0, to: 120, by: 2) { _ = policy.evaluate(active: [.disk, .memory], now: time) }
        XCTAssertEqual(policy.evaluate(active: [.disk, .memory], now: 120), [.disk])
    }
    func testExplicitRPMValidationRejectsUnsafeOrNonfiniteTargets() throws {
        let fan = FanReading(id: 0, current: 3000, minimum: 1200, maximum: 6000, target: nil, manual: false)
        XCTAssertEqual(try FanPolicy.targetRPM(fan: fan, rpm: 4500, thermalState: 0), 4500)
        for rpm in [Double.nan, .infinity, 1199, 6001] {
            XCTAssertThrowsError(try FanPolicy.targetRPM(fan: fan, rpm: rpm, thermalState: 0))
        }
        XCTAssertThrowsError(try FanPolicy.targetRPM(fan: fan, rpm: 4500, thermalState: 2))
    }
    func testCooldownAllowsANewEpisodeOnlyAfterThirtyMinutes() {
        var policy = AlertPolicy()
        for time in stride(from: 0.0, through: 60, by: 2) { _ = policy.evaluate(active: [.heat], now: time) }
        policy.delivered(.heat, now: 60)
        _ = policy.evaluate(active: [], now: 62)
        for time in stride(from: 64.0, to: 1860, by: 2) { XCTAssertTrue(policy.evaluate(active: [.heat], now: time).isEmpty) }
        XCTAssertEqual(policy.evaluate(active: [.heat], now: 1860), [.heat])
    }

}
