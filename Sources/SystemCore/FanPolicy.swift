import Foundation

public enum FanPolicy {
    // Application protection threshold, not an Apple hardware specification.
    public static let overheatCelsius: Double = 95
    public static func overheated(_ reading: ThermalReading, thermalState: Int) -> Bool {
        if thermalState >= 2 { return true }
        let chipTemperatures = reading.temperatures.filter { $0.id == "cpu" || $0.id == "gpu" }.compactMap(\.celsius)
        return (chipTemperatures + [reading.temperature].compactMap { $0 }).contains { $0.isFinite && $0 >= overheatCelsius }
    }
    public static func blockReason(_ reading: ThermalReading?, thermalState: Int) -> String? {
        if let reading, overheated(reading, thermalState: 0) {
            return "Ручной режим недоступен: CPU/GPU ≥95 °C. Управление — Авто."
        }
        if thermalState >= 2 {
            let state = thermalState == 2 ? "serious" : "critical"
            return "Ручной режим недоступен: статус macOS \(state). Управление — Авто."
        }
        return nil
    }
    public static let leaseDuration: TimeInterval = 12
    public static func target(fan: FanReading, fraction: Double, thermalState: Int) throws -> Double {
        guard fraction.isFinite, (0...1).contains(fraction),
              fan.minimum.isFinite, fan.maximum.isFinite, fan.maximum > fan.minimum,
              fan.minimum >= 0, fan.maximum <= 20000 else { throw HardwareError.invalid("Некорректные параметры вентилятора") }
        guard thermalState < 2 else { throw HardwareError.invalid("Mac нагрет — управление возвращено системе") }
        let floor = 0.0
        return (floor + (fan.maximum - floor) * fraction).rounded()
    }
    public static func targetRPM(fan: FanReading, rpm: Double, thermalState: Int) throws -> Double {
        let floor = try target(fan: fan, fraction: 0, thermalState: thermalState)
        guard rpm.isFinite, rpm >= floor, rpm <= fan.maximum else {
            throw HardwareError.invalid("Допустимо \(Int(floor))–\(Int(fan.maximum)) об/мин")
        }
        return rpm.rounded()
    }
    public static func expired(deadline: TimeInterval?, now: TimeInterval) -> Bool {
        guard let deadline else { return false }
        return now >= deadline
    }
}

@objc public protocol FanServiceProtocol {
    func ping(reply: @escaping (String) -> Void)
    func manual(fanID: Int, fraction: Double, reply: @escaping (String?) -> Void)
    func manualRPM(fanID: Int, rpm: Double, reply: @escaping (String?) -> Void)
    func renew(reply: @escaping (String?) -> Void)
    func automatic(fanID: Int, reply: @escaping (String?) -> Void)
}
public enum FanServiceIdentity {
    public static let label = "ru.stix.system.fans"
    public static let appIdentifier = "ru.stix.system"
    public static let plistName = "ru.stix.system.fans.plist"
}
