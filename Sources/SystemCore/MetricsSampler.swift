import Foundation
import Darwin
import IOKit

// Single owner, called on one background queue. No main-thread I/O.
public final class MetricsSampler {
    private let processSampler = ProcessSampler()
    private var previousCPU: [UInt64]?
    private var previousDisk: (UInt64, UInt64, TimeInterval)?
    public init() {}
    public func sample() -> SystemSnapshot {
        var issues: [String] = []
        let cpu = cpuUsage()
        let memory = memoryUsage()
        let disk = diskUsage()
        let allProcesses = processSampler.sample()
        let candidates = ProcessUsage.top(allProcesses) + ProcessUsage.top(allProcesses, by: .cpu)
        let processes = Array(Dictionary(candidates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values)
        if memory == nil { issues.append("Не удалось прочитать память") }
        if disk == nil { issues.append("Не удалось прочитать диск") }
        if processes.isEmpty { issues.append("Нет доступа к списку процессов") }
        return SystemSnapshot(cpu: cpu, memory: memory, disk: disk, processes: processes,
                              thermalState: ProcessInfo.processInfo.thermalState.rawValue, issues: issues)
    }
    private func cpuUsage() -> Double? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        let ticks = [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3].map(UInt64.init)
        defer { previousCPU = ticks }
        return MetricMath.cpu(previous: previousCPU, current: ticks)
    }
    private func memoryUsage() -> MemoryUsage? {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        var page: vm_size_t = 0
        guard host_page_size(mach_host_self(), &page) == KERN_SUCCESS else { return nil }
        var pressure: Int32 = 0
        var pressureSize = MemoryLayout<Int32>.size
        let pressureOK = sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &pressureSize, nil, 0) == 0
        let total = ProcessInfo.processInfo.physicalMemory
        return MemoryUsage(used: MetricMath.usedMemory(active: UInt64(info.active_count), wired: UInt64(info.wire_count),
                  compressed: UInt64(info.compressor_page_count), purgeable: UInt64(info.purgeable_count), pageSize: UInt64(page), total: total),
                  total: total, pressure: pressureOK ? Int(pressure) : 0, swapUsed: swapUsage())
    }
    private func swapUsage() -> UInt64? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0,
              size == MemoryLayout<xsw_usage>.size else { return nil }
        return usage.xsu_used
    }
    private func diskUsage() -> DiskUsage? {
        // /System/Volumes/Data is the writable user-data APFS volume.
        var volume = statfs()
        guard statfs("/System/Volumes/Data", &volume) == 0 else { return nil }
        let now = ProcessInfo.processInfo.systemUptime
        let counters = diskCounters()
        var read: Double?, write: Double?
        if let counters {
            if let previousDisk {
                read = MetricMath.rate(previous: previousDisk.0, current: counters.0, seconds: now - previousDisk.2)
                write = MetricMath.rate(previous: previousDisk.1, current: counters.1, seconds: now - previousDisk.2)
            }
            previousDisk = (counters.0, counters.1, now)
        } else { previousDisk = nil }
        return DiskUsage(free: UInt64(volume.f_bavail) * UInt64(volume.f_bsize), total: UInt64(volume.f_blocks) * UInt64(volume.f_bsize),
                         readBytesPerSecond: read, writeBytesPerSecond: write)
    }
    private func diskCounters() -> (UInt64, UInt64)? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var read: UInt64 = 0, write: UInt64 = 0, found = false
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let stats = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any],
                  let r = stats["Bytes (Read)"] as? NSNumber, let w = stats["Bytes (Write)"] as? NSNumber else { continue }
            read += r.uint64Value; write += w.uint64Value; found = true
        }
        return found ? (read, write) : nil
    }
}
