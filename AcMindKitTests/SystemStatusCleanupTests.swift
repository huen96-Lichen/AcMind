import XCTest

final class SystemStatusCleanupTests: XCTestCase {
    func testDynamicContinentNoLegacyStatusPanels() throws {
        let source = try readSource("Features/Native/DynamicContinent/DynamicContinentConfigView.swift")
        XCTAssertFalse(source.contains("采样通道"))
        XCTAssertFalse(source.contains("权限状态"))
        XCTAssertFalse(source.contains("系统事件"))
    }

    func testVoiceEntryOnlyKeepsStatusEntry() throws {
        let source = try readSource("Features/Native/VoiceEntry/VoiceEntryView.swift")
        XCTAssertFalse(source.contains("权限状态"))
        XCTAssertTrue(source.contains("查看状态"))
    }

    func testSettingsViewsOnlyKeepStatusJump() throws {
        let suiteSource = try readSource("Features/Native/Settings/SettingsSuiteView.swift")
        let viewSource = try readSource("Features/Native/Settings/SettingsView.swift")

        XCTAssertFalse(suiteSource.contains("诊断信息"))
        XCTAssertTrue(suiteSource.contains("查看状态"))
        XCTAssertFalse(viewSource.contains("诊断信息"))
        XCTAssertTrue(viewSource.contains("查看状态"))
    }

    func testNotchSummaryRailIsLightweight() throws {
        let source = try readSource("Features/Companion/NotchV2SystemStatusRail.swift")
        XCTAssertTrue(source.contains("查看状态"))
        XCTAssertFalse(source.contains("BatteryService"))
        XCTAssertFalse(source.contains("PermissionManager"))
    }

    func testSystemStatusViewUsesSharedBackgroundAndSnapshotDriven() throws {
        let source = try readSource("Features/Native/SystemStatus/SystemStatusView.swift")
        XCTAssertTrue(source.contains("AppSurfaceTokens.background.ignoresSafeArea()"))
        XCTAssertFalse(source.contains("BatteryService.shared"))
        XCTAssertFalse(source.contains("PermissionManager"))
    }

    func testWorkspaceHomeViewDoesNotUseSystemStatusSingleton() throws {
        let source = try readSource("Features/Native/Home/WorkspaceHomeView.swift")
        XCTAssertFalse(source.contains("SystemStatusViewModel(service: .shared)"))
        XCTAssertTrue(source.contains("systemStatusService"))
    }

    func testSystemStatusViewDoesNotUseSystemStatusSingleton() throws {
        let source = try readSource("Features/Native/SystemStatus/SystemStatusView.swift")
        XCTAssertFalse(source.contains("SystemStatusViewModel(service: .shared)"))
        XCTAssertTrue(source.contains("SystemStatusViewModel(service:"))
    }

    func testServiceContainerOwnsSystemStatusServiceLifecycle() throws {
        let source = try readSource("App/ServiceContainer.swift")
        XCTAssertTrue(source.contains("public let systemStatusService"))
        XCTAssertTrue(source.contains("systemStatusService.stop()"))
    }

    func testSystemStatusServiceHasNoSharedSingleton() throws {
        let source = try readSource("AcMindKit/Services/SystemStatus/SystemStatusService.swift")
        XCTAssertFalse(source.contains("static let shared"))
    }

    func testNotchCompanionViewsUseInjectedSystemEventCenter() throws {
        let rootSource = try readSource("Features/Companion/NotchV2RootView.swift")
        let hudSource = try readSource("Features/Companion/SystemEventHUD.swift")
        let musicSource = try readSource("Features/Companion/NotchV2MusicPage.swift")

        XCTAssertTrue(rootSource.contains("SystemEventHUDView(center: viewModel.systemEventCenter)"))
        XCTAssertFalse(hudSource.contains("SystemEventCenter.shared"))
        XCTAssertFalse(musicSource.contains("SystemEventCenter.shared"))
    }

    func testNotchCompanionViewModelUsesInjectedMediaServices() throws {
        let source = try readSource("Features/Companion/NotchV2ViewModel.swift")
        XCTAssertFalse(source.contains("BatteryService.shared"))
        XCTAssertFalse(source.contains("MusicService.shared"))
        XCTAssertFalse(source.contains("SystemEventCenter.shared"))
        XCTAssertTrue(source.contains("batteryService: BatteryService"))
        XCTAssertTrue(source.contains("systemEventCenter: SystemEventCenter"))
        XCTAssertTrue(source.contains("musicService: MusicService"))
    }

    func testCompanionDemoViewsAreInjected() throws {
        let batterySource = try readSource("Features/Companion/BatteryService.swift")
        let musicSource = try readSource("Features/Companion/MusicService.swift")

        XCTAssertFalse(batterySource.contains("BatteryService.shared"))
        XCTAssertFalse(musicSource.contains("MusicService.shared"))
        XCTAssertTrue(batterySource.contains("batteryService: BatteryService"))
        XCTAssertTrue(musicSource.contains("musicService: MusicService"))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
