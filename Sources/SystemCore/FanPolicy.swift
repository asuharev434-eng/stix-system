import Foundation

public enum FanPolicy {
    public static let leaseDuration: TimeInterval = 12
    public static func target(fan: FanReading, fraction: Double, baseline: Double, thermalState: Int) throws -> Double {
        guard fraction.isFinite, (0...1).contains(fraction), baseline.isFinite, baseline >= 0,
              fan.minimum.isFinite, fan.maximum.isFinite, fan.maximum > fan.minimum,
              fan.minimum >= 0, fan.maximum <= 20000 else { throw HardwareError.invalid("Некорректные параметры вентилятора") }
        guard thermalState < 2 else { throw HardwareError.invalid("Mac нагрет — управление возвращено системе") }
        let floor = min(fan.maximum, max(fan.minimum, baseline, 2000))
        return (floor + (fan.maximum - floor) * fraction).rounded()
    }
    public static func expired(deadline: TimeInterval?, now: TimeInterval) -> Bool {
        guard let deadline else { return false }
        return now >= deadline
    }
}

@objc public protocol FanServiceProtocol {
    func ping(reply: @escaping (String) -> Void)
    func manual(fanID: Int, fraction: Double, reply: @escaping (String?) -> Void)
    func renew(reply: @escaping (String?) -> Void)
    func automatic(fanID: Int, reply: @escaping (String?) -> Void)
}
public enum FanServiceIdentity {
    public static let label = "ru.stix.system.fans"
    public static let appIdentifier = "ru.stix.system"
    public static let plistName = "ru.stix.system.fans.plist"
}
