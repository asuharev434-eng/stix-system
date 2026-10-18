import Foundation

public enum HealthAlert: String, CaseIterable, Sendable {
    case heat, memory, disk
    public var title: String {
        switch self { case .heat: return "Длительный перегрев"; case .memory: return "Мало доступной памяти"; case .disk: return "Мало места на диске" }
    }
}
// Monotonic timing, one alert per episode, and a 30-minute cooldown across episodes.
public struct AlertPolicy {
    private var started: [HealthAlert: TimeInterval] = [:]
    private var sent: Set<HealthAlert> = []
    private var lastSent: [HealthAlert: TimeInterval] = [:]
    private var lastSample: TimeInterval?
    public init() {}
    public mutating func evaluate(active: Set<HealthAlert>, now: TimeInterval) -> [HealthAlert] {
        // Suspension / long sampling gaps do not establish a sustained condition.
        if let lastSample, now < lastSample || now - lastSample > 10 { started = [:]; sent = [] }
        lastSample = now
        var ready: [HealthAlert] = []
        for kind in HealthAlert.allCases {
            guard active.contains(kind) else { started[kind] = nil; sent.remove(kind); continue }
            if started[kind] == nil { started[kind] = now }
            let delay: TimeInterval = kind == .disk ? 120 : 60
            if now - (started[kind] ?? now) >= delay, !sent.contains(kind), now - (lastSent[kind] ?? -.infinity) >= 1800 { ready.append(kind) }
        }
        return ready
    }
    public mutating func delivered(_ alert: HealthAlert, now: TimeInterval) { sent.insert(alert); lastSent[alert] = now }
}
