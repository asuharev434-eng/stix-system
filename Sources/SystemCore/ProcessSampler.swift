import Foundation
import Darwin

public struct ProcessCounter: Sendable {
    public let startedSeconds: UInt64
    public let startedMicros: UInt64
    public let cpuTicks: UInt64
    public let nanosecondsPerTick: Double
    public let uptime: TimeInterval
    public init(startedSeconds: UInt64, startedMicros: UInt64, cpuTicks: UInt64, uptime: TimeInterval, nanosecondsPerTick: Double = 1) {
        self.startedSeconds = startedSeconds; self.startedMicros = startedMicros
        self.cpuTicks = cpuTicks; self.uptime = uptime; self.nanosecondsPerTick = nanosecondsPerTick
    }
    public func percent(since previous: Self?) -> Double? {
        guard nanosecondsPerTick.isFinite, nanosecondsPerTick > 0, let previous, previous.nanosecondsPerTick == nanosecondsPerTick, previous.startedSeconds == startedSeconds, previous.startedMicros == startedMicros,
              let rate = MetricMath.rate(previous: previous.cpuTicks, current: cpuTicks, seconds: uptime - previous.uptime) else { return nil }
        // Activity Monitor convention: 100% means one fully occupied logical CPU.
        return rate * nanosecondsPerTick / 10_000_000
    }
}
public final class ProcessSampler {
    private var previous: [pid_t: ProcessCounter] = [:]
    private let nanosecondsPerTick: Double
    public init() {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        nanosecondsPerTick = Double(timebase.numer) / Double(max(1, timebase.denom))
    }
    public func sample() -> [ProcessUsage] {
        let capacity = proc_listallpids(nil, 0)
        guard capacity > 0 else { previous = [:]; return [] }
        var pids = [pid_t](repeating: 0, count: Int(capacity) + 128)
        let bytes = Int32(pids.count * MemoryLayout<pid_t>.size)
        let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, bytes) }
        guard count > 0 else { previous = [:]; return [] }
        var rows: [ProcessUsage] = [], next: [pid_t: ProcessCounter] = [:]
        for pid in pids.prefix(min(Int(count), pids.count)) where pid > 0 {
            var info = proc_taskallinfo()
            let size = Int32(MemoryLayout<proc_taskallinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, size) == size else { continue }
            let counter = ProcessCounter(startedSeconds: info.pbsd.pbi_start_tvsec, startedMicros: info.pbsd.pbi_start_tvusec,
                cpuTicks: info.ptinfo.pti_total_user &+ info.ptinfo.pti_total_system, uptime: ProcessInfo.processInfo.systemUptime, nanosecondsPerTick: nanosecondsPerTick)
            next[pid] = counter
            var name = [CChar](repeating: 0, count: 1024)
            let length = proc_name(pid, &name, UInt32(name.count))
            var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
            let pathLength = proc_pidpath(pid, &path, UInt32(path.count))
            let label = pathLength > 0 ? URL(fileURLWithPath: String(cString: path)).lastPathComponent : (length > 0 ? String(cString: name) : "Процесс \(pid)")
            rows.append(ProcessUsage(id: pid, name: label, residentBytes: info.ptinfo.pti_resident_size, cpuPercent: counter.percent(since: previous[pid])))
        }
        previous = next
        return rows
    }
}
