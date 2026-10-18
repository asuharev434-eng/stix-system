import Foundation
import SMCBridge

public enum HardwareError: LocalizedError {
    case unavailable
    case operation(String, Int32)
    case invalid(String)
    public var errorDescription: String? {
        switch self {
        case .unavailable: return "SMC недоступен на этом Mac"
        case .operation(let key, let code): return "SMC \(key): ошибка 0x\(String(UInt32(bitPattern: code), radix: 16))"
        case .invalid(let reason): return reason
        }
    }
}
// Not shared across queues. Only the privileged service calls write methods.
public final class SMC {
    private let handle: OpaquePointer?
    private let chip = TemperatureCatalog.chipName()
    public init() { handle = stix_smc_open() }
    deinit { stix_smc_close(handle) }
    public func read(_ key: String) -> Double? {
        var value = 0.0
        guard key.utf8.count == 4, stix_smc_read(handle, key, &value) == 0 else { return nil }
        return value
    }
    public func snapshot() -> ThermalReading {
        guard handle != nil else { return ThermalReading(fans: [], temperature: nil, error: HardwareError.unavailable.localizedDescription) }
        guard let count = read("FNum"), count >= 0, count <= 10, count.rounded() == count else {
            return ThermalReading(fans: [], temperature: nil, error: "SMC не сообщает список вентиляторов")
        }
        let fans = (0..<Int(count)).compactMap { id -> FanReading? in
            guard let current = read("F\(id)Ac"), let min = read("F\(id)Mn"), let max = read("F\(id)Mx"),
                  current >= 0, min >= 0, max > min, max <= 20000 else { return nil }
            let mode = read(modeKey(id))
            return FanReading(id: id, current: current, minimum: min, maximum: max, target: read("F\(id)Tg"),
                              manual: mode.map { $0 == 1 })
        }
        // Labelled as a sensor reading; thermal warnings use the OS thermal state.
        let temperatures = TemperatureCatalog.sample(chip: chip, read: read)
        let temperature = temperatures.first(where: { $0.id == "cpu" })?.celsius
        return ThermalReading(fans: fans, temperature: temperature, temperatures: temperatures,
                              error: fans.count != Int(count) ? "Часть датчиков вентиляторов недоступна" : nil)
    }
    private func modeKey(_ id: Int) -> String {
        read("F\(id)Md") != nil ? "F\(id)Md" : "F\(id)md"
    }
    private func write(_ key: String, _ value: Double, attempts: Int = 5) throws {
        var last: Int32 = 0
        for _ in 0..<attempts {
            last = stix_smc_write_fan(handle, key, value)
            if last == 0 { return }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw HardwareError.operation(key, last)
    }
    public func setManual(id: Int, rpm: Double) throws {
        guard (0..<10).contains(id) else { throw HardwareError.invalid("Некорректный вентилятор") }
        let key = modeKey(id)
        #if arch(arm64)
        // M1–M4 thermalmonitord may acknowledge a mode write and immediately undo
        // it. If the firmware exposes Ftst, acquire that handoff before any mode write.
        if let unlock = read("Ftst"), unlock != 1 {
            try write("Ftst", 1, attempts: 20)
            Thread.sleep(forTimeInterval: 3)
        }
        #endif
        var confirmed = false
        for _ in 0..<60 {
            if read(key) != 1 { try write(key, 1) }
            try write("F\(id)Tg", rpm)
            Thread.sleep(forTimeInterval: 0.1)
            if read(key) == 1, let target = read("F\(id)Tg"), abs(target - rpm) < 5 {
                confirmed = true; break
            }
        }
        guard confirmed else {
            throw HardwareError.invalid("SMC не подтвердил ручной режим: \(key)=\(read(key) ?? -1), цель=\(read("F\(id)Tg") ?? -1), Ftst=\(read("Ftst") ?? -1)")
        }
    }

    private func restartStoppedFans(_ fans: [FanReading]) throws {
        // Start all stopped fans before releasing any mode. Firmware can take
        // several seconds to accept a mode transition after a zero target.
        for fan in fans where fan.manual == true && (fan.target == 0 || fan.current < 100) {
            try setManual(id: fan.id, rpm: fan.maximum)
        }
    }
    private func releaseModes(_ fans: [FanReading]) throws {
        var lastError: Error?
        for _ in 0..<120 {
            for fan in fans {
                if let mode = read(modeKey(fan.id)), mode == 0 || mode == 3 { continue }
                do { try write(modeKey(fan.id), 0, attempts: 1) }
                catch { lastError = error }
            }
            if fans.allSatisfy({ fan in
                guard let mode = read(modeKey(fan.id)) else { return false }
                return mode == 0 || mode == 3
            }) { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw lastError ?? HardwareError.invalid("SMC не подтвердил автоматический режим")
    }
    public func restoreAutomatic(id: Int) throws {
        guard let fan = snapshot().fans.first(where: { $0.id == id }) else { throw HardwareError.invalid("Некорректный вентилятор") }
        try restartStoppedFans([fan])
        try releaseModes([fan])
    }
    public func restoreAutomatic() throws {
        let fans = snapshot().fans
        guard !fans.isEmpty else { throw HardwareError.unavailable }
        try restartStoppedFans(fans)
        try releaseModes(fans)
        if read("Ftst") != nil { try write("Ftst", 0) }
        for _ in 0..<40 {
            let after = snapshot()
            if after.fans.count == fans.count && after.fans.allSatisfy({ $0.manual == false }) && (read("Ftst") ?? 0) == 0 { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw HardwareError.invalid("SMC не подтвердил автоматический режим")
    }
}
