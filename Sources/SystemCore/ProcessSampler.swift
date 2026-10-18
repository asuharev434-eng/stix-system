import Foundation
import Darwin

public enum ProcessSampler {
    public static func sample() -> [ProcessUsage] {
        let capacity = proc_listallpids(nil, 0)
        guard capacity > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(capacity) + 128)
        let bytes = Int32(pids.count * MemoryLayout<pid_t>.size)
        let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, bytes) }
        guard count > 0 else { return [] }
        var rows: [ProcessUsage] = []
        for pid in pids.prefix(min(Int(count), pids.count)) where pid > 0 {
            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size, info.pti_resident_size > 0 else { continue }
            var name = [CChar](repeating: 0, count: 1024)
            let length = proc_name(pid, &name, UInt32(name.count))
            var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
            let pathLength = proc_pidpath(pid, &path, UInt32(path.count))
            let label = pathLength > 0 ? URL(fileURLWithPath: String(cString: path)).lastPathComponent : (length > 0 ? String(cString: name) : "Процесс \(pid)")
            rows.append(ProcessUsage(id: pid, name: label, residentBytes: info.pti_resident_size))
        }
        return ProcessUsage.top(rows)
    }
}
