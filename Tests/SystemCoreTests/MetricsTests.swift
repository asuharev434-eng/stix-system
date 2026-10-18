import XCTest
@testable import SystemCore
final class MetricsTests: XCTestCase {
    func testCPUUsesDeltasAndIdleIndex() {
        XCTAssertEqual(MetricMath.cpu(previous: [10, 20, 70, 0], current: [30, 40, 130, 0])!, 0.4, accuracy: 0.001)
        XCTAssertNil(MetricMath.cpu(previous: nil, current: [1, 2, 3, 4]))
        XCTAssertNil(MetricMath.cpu(previous: [100, 2, 3, 4], current: [1, 2, 3, 4]))
        XCTAssertNil(MetricMath.cpu(previous: [1, 2, 3, 4], current: [1, 2, 3, 4]))
    }
    func testRateRejectsResetAndInvalidTime() {
        XCTAssertEqual(MetricMath.rate(previous: 10, current: 1010, seconds: 2), 500)
        XCTAssertNil(MetricMath.rate(previous: nil, current: 100, seconds: 1))
        XCTAssertNil(MetricMath.rate(previous: 100, current: 10, seconds: 1))
        XCTAssertNil(MetricMath.rate(previous: 10, current: 100, seconds: 0))
        XCTAssertNil(MetricMath.rate(previous: 10, current: 100, seconds: .nan))
    }
    func testMemoryExcludesPurgeableAndClamps() {
        XCTAssertEqual(MetricMath.usedMemory(active: 10, wired: 20, compressed: 5, purgeable: 3, pageSize: 4096, total: 1_000_000), 32 * 4096)
        XCTAssertEqual(MetricMath.usedMemory(active: 1, wired: 0, compressed: 0, purgeable: 9, pageSize: 4096, total: 100), 0)
        XCTAssertEqual(MetricMath.usedMemory(active: 10, wired: 0, compressed: 0, purgeable: 0, pageSize: 4096, total: 100), 100)
    }
    func testTopFiveSortedByRAMWithStablePIDTieBreak() {
        let rows = (1...8).map { ProcessUsage(id: Int32($0), name: "p", residentBytes: UInt64($0 * 100)) }
        XCTAssertEqual(ProcessUsage.top(rows).map(\.id), [8, 7, 6, 5, 4])
        XCTAssertEqual(ProcessUsage.top([rows[0], ProcessUsage(id: 0, name: "tie", residentBytes: 100)]).map(\.id), [0, 1])
    }
}
