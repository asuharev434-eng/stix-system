import Foundation

/// Estimated reclaimable capacity. Compressed bytes stay used; file cache does not.
public struct MemoryAccounting {
    public let used: UInt64
    public let available: UInt64
    public let cached: UInt64
    public init(anonymous: UInt64, wired: UInt64, compressed: UInt64, purgeable: UInt64,
                fileBacked: UInt64, pageSize: UInt64, total: UInt64) {
        func bytes(_ counts: [UInt64], limit: UInt64) -> UInt64 {
            guard pageSize > 0 else { return 0 }
            var remaining = limit
            for count in counts {
                remaining -= min(count, remaining / pageSize) * pageSize
            }
            return limit - remaining
        }
        let reclaimableAnonymous = min(anonymous, purgeable)
        used = bytes([anonymous - reclaimableAnonymous, wired, compressed], limit: total)
        available = total - used
        cached = bytes([fileBacked, reclaimableAnonymous], limit: available)
    }
}

/// Logical swapped page throughput, not compressed physical SSD byte throughput.
public struct SwapActivity {
    private var previous: (input: UInt64, output: UInt64, time: TimeInterval)?
    public init() {}
    public mutating func sample(input: UInt64, output: UInt64, pageSize: UInt64, now: TimeInterval) -> (read: Double?, write: Double?) {
        defer { previous = (input, output, now) }
        guard let previous, now.isFinite, previous.time.isFinite,
              now > previous.time, now - previous.time <= 10, pageSize > 0,
              input >= previous.input, output >= previous.output else { return (nil, nil) }
        let seconds = now - previous.time
        return (Double(input - previous.input) * Double(pageSize) / seconds,
                Double(output - previous.output) * Double(pageSize) / seconds)
    }
}
