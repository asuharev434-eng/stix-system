import XCTest
@testable import SystemCore
final class TemperatureTests: XCTestCase {
    func testEachComponentUsesOwnSensorsAndMaximum() {
        let values = ["Tp01": 75.0, "Tp09": 88, "Te05": 65, "Tg1U": 51, "Tg1k": 55, "Tm0p": 41, "TH0x": 43, "TB1T": 33, "TB2T": 35]
        let readings = TemperatureCatalog.sample(chip: "Apple M4 Pro") { values[$0] }
        XCTAssertEqual(readings.map(\.celsius), [88, 55, 41, 43, 35])
        XCTAssertEqual(readings[0].sensorCount, 3)
    }
    func testInvalidMissingAndUnmappedSensorsRemainUnavailable() {
        let readings = TemperatureCatalog.sample(chip: "Apple M4 Pro") { key in
            switch key { case "Tp01": return .nan; case "TH0x": return 140; case "TB1T": return 0; default: return nil }
        }
        XCTAssertTrue(readings.allSatisfy { $0.celsius == nil && $0.sensorCount == 0 })
        let unknown = TemperatureCatalog.sample(chip: "Unknown") { $0 == "Tp09" ? 75 : nil }
        XCTAssertTrue(unknown.allSatisfy { $0.celsius == nil })
    }
}
