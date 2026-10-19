import Foundation

public enum GPUUsage {
    // Device utilization is a percentage, not the renderer/tiler counters.
    public static func fraction(percentages: [Double]) -> Double? {
        percentages.filter { $0.isFinite && (0...100).contains($0) }.max().map { $0 / 100 }
    }
}
