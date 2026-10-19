import Foundation
import Darwin
import IOKit.ps

// Read-only system data, called by MetricsSampler on its background worker.
enum SystemSignalsReader {
    static func networkCounters() -> [String: NetworkCounters]? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var size = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0, size <= 16 * 1024 * 1024 else { return nil }
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<if_msghdr2>.alignment)
        defer { buffer.deallocate() }
        guard sysctl(&mib, u_int(mib.count), buffer, &size, nil, 0) == 0 else { return nil }
        var offset = 0
        var result: [String: NetworkCounters] = [:]
        while offset + 4 <= size {
            let length = Int(buffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
            guard length >= 4, length <= size - offset else { return nil }
            let type = buffer.load(fromByteOffset: offset + 3, as: UInt8.self)
            if type == RTM_IFINFO2, length >= MemoryLayout<if_msghdr2>.size {
                let entry = buffer.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                var name = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                if entry.ifm_flags & (IFF_UP | IFF_RUNNING) == (IFF_UP | IFF_RUNNING), entry.ifm_data.ifi_type == IFT_ETHER,
                   if_indextoname(UInt32(entry.ifm_index), &name) != nil {
                    let id = String(cString: name)
                    // Count carrier traffic once; utun/VPN/bridge/VM traffic is not added again.
                    if id.hasPrefix("en") {
                        result[id] = NetworkCounters(received: entry.ifm_data.ifi_ibytes, sent: entry.ifm_data.ifi_obytes)
                    }
                }
            }
            offset += length
        }
        return result
    }
    static func battery() -> BatteryUsage? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let values = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  values[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  values[kIOPSIsPresentKey] as? Bool != false,
                  let current = values[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = values[kIOPSMaxCapacityKey] as? Int,
                  let state = values[kIOPSPowerSourceStateKey] as? String,
                  state == kIOPSACPowerValue || state == kIOPSBatteryPowerValue else { continue }
            return BatteryUsage(current: current, maximum: maximum,
                                charging: values[kIOPSIsChargingKey] as? Bool ?? false, external: state == kIOPSACPowerValue)
        }
        return nil
    }
}
