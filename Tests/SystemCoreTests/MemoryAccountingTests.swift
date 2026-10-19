import XCTest
@testable import SystemCore

final class MemoryAccountingTests: XCTestCase {
    func testAnonymousPagesAndCompressorRemainUsedWhileCacheIsAvailable() {
        let result = MemoryAccounting(anonymous: 500, wired: 200, compressed: 100, purgeable: 50,
                                      fileBacked: 150, pageSize: 4096, total: 1000 * 4096)
        XCTAssertEqual(result.used, 750 * 4096)
        XCTAssertEqual(result.available, 250 * 4096)
        XCTAssertEqual(result.cached, 200 * 4096)
    }
    func testInconsistentCountersCannotProduceNegativeOrExcessMemory() {
        let result = MemoryAccounting(anonymous: 1, wired: 10, compressed: 5, purgeable: 20,
                                      fileBacked: 100, pageSize: 4096, total: 16 * 4096)
        XCTAssertEqual(result.used, 15 * 4096)
        XCTAssertEqual(result.cached, 4096)
        XCTAssertEqual(result.available, 4096)
    }
    func testSwapRatesNeedTwoSamplesAndRejectCounterResetOrLongGap() {
        var tracker = SwapActivity()
        XCTAssertNil(tracker.sample(input: 10, output: 20, pageSize: 16384, now: 0).read)
        let rates = tracker.sample(input: 138, output: 84, pageSize: 16384, now: 2)
        XCTAssertEqual(rates.read, 1_048_576)
        XCTAssertEqual(rates.write, 524_288)
        XCTAssertNil(tracker.sample(input: 0, output: 0, pageSize: 16384, now: 4).read)
        XCTAssertNil(tracker.sample(input: 1000, output: 1000, pageSize: 16384, now: 40).write)
        XCTAssertEqual(tracker.sample(input: 1000, output: 1000, pageSize: 16384, now: 42).read, 0)
    }
}
