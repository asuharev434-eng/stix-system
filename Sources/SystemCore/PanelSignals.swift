import Foundation

public struct NetworkCounters: Sendable {
    public let received: UInt64
    public let sent: UInt64
    public init(received: UInt64, sent: UInt64) { self.received = received; self.sent = sent }
}
public struct NetworkUsage: Sendable, Codable {
    public let download: Double?
    public let upload: Double?
}
public struct NetworkRateTracker {
    private var previous: (counters: [String: NetworkCounters], time: TimeInterval)?
    public init() {}
    public mutating func sample(_ counters: [String: NetworkCounters]?, now: TimeInterval) -> NetworkUsage? {
        guard let counters, !counters.isEmpty else { previous = nil; return nil }
        defer { previous = (counters, now) }
        guard let previous, now.isFinite, previous.time.isFinite,
              now > previous.time, now - previous.time <= 10 else { return NetworkUsage(download: nil, upload: nil) }
        var download = 0.0, upload = 0.0, matched = false
        for (id, value) in counters {
            guard let old = previous.counters[id], value.received >= old.received, value.sent >= old.sent else { continue }
            matched = true
            download += Double(value.received - old.received)
            upload += Double(value.sent - old.sent)
        }
        let seconds = now - previous.time
        return NetworkUsage(download: matched ? download / seconds : nil, upload: matched ? upload / seconds : nil)
    }
}
public struct BatteryUsage: Sendable, Codable {
    public enum State: String, Sendable, Codable { case charging, external, battery }
    public let fraction: Double
    public let state: State
    public init?(current: Int, maximum: Int, charging: Bool, external: Bool) {
        guard maximum > 0, current >= 0, current <= maximum else { return nil }
        fraction = Double(current) / Double(maximum)
        state = external ? (charging ? .charging : .external) : .battery
    }
}
public enum MenuMetric: String, CaseIterable, Sendable {
    case icon, cpu, gpu, temperature
    public var title: String {
        switch self { case .icon: return "Значок"; case .cpu: return "CPU"; case .gpu: return "GPU"; case .temperature: return "Температура CPU" }
    }
    public func text(cpu: Double?, gpu: Double?, temperature: Double?) -> String? {
        func percent(_ value: Double?) -> String {
            guard let value, value.isFinite, (0...1).contains(value) else { return "—" }
            return "\(Int((value * 100).rounded()))%"
        }
        switch self {
        case .icon: return nil
        case .cpu: return "CPU \(percent(cpu))"
        case .gpu: return "GPU \(percent(gpu))"
        case .temperature:
            guard let temperature, temperature.isFinite, (0..<130).contains(temperature) else { return "—°" }
            return "\(Int(temperature.rounded()))°"
        }
    }
}
public struct HistoryPoint: Sendable {
    public let time: TimeInterval
    public let value: Double?
}
public struct MetricHistory: Sendable {
    public private(set) var points: [HistoryPoint] = []
    public init() {}
    public mutating func append(_ value: Double?, at time: TimeInterval) {
        guard time.isFinite else { return }
        if let last = points.last {
            if time < last.time { points = [] }
            else if time == last.time { points.removeLast() }
            else if time - last.time > 10 { points.append(HistoryPoint(time: last.time + 0.001, value: nil)) }
        }
        points.append(HistoryPoint(time: time, value: value.flatMap { $0.isFinite ? $0 : nil }))
        points.removeAll { $0.time < time - 900 }
        if points.count > 451 { points.removeFirst(points.count - 451) }
    }
}

public struct PanelHistory: Sendable {
    public private(set) var memory = MetricHistory()
    public private(set) var temperatures: [String: MetricHistory] = [:]
    public init() {}
    public mutating func record(memoryFraction: Double?, temperatures readings: [TemperatureReading], at time: TimeInterval) {
        memory.append(memoryFraction, at: time)
        for reading in readings {
            temperatures[reading.id, default: MetricHistory()].append(reading.celsius, at: time)
        }
    }
}
