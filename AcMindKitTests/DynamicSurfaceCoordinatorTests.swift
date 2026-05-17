import XCTest
import AppKit
@testable import AcMindKit

@MainActor
final class DynamicSurfaceCoordinatorTests: XCTestCase {
    private let capsulePositionKey = "DesktopCapsule.position"
    private let continentScreenKey = "DynamicSurface.continentTopDockScreenID"
    private let visibilityStateKey = "DynamicSurface.visibilityState"
    private var userDefaultsSuiteName: String!

    override func setUp() {
        super.setUp()
        userDefaultsSuiteName = "AcMindKitTests.DynamicSurfaceCoordinatorTests.\(UUID().uuidString)"
        clearPersistedState()
    }

    override func tearDown() {
        clearPersistedState()
        userDefaultsSuiteName = nil
        super.tearDown()
    }

    func testTopDockHotZoneUsesNinetySixPixels() throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main screen available")
        }

        let topPoint = CGPoint(x: screen.frame.midX, y: screen.frame.maxY - 1)
        let lowerPoint = CGPoint(x: screen.frame.midX, y: screen.frame.maxY - 120)

        XCTAssertTrue(CompanionScreenPositioning.isPointInTopDockHotZone(topPoint, screen: screen))
        XCTAssertFalse(CompanionScreenPositioning.isPointInTopDockHotZone(lowerPoint, screen: screen))
    }

    func testCapsuleDragCommitsToContinentWhenEndingInTopHotZone() throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main screen available")
        }

        let coordinator = makeCoordinator()
        let capsule = MockSurfaceAdapter()
        let continent = MockSurfaceAdapter()
        coordinator.registerCapsuleAdapter(capsule)
        coordinator.registerContinentAdapter(continent)

        let topPoint = CGPoint(x: screen.frame.midX, y: screen.frame.maxY - 4)
        coordinator.capsuleDragBegan(at: topPoint)
        coordinator.capsuleDragChanged(to: topPoint)

        XCTAssertTrue(capsule.isVisible)
        XCTAssertFalse(continent.isVisible)
        XCTAssertEqual(capsule.visibleSurfaceCount + continent.visibleSurfaceCount, 1)

        coordinator.capsuleDragEnded(at: topPoint)

        XCTAssertEqual(coordinator.visibilityState, .continentCompact)
        XCTAssertEqual(coordinator.dragPhase, .idle)
        XCTAssertTrue(capsule.didHide)
        XCTAssertTrue(continent.didShowCompact)
        XCTAssertEqual(capsule.visibleSurfaceCount + continent.visibleSurfaceCount, 1)
    }

    func testCapsuleToContinentHidesCapsule() throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main screen available")
        }

        let coordinator = makeCoordinator()
        let capsule = MockSurfaceAdapter()
        let continent = MockSurfaceAdapter()
        coordinator.registerCapsuleAdapter(capsule)
        coordinator.registerContinentAdapter(continent)

        let topPoint = CGPoint(x: screen.frame.midX, y: screen.frame.maxY - 4)
        coordinator.capsuleDragBegan(at: topPoint)
        coordinator.capsuleDragChanged(to: topPoint)
        coordinator.capsuleDragEnded(at: topPoint)

        XCTAssertEqual(coordinator.visibilityState, .continentCompact)
        XCTAssertFalse(capsule.isVisible)
        XCTAssertTrue(continent.isVisible)
        XCTAssertEqual(capsule.visibleSurfaceCount + continent.visibleSurfaceCount, 1)
    }

    func testContinentDragReturnsToCapsuleWhenEndingInDesktopZone() throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main screen available")
        }

        let coordinator = makeCoordinator()
        let capsule = MockSurfaceAdapter()
        let continent = MockSurfaceAdapter()
        coordinator.registerCapsuleAdapter(capsule)
        coordinator.registerContinentAdapter(continent)

        let topPoint = CGPoint(x: screen.frame.midX, y: screen.frame.maxY - 4)
        let desktopPoint = CGPoint(x: screen.frame.midX, y: max(screen.frame.minY + 80, screen.frame.maxY - 200))

        coordinator.continentLongPressBegan(at: topPoint)
        coordinator.continentDragChanged(to: desktopPoint)

        XCTAssertTrue(continent.isVisible)
        XCTAssertFalse(capsule.isVisible)
        XCTAssertEqual(capsule.visibleSurfaceCount + continent.visibleSurfaceCount, 1)

        coordinator.continentDragEnded(at: desktopPoint)

        XCTAssertEqual(coordinator.visibilityState, .capsuleCompact)
        XCTAssertEqual(coordinator.dragPhase, .idle)
        XCTAssertTrue(continent.didHide)
        XCTAssertTrue(capsule.didShowCompact)
        XCTAssertEqual(capsule.visibleSurfaceCount + continent.visibleSurfaceCount, 1)
    }

    func testContinentToCapsuleHidesContinent() throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main screen available")
        }

        let coordinator = makeCoordinator()
        let capsule = MockSurfaceAdapter()
        let continent = MockSurfaceAdapter()
        coordinator.registerCapsuleAdapter(capsule)
        coordinator.registerContinentAdapter(continent)

        let topPoint = CGPoint(x: screen.frame.midX, y: screen.frame.maxY - 4)
        let desktopPoint = CGPoint(x: screen.frame.midX, y: max(screen.frame.minY + 80, screen.frame.maxY - 200))

        coordinator.continentLongPressBegan(at: topPoint)
        coordinator.continentDragChanged(to: desktopPoint)
        coordinator.continentDragEnded(at: desktopPoint)

        XCTAssertEqual(coordinator.visibilityState, .capsuleCompact)
        XCTAssertFalse(continent.isVisible)
        XCTAssertTrue(capsule.isVisible)
        XCTAssertEqual(capsule.visibleSurfaceCount + continent.visibleSurfaceCount, 1)
    }

    func testOnlyOneSurfaceVisibleAfterRestore() throws {
        let persistedCoordinator = makeCoordinator()
        let persistedCapsule = MockSurfaceAdapter()
        let persistedContinent = MockSurfaceAdapter()
        persistedCoordinator.registerCapsuleAdapter(persistedCapsule)
        persistedCoordinator.registerContinentAdapter(persistedContinent)
        persistedCoordinator.transition(to: .continentCompact, reason: .manualCommand)

        let restoredCoordinator = makeCoordinator()
        let restoredCapsule = MockSurfaceAdapter()
        let restoredContinent = MockSurfaceAdapter()
        restoredCoordinator.registerCapsuleAdapter(restoredCapsule)
        restoredCoordinator.registerContinentAdapter(restoredContinent)
        restoredCoordinator.restoreLastSurface()

        XCTAssertEqual(restoredCoordinator.visibilityState, .continentCompact)
        XCTAssertTrue(restoredContinent.isVisible)
        XCTAssertFalse(restoredCapsule.isVisible)
        XCTAssertEqual(restoredCapsule.visibleSurfaceCount + restoredContinent.visibleSurfaceCount, 1)
    }

    func testPreviewDoesNotCommitVisibilityBeforeMouseUp() throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No main screen available")
        }

        let coordinator = makeCoordinator()
        let capsule = MockSurfaceAdapter()
        let continent = MockSurfaceAdapter()
        coordinator.registerCapsuleAdapter(capsule)
        coordinator.registerContinentAdapter(continent)

        let topPoint = CGPoint(x: screen.frame.midX, y: screen.frame.maxY - 4)
        coordinator.capsuleDragBegan(at: topPoint)
        coordinator.capsuleDragChanged(to: topPoint)

        XCTAssertEqual(coordinator.visibilityState, .capsuleCompact)
        XCTAssertTrue(capsule.isVisible)
        XCTAssertFalse(continent.isVisible)
        XCTAssertEqual(capsule.visibleSurfaceCount + continent.visibleSurfaceCount, 1)
        XCTAssertEqual(continent.didShowCompactCount, 0)

        coordinator.capsuleDragEnded(at: topPoint)

        XCTAssertEqual(coordinator.visibilityState, .continentCompact)
        XCTAssertTrue(continent.isVisible)
        XCTAssertFalse(capsule.isVisible)
        XCTAssertEqual(capsule.visibleSurfaceCount + continent.visibleSurfaceCount, 1)
    }

    func testDirectShowCannotLeaveBothPanelsVisible() throws {
        let coordinator = makeCoordinator()
        let capsule = MockSurfaceAdapter()
        let continent = MockSurfaceAdapter()
        coordinator.registerCapsuleAdapter(capsule)
        coordinator.registerContinentAdapter(continent)

        coordinator.transition(to: .capsuleCompact, reason: .manualCommand)
        coordinator.transition(to: .continentCompact, reason: .manualCommand)

        XCTAssertTrue(continent.isVisible)
        XCTAssertFalse(capsule.isVisible)
        XCTAssertEqual(capsule.visibleSurfaceCount + continent.visibleSurfaceCount, 1)
    }

    private func clearPersistedState() {
        guard let suite = userDefaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) else { return }
        suite.removePersistentDomain(forName: userDefaultsSuiteName)
        suite.synchronize()
    }

    private func makeCoordinator() -> DynamicSurfaceCoordinator {
        guard let suite = userDefaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) else {
            return DynamicSurfaceCoordinator()
        }
        return DynamicSurfaceCoordinator(userDefaults: suite)
    }
}

@MainActor
private final class MockSurfaceAdapter: DynamicSurfacePanelAdapter {
    private(set) var didShowCompact = false
    private(set) var didShowExpanded = false
    private(set) var didHide = false
    private(set) var beginPreviewCount = 0
    private(set) var endPreviewCount = 0
    private(set) var didShowCompactCount = 0
    private(set) var didShowExpandedCount = 0
    private(set) var isVisible = false

    func showCompact(on screen: NSScreen?, at point: CGPoint?, animated: Bool) {
        didShowCompact = true
        didShowCompactCount += 1
        isVisible = true
    }

    func showExpanded(on screen: NSScreen?, at point: CGPoint?, animated: Bool) {
        didShowExpanded = true
        didShowExpandedCount += 1
        isVisible = true
    }

    func hide(animated: Bool) {
        didHide = true
        isVisible = false
    }

    func beginDragPreview() {
        beginPreviewCount += 1
    }

    func updateDragPreview(mouseLocation: CGPoint, phase: DynamicSurfaceDragPhase) {
    }

    func endDragPreview() {
        endPreviewCount += 1
    }

    var visibleSurfaceCount: Int {
        isVisible ? 1 : 0
    }
}
