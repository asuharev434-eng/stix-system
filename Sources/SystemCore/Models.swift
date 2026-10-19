import Foundation

public enum ProcessSort: String, CaseIterable, Sendable { case memory, cpu }

public struct ProcessUsage: Identifiable, Sendable, Codable, Equatable {
    public let id: Int32
    public let name: String
    public let residentBytes: UInt64
    public let cpuPercent: Double?
    public init(id: Int32, name: String, residentBytes: UInt64, cpuPercent: Double? = nil) {
        self.id = id; self.name = name; self.residentBytes = residentBytes; self.cpuPercent = cpuPercent
    }
    public static func top(_ processes: [Self], by sort: ProcessSort = .memory) -> [Self] {
        Array(processes.sorted {
            if sort == .cpu, $0.cpuPercent != $1.cpuPercent { return ($0.cpuPercent ?? -1) > ($1.cpuPercent ?? -1) }
            return $0.residentBytes == $1.residentBytes ? $0.id < $1.id : $0.residentBytes > $1.residentBytes
        }.prefix(5))
    }

}
public struct MemoryUsage: Sendable, Codable {
    public let used: UInt64
    public let total: UInt64
    public let pressure: Int
    public let available: UInt64
    public let cached: UInt64
    public let swapReadBytesPerSecond: Double?
    public let swapWriteBytesPerSecond: Double?
    public let compressedUsed: UInt64
    public let swapUsed: UInt64?
    public var fraction: Double { total > 0 ? min(1, Double(used) / Double(total)) : 0 }
}
public struct DiskUsage: Sendable, Codable {
    public let free: UInt64
    public let total: UInt64
    public let readBytesPerSecond: Double?
    public let writeBytesPerSecond: Double?
}
public struct SystemSnapshot: Sendable, Codable {
    public let cpu: Double?
    public let gpu: Double?
    public let memory: MemoryUsage?
    public let disk: DiskUsage?
    public let processes: [ProcessUsage]
    public let thermalState: Int
    public let issues: [String]
}
public struct FanReading: Identifiable, Sendable, Codable {
    public let id: Int
    public let current: Double
    public let minimum: Double
    public let maximum: Double
    public let target: Double?
    public let manual: Bool?
    public init(id: Int, current: Double, minimum: Double, maximum: Double, target: Double?, manual: Bool?) {
        self.id = id; self.current = current; self.minimum = minimum; self.maximum = maximum; self.target = target; self.manual = manual
    }
}
public struct ThermalReading: Sendable, Codable {
    public let fans: [FanReading]
    public let temperature: Double?
    public let temperatures: [TemperatureReading]
    public let error: String?
    public init(fans: [FanReading], temperature: Double?, temperatures: [TemperatureReading] = [], error: String?) {
        self.fans = fans; self.temperature = temperature; self.temperatures = temperatures; self.error = error
    }
}
public enum MetricMath {
    public static func cpu(previous: [UInt64]?, current: [UInt64]) -> Double? {
        guard let previous, previous.count == 4, current.count == 4,
              zip(current, previous).allSatisfy({ $0 >= $1 }) else { return nil }
        let deltas = zip(current, previous).map(-)
        let total = deltas.reduce(0, +)
        guard total > 0 else { return nil }
        return min(1, max(0, 1 - Double(deltas[2]) / Double(total)))
    }
    public static func rate(previous: UInt64?, current: UInt64, seconds: Double) -> Double? {
        guard let previous, current >= previous, seconds > 0, seconds.isFinite else { return nil }
        return Double(current - previous) / seconds
    }
}
