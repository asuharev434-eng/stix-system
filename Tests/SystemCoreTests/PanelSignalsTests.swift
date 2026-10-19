import XCTest
@testable import SystemCore

final class PanelSignalsTests: XCTestCase {
    func testNetworkRatesIgnoreNewRemovedAndResetInterfaces() {
        var tracker = NetworkRateTracker()
        XCTAssertNil(tracker.sample(["en0": .init(received: 100, sent: 200)], now: 0)?.download)
        let rate = tracker.sample(["en0": .init(received: 2100, sent: 1200), "en1": .init(received: 9_000_000, sent: 8_000_000)], now: 2)
        XCTAssertEqual(rate?.download, 1000)
        XCTAssertEqual(rate?.upload, 500)
        XCTAssertNil(tracker.sample(["en0": .init(received: 0, sent: 0)], now: 4)?.download)
        XCTAssertNil(tracker.sample(["en0": .init(received: 10000, sent: 10000)], now: 40)?.upload)
        XCTAssertNil(tracker.sample(nil, now: 42))
    }
    func testBatteryStatesAndInvalidCapacity() {
        XCTAssertEqual(BatteryUsage(current: 50, maximum: 100, charging: true, external: true)?.state, .charging)
        XCTAssertEqual(BatteryUsage(current: 100, maximum: 100, charging: false, external: true)?.state, .external)
        XCTAssertEqual(BatteryUsage(current: 30, maximum: 60, charging: false, external: false)?.fraction, 0.5)
        XCTAssertNil(BatteryUsage(current: 10, maximum: 0, charging: false, external: false))
        XCTAssertNil(BatteryUsage(current: 101, maximum: 100, charging: false, external: true))
    }
    func testHistoryRetainsFifteenMinutesAndRepresentsGaps() {
        var history = MetricHistory()
        for time in stride(from: 0.0, through: 1800, by: 2) { history.append(0.5, at: time) }
        XCTAssertEqual(history.points.first?.time, 900)
        XCTAssertEqual(history.points.count, 451)
        history.append(nil, at: 1802)
        XCTAssertNil(history.points.last?.value)
        history.append(0.8, at: 1850)
        XCTAssertTrue(history.points.contains { $0.value == nil })
        history.append(0.1, at: 1)
        XCTAssertEqual(history.points.count, 1)
    }
    func testMenuMetricFormattingAndMissingValues() {
        XCTAssertNil(MenuMetric.icon.text(cpu: 0.37, gpu: 1, temperature: 65))
        XCTAssertEqual(MenuMetric.cpu.text(cpu: 0.37, gpu: nil, temperature: nil), "CPU 37%")
        XCTAssertEqual(MenuMetric.gpu.text(cpu: nil, gpu: 1, temperature: nil), "GPU 100%")
        XCTAssertEqual(MenuMetric.temperature.text(cpu: nil, gpu: nil, temperature: 65.2), "65°")
        XCTAssertEqual(MenuMetric.gpu.text(cpu: nil, gpu: nil, temperature: nil), "GPU —")
    }
}

extension PanelSignalsTests {
    func testMemoryUsageHistoryIsIndependentOfMissingRAMTemperature() {
        var history = PanelHistory()
        history.record(memoryFraction: 0.7, temperatures: [TemperatureReading(id: "memory", title: "RAM", celsius: nil, sensorCount: 0, detail: "")], at: 100)
        XCTAssertEqual(history.memory.points.last?.value, 0.7)
        XCTAssertNil(history.temperatures["memory"]?.points.last?.value)
    }
}
