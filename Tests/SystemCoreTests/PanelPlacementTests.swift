import CoreGraphics
import XCTest
@testable import SystemCore
final class PanelPlacementTests: XCTestCase {
    func testNotchedScreenNeverPlacesPanelUnderCameraOrOutsideVisibleArea() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let visible = CGRect(x: 0, y: 70, width: 1512, height: 875)
        let frame = PanelPlacement.frame(content: CGSize(width: 382, height: 680), screen: screen, visible: visible, safeTop: 37, anchorX: 756)
        XCTAssertEqual(frame.maxY, 933)
        XCTAssertGreaterThanOrEqual(frame.minY, visible.minY + 12)
    }
    func testShortExternalScreenAndOffscreenAnchorAreClamped() {
        let screen = CGRect(x: -1280, y: 0, width: 1280, height: 600)
        let visible = CGRect(x: -1280, y: 50, width: 1280, height: 525)
        let frame = PanelPlacement.frame(content: CGSize(width: 382, height: 680), screen: screen, visible: visible, safeTop: 0, anchorX: 900)
        XCTAssertEqual(frame.maxX, -12)
        XCTAssertEqual(frame.minY, 62)
        XCTAssertEqual(frame.maxY, 563)
    }
}
