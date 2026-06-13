import XCTest
import UserNotifications
@testable import AcMindKit

final class AppNotificationServiceTests: XCTestCase {
    func testFocusClassifierRecognizesFocusSensitiveApps() {
        XCTAssertTrue(AppNotificationFocusClassifier.isFocusSensitive(bundleIdentifier: "com.apple.Terminal", applicationName: "Terminal"))
        XCTAssertTrue(AppNotificationFocusClassifier.isFocusSensitive(bundleIdentifier: "com.googlecode.iterm2", applicationName: "iTerm2"))
        XCTAssertTrue(AppNotificationFocusClassifier.isFocusSensitive(bundleIdentifier: nil, applicationName: "Cursor"))
        XCTAssertFalse(AppNotificationFocusClassifier.isFocusSensitive(bundleIdentifier: "com.example.other", applicationName: "Other"))
    }

    func testPlanPrefersInlineToastWhenAcMindIsFrontmost() {
        let focus = AppNotificationFocusSnapshot(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            applicationName: "AcMind",
            source: "test"
        )

        let plan = AppNotificationStrategy.plan(focus: focus, authorizationStatus: .authorized, force: false)

        XCTAssertEqual(plan.channel, .inlineToast)
    }

    func testPlanPrefersInlineToastWhenAcMindIsFrontmostEvenIfDenied() {
        let focus = AppNotificationFocusSnapshot(
            bundleIdentifier: nil,
            applicationName: "AcMind",
            source: "test"
        )

        let plan = AppNotificationStrategy.plan(focus: focus, authorizationStatus: .denied, force: false)

        XCTAssertEqual(plan.channel, .inlineToast)
    }

    func testPlanSuppressesFocusSensitiveAppsWhenNotForced() {
        let focus = AppNotificationFocusSnapshot(
            bundleIdentifier: "com.apple.Terminal",
            applicationName: "Terminal",
            source: "test"
        )

        let plan = AppNotificationStrategy.plan(focus: focus, authorizationStatus: .authorized, force: false)

        XCTAssertEqual(plan.channel, .suppressed)
    }

    func testPlanFallsBackWhenNotificationsAreDenied() {
        let focus = AppNotificationFocusSnapshot(
            bundleIdentifier: "com.example.editor",
            applicationName: "Editor",
            source: "test"
        )

        let plan = AppNotificationStrategy.plan(focus: focus, authorizationStatus: .denied, force: false)

        XCTAssertEqual(plan.channel, .appleScriptFallback)
    }

    func testForcedNotificationsBypassSuppression() {
        let focus = AppNotificationFocusSnapshot(
            bundleIdentifier: "com.apple.Terminal",
            applicationName: "Terminal",
            source: "test"
        )

        let plan = AppNotificationStrategy.plan(focus: focus, authorizationStatus: .authorized, force: true)

        XCTAssertEqual(plan.channel, .systemNotification)
    }

    func testStrategySummaryDescribesFallbackChain() {
        let summary = AppNotificationStrategy.strategySummary

        XCTAssertTrue(summary.contains("内联提示"))
        XCTAssertTrue(summary.contains("静默"))
        XCTAssertTrue(summary.contains("AppleScript"))
    }
}
