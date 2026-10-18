import Foundation
import Darwin

public struct TemperatureReading: Identifiable, Codable, Sendable {
    public let id: String
    public let title: String
    public let celsius: Double?
    public let sensorCount: Int
    public let detail: String
}
public enum TemperatureCatalog {
    public static func chipName() -> String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else { return "Unknown" }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &bytes, &size, nil, 0) == 0 else { return "Unknown" }
        return String(cString: bytes)
    }
    public static func sample(chip: String, read: (String) -> Double?) -> [TemperatureReading] {
        let m4 = chip.contains("Apple M4")
        let proGPU = chip.contains("Pro") || chip.contains("Max")
        let m4GPU = (proGPU ? ["Tg1U", "Tg1k"] : ["Tg0G", "Tg0H"]) + ["Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k"]
        // Sensor identities are model-specific. Never infer component names just
        // from a T-prefixed key, and never reuse a CPU sensor as another component.
        let groups: [(String, String, [String], String)] = [
            ("cpu", "CPU", m4 ? ["Te05", "Te0S", "Te09", "Te0H", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"] : ["TC0P"], "Максимум доступных датчиков CPU"),
            ("gpu", "GPU", m4 ? m4GPU : ["TG0P"], "Максимум доступных датчиков GPU"),
            ("memory", "RAM", m4 ? ["Tm0p", "Tm1p", "Tm2p"] : [], "Температура рядом с памятью, максимум датчиков proximity"),
            ("ssd", "SSD", ["TH0x"], "Датчик NAND внутреннего накопителя"),
            ("battery", "Батарея", ["TB1T", "TB2T"], "Максимум доступных датчиков батареи")
        ]
        return groups.map { id, title, keys, detail in
            let values = keys.compactMap(read).filter { $0.isFinite && $0 > 0 && $0 < 130 }
            return TemperatureReading(id: id, title: title, celsius: values.max(), sensorCount: values.count, detail: detail)
        }
    }
}
