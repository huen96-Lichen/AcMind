import XCTest
@testable import AcMindKit

@MainActor
final class HotCornerManagerTests: XCTestCase {
    func testCornerHitTestingFindsTheCorrectScreenCorner() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertEqual(HotCornerGeometry.corner(at: CGPoint(x: 5, y: 895), in: screen), .topLeft)
        XCTAssertEqual(HotCornerGeometry.corner(at: CGPoint(x: 1435, y: 895), in: screen), .topRight)
        XCTAssertEqual(HotCornerGeometry.corner(at: CGPoint(x: 5, y: 5), in: screen), .bottomLeft)
        XCTAssertEqual(HotCornerGeometry.corner(at: CGPoint(x: 1435, y: 5), in: screen), .bottomRight)
    }

    func testCornerHitTestingRespectsRoundedCutout() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertNil(HotCornerGeometry.corner(at: CGPoint(x: 20, y: 880), in: screen))
        XCTAssertNil(HotCornerGeometry.corner(at: CGPoint(x: 1420, y: 880), in: screen))
        XCTAssertNil(HotCornerGeometry.corner(at: CGPoint(x: 20, y: 20), in: screen))
        XCTAssertNil(HotCornerGeometry.corner(at: CGPoint(x: 1420, y: 20), in: screen))
    }

    func testCornerSizeExpandsTheTriggerArea() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let point = CGPoint(x: 20, y: 880)

        XCTAssertNil(HotCornerGeometry.corner(at: point, in: screen))
        XCTAssertEqual(HotCornerGeometry.corner(at: point, in: screen, size: 90), .topLeft)
    }

    func testOverlayFrameAnchorsToCorner() {
        let screen = CGRect(x: 100, y: 200, width: 1000, height: 800)

        XCTAssertEqual(
            HotCornerGeometry.overlayFrame(for: .topLeft, in: screen),
            CGRect(x: 100, y: 976, width: 24, height: 24)
        )
        XCTAssertEqual(
            HotCornerGeometry.overlayFrame(for: .topRight, in: screen),
            CGRect(x: 1076, y: 976, width: 24, height: 24)
        )
        XCTAssertEqual(
            HotCornerGeometry.overlayFrame(for: .bottomLeft, in: screen),
            CGRect(x: 100, y: 200, width: 24, height: 24)
        )
        XCTAssertEqual(
            HotCornerGeometry.overlayFrame(for: .bottomRight, in: screen),
            CGRect(x: 1076, y: 200, width: 24, height: 24)
        )
    }

    func testOverlayCutoutRectAnchorsToEachCorner() {
        let bounds = CGRect(x: 0, y: 0, width: 24, height: 24)

        XCTAssertEqual(
            HotCornerGeometry.overlayCutoutRect(for: .topLeft, in: bounds),
            CGRect(x: 0, y: -24, width: 48, height: 48)
        )
        XCTAssertEqual(
            HotCornerGeometry.overlayCutoutRect(for: .topRight, in: bounds),
            CGRect(x: -24, y: -24, width: 48, height: 48)
        )
        XCTAssertEqual(
            HotCornerGeometry.overlayCutoutRect(for: .bottomLeft, in: bounds),
            CGRect(x: 0, y: 0, width: 48, height: 48)
        )
        XCTAssertEqual(
            HotCornerGeometry.overlayCutoutRect(for: .bottomRight, in: bounds),
            CGRect(x: -24, y: 0, width: 48, height: 48)
        )
    }

    func testHoverDelayTriggersOnlyAfterDwell() async {
        var triggered = false
        let manager = HotCornerManager(actionExecutor: { _ in triggered = true })
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let settings = HotCornerSettings(
            bindings: [
                .topLeft: HotCornerBinding(hoverDelay: 0.05, action: .openURL(urlString: "https://example.com"))
            ]
        )

        manager.update(settings: settings)
        manager.update(mouseLocation: CGPoint(x: 5, y: 895), screenFrames: [screen])

        try? await Task.sleep(for: .milliseconds(150))

        XCTAssertTrue(triggered)
    }
}
