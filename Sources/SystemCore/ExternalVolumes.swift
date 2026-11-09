import Foundation
import DiskArbitration

public enum ExternalVolumeMath {
    /// Returns the nearest whole-percent fill level, or nil for invalid capacity data.
    public static func usedPercent(total: UInt64, available: UInt64) -> Int? {
        guard total > 0, available <= total else { return nil }
        return Int((Double(total - available) / Double(total) * 100).rounded())
    }

    /// Unknown device/network state is rejected: only positively identified local external hardware is shown.
    public static func isExternalLocalHardware(isInternal: Bool?, isNetwork: Bool?, protocolName: String?) -> Bool {
        guard isInternal == false, isNetwork == false, let protocolName else { return false }
        let normalized = protocolName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return false }
        return !["DISK IMAGE", "IMAGE", "VIRTUAL", "NETWORK", "FILE"].contains(normalized)
    }
}

public enum ExternalVolumeSampler {
    public static func sample() -> [ExternalVolumeUsage] {
        guard let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [], options: [.skipHiddenVolumes]),
              let session = DASessionCreate(kCFAllocatorDefault) else { return [] }
        return volumes.compactMap { url in
            guard let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
                  let description = DADiskCopyDescription(disk) as? [String: Any],
                  let internalValue = description[kDADiskDescriptionDeviceInternalKey as String] as? Bool,
                  let networkValue = description[kDADiskDescriptionVolumeNetworkKey as String] as? Bool,
                  let protocolName = description[kDADiskDescriptionDeviceProtocolKey as String] as? String,
                  ExternalVolumeMath.isExternalLocalHardware(isInternal: internalValue, isNetwork: networkValue, protocolName: protocolName),
                  let values = try? url.resourceValues(forKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
                  let capacity = values.volumeTotalCapacity, capacity > 0,
                  let available = values.volumeAvailableCapacity, available >= 0,
                  let percent = ExternalVolumeMath.usedPercent(total: UInt64(capacity), available: UInt64(available)) else { return nil }
            return ExternalVolumeUsage(id: url.path, name: values.volumeName ?? url.lastPathComponent, usedPercent: percent)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
