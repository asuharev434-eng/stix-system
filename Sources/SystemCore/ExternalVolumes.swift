import Foundation
import DiskArbitration

public enum ExternalVolumeMath {
    /// Validates a capacity pair once and derives both the exact fill fraction and its display percent.
    public static func metrics(total: UInt64, available: UInt64) -> ExternalVolumeMetrics? {
        guard total > 0, available <= total else { return nil }
        let fraction = Double(total - available) / Double(total)
        return ExternalVolumeMetrics(usedFraction: fraction, usedPercent: Int((fraction * 100).rounded()))
    }

    /// Unknown device/network state is rejected: only positively identified local external hardware is shown.
    public static func isExternalLocalHardware(isInternal: Bool?, isNetwork: Bool?, protocolName: String?) -> Bool {
        guard isInternal == false, isNetwork == false, let protocolName else { return false }
        let normalized = protocolName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return false }
        return !["DISK IMAGE", "IMAGE", "VIRTUAL", "NETWORK", "FILE"].contains(normalized)
    }
}

public struct ExternalVolumeMetrics: Sendable, Equatable {
    public let usedFraction: Double
    public let usedPercent: Int
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
                  let usage = ExternalVolumeUsage(id: url.path, name: values.volumeName ?? url.lastPathComponent,
                                                  totalBytes: UInt64(capacity), availableBytes: UInt64(available)) else { return nil }
            return usage
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
