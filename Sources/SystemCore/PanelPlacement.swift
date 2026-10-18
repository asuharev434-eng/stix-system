import CoreGraphics
import Foundation

public enum PanelPlacement {
    public static func frame(content: CGSize, screen: CGRect, visible: CGRect, safeTop: CGFloat, anchorX: CGFloat?) -> CGRect {
        let margin: CGFloat = 12
        let top = min(visible.maxY, screen.maxY - max(0, safeTop)) - margin
        let width = min(content.width, max(1, visible.width - 2 * margin))
        let height = min(content.height, max(1, top - visible.minY - margin))
        let center = anchorX ?? visible.midX
        let x = min(max(center - width / 2, visible.minX + margin), visible.maxX - width - margin)
        return CGRect(x: x, y: top - height, width: width, height: height)
    }
}
