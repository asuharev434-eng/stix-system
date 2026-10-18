import Foundation

public protocol FanHardware: AnyObject {
    func snapshot() -> ThermalReading
    func setManual(id: Int, rpm: Double) throws
    func restoreAutomatic() throws
    func restoreAutomatic(id: Int) throws
}
extension SMC: FanHardware {}

// All entry points run on the service's single serial queue.
public final class FanController {
    private let hardware: FanHardware
    private let clock: () -> TimeInterval
    private let thermal: () -> Int
    private let markActive: () throws -> Void
    private let markInactive: () throws -> Void
    private var baseline: [Int: Double] = [:]
    private var owner: String?
    private var manualIDs: Set<Int> = []
    private var deadline: TimeInterval?
    public private(set) var active = false
    public init(hardware: FanHardware, recoveryNeeded: Bool = false,
                clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
                thermal: @escaping () -> Int = { ProcessInfo.processInfo.thermalState.rawValue },
                markActive: @escaping () throws -> Void = {}, markInactive: @escaping () throws -> Void = {}) {
        self.hardware = hardware; self.clock = clock; self.thermal = thermal
        self.markActive = markActive; self.markInactive = markInactive
        active = recoveryNeeded
        if recoveryNeeded { deadline = 0 }
    }
    public func manual(fraction: Double, owner client: String, fanID: Int? = nil) throws {
        try apply(owner: client, fanID: fanID) { fan, baseline, thermal in
            try FanPolicy.target(fan: fan, fraction: fraction, baseline: baseline, thermalState: thermal)
        }
    }
    public func manualRPM(rpm: Double, owner client: String, fanID: Int? = nil) throws {
        try apply(owner: client, fanID: fanID) { fan, baseline, thermal in
            try FanPolicy.targetRPM(fan: fan, rpm: rpm, baseline: baseline, thermalState: thermal)
        }
    }
    private func apply(owner client: String, fanID: Int?, target: (FanReading, Double, Int) throws -> Double) throws {
        guard owner == nil || owner == client else { throw HardwareError.invalid("Управление занято другим экземпляром приложения") }
        guard !(active && owner == nil) else { throw HardwareError.invalid("Ожидается восстановление автоматического режима") }
        let reading = hardware.snapshot()
        guard !reading.fans.isEmpty, reading.error == nil else { throw HardwareError.unavailable }
        if !active {
            guard reading.fans.allSatisfy({ $0.manual == false }) else {
                throw HardwareError.invalid("Вентиляторами уже управляет другая программа")
            }
            baseline = Dictionary(uniqueKeysWithValues: reading.fans.map { ($0.id, $0.current) })
        }
        if let fanID, !reading.fans.contains(where: { $0.id == fanID }) { throw HardwareError.invalid("Некорректный вентилятор") }
        let selected = reading.fans.filter { fanID == nil || $0.id == fanID }
        let targets = try selected.map { fan in
            (fan.id, try target(fan, baseline[fan.id] ?? fan.current, thermal()))
        }
        // Persist recovery intent before touching firmware, including its diagnostic unlock.
        try markActive()
        active = true; owner = client; deadline = clock() + FanPolicy.leaseDuration
        do {
            for (id, rpm) in targets { try hardware.setManual(id: id, rpm: rpm) }
            manualIDs.formUnion(selected.map(\.id))
            guard thermal() < 2 else { throw HardwareError.invalid("Mac нагрет — ручной режим отменён") }
            deadline = clock() + FanPolicy.leaseDuration
        } catch {
            do { try restore() }
            catch let restoreError {
                throw HardwareError.invalid("\(error.localizedDescription). Возврат в Авто: \(restoreError.localizedDescription)")
            }
            throw error
        }
    }
    public func automatic(fanID: Int, owner client: String) throws {
        guard hardware.snapshot().fans.contains(where: { $0.id == fanID }) else { throw HardwareError.invalid("Некорректный вентилятор") }
        guard active else { return }
        guard owner == client else { throw HardwareError.invalid("Управление занято другим экземпляром приложения") }
        guard manualIDs.contains(fanID) else { return }
        if manualIDs.count == 1 { try restore(); return }
        do {
            try hardware.restoreAutomatic(id: fanID)
            manualIDs.remove(fanID)
            deadline = clock() + FanPolicy.leaseDuration
        } catch {
            deadline = 0
            throw error
        }
    }
    public func renew(owner client: String) throws {
        guard active, owner == client else { throw HardwareError.invalid("Ручная сессия завершена") }
        if FanPolicy.expired(deadline: deadline, now: clock()) || thermal() >= 2 {
            try restore()
            throw HardwareError.invalid("Управление возвращено macOS")
        }
        deadline = clock() + FanPolicy.leaseDuration
    }
    public func restore() throws {
        guard active else { return }
        // Keep recovery armed if any write/read-back or journal cleanup fails.
        deadline = 0
        try hardware.restoreAutomatic()
        try markInactive()
        active = false; owner = nil; deadline = nil; baseline = [:]; manualIDs = []
    }
    public func release(owner client: String) throws {
        if owner == client { try restore() }
    }
    public func tick() throws {
        if active && (FanPolicy.expired(deadline: deadline, now: clock()) || thermal() >= 2) { try restore() }
    }
}
