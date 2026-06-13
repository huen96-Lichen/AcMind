import XCTest

final class SystemStatusCleanupTests: XCTestCase {
    func testDynamicContinentNoLegacyStatusPanels() throws {
        let source = try readSource("Features/Native/DynamicContinent/DynamicContinentConfigView.swift")
        XCTAssertFalse(source.contains("采样通道"))
        XCTAssertFalse(source.contains("权限状态"))
        XCTAssertFalse(source.contains("系统事件"))
        XCTAssertTrue(source.contains("SettingsStatusLabelFormatter.binaryState"))
        XCTAssertTrue(source.contains("enabledText: \"已启用 · 停留"))
    }

    func testAgentDashboardUsesSharedActivityAndProcessingLabels() throws {
        let source = try readSource("Features/Native/Agent/AgentDashboardView.swift")
        XCTAssertTrue(source.contains("ActivityStateLabelFormatter.activityLabel"))
        XCTAssertTrue(source.contains("ToolStatusLabelFormatter.processingText"))
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

    func testShowSystemStatusRoutesToSystemStatusSelection() throws {
        let source = try readSource("App/AppDelegate.swift")
        XCTAssertTrue(source.contains("case .systemStatus:"))
        XCTAssertTrue(source.contains("appState.selectSidebarItem(.systemStatus)"))
        XCTAssertTrue(source.contains("@objc func showSystemStatus()"))
    }

    func testNotchSystemStatusPageIsAlwaysSelectable() throws {
        let source = try readSource("Features/Companion/NotchV2ViewModel.swift")
        XCTAssertTrue(source.contains("func openSystemStatusPage()"))
        XCTAssertTrue(source.contains("case .systemStatus:"))
        XCTAssertTrue(source.contains("return true"))
    }

    func testNotchAttentionHintOpensCompanionStatusPageDirectly() throws {
        let source = try readSource("Features/Companion/NotchV2ViewModel.swift")
        XCTAssertTrue(source.contains("Button(\"查看状态\")"))
        XCTAssertTrue(source.contains("openSystemStatusPage()"))
    }

    func testAppSurfaceCardSupportsVerticalStretching() throws {
        let source = try readSource("Features/Native/Shared/AppSurfaceStyle.swift")
        XCTAssertTrue(source.contains("let fillHeight: Bool"))
        XCTAssertTrue(source.contains("frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil"))
    }

    func testSystemStatusViewUsesSharedBackgroundAndSnapshotDriven() throws {
        let source = try readSource("Features/Native/SystemStatus/SystemStatusView.swift")
        XCTAssertTrue(source.contains("AppSurfaceTokens.background.ignoresSafeArea()"))
        XCTAssertFalse(source.contains("BatteryService.shared"))
        XCTAssertFalse(source.contains("PermissionManager"))
    }

    func testMainContentRoutesHomeToTheWorkspaceDashboard() throws {
        let source = try readSource("App/ContentView.swift")
        XCTAssertTrue(source.contains("case .home:"))
        XCTAssertTrue(source.contains("WorkspaceHomeView(systemStatusService: serviceContainer.systemStatusService)"))
        XCTAssertTrue(source.contains("case .systemStatus:"))
        XCTAssertTrue(source.contains("SystemStatusView(systemStatusService: serviceContainer.systemStatusService)"))
    }

    func testWorkspaceHomeViewDoesNotUseSystemStatusSingleton() throws {
        let source = try readSource("Features/Native/Home/WorkspaceHomeView.swift")
        XCTAssertFalse(source.contains("SystemStatusViewModel(service: .shared)"))
        XCTAssertTrue(source.contains("systemStatusService"))
        XCTAssertTrue(source.contains("SystemStatusLabelFormatter"))
        XCTAssertTrue(source.contains("availabilityState"))
        XCTAssertTrue(source.contains("healthState"))
    }

    func testWorkspaceHomeViewUsesWorkspaceLanguageInsteadOfStatusLanguage() throws {
        let source = try readSource("Features/Native/Home/WorkspaceHomeView.swift")
        XCTAssertTrue(source.contains("工作台总览"))
        XCTAssertTrue(source.contains("运行概览"))
        XCTAssertTrue(source.contains("运行提醒"))
        XCTAssertTrue(source.contains("工作台摘要"))
        XCTAssertTrue(source.contains("资源"))
        XCTAssertTrue(source.contains("连接与权限"))
        XCTAssertTrue(source.contains("温度状态"))
        XCTAssertFalse(source.contains("本机状态总览"))
        XCTAssertFalse(source.contains("系统状态总览"))
        XCTAssertFalse(source.contains("状态指示"))
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
        XCTAssertTrue(source.contains("systemStatusService: SystemStatusService"))
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

    func testMusicServiceDoesNotAutoPromptAccessibilityPermission() throws {
        let source = try readSource("Features/Companion/MusicService.swift")

        XCTAssertFalse(source.contains("\"AXTrustedCheckOptionPrompt\": true"))
        XCTAssertTrue(source.contains("AXIsProcessTrusted()"))
        XCTAssertTrue(source.contains("didLogMissingAccessibilityThisLaunch"))
        XCTAssertTrue(source.contains("falling back to OCR"))
    }

    func testDynamicContinentTemplateScrollsItsContentArea() throws {
        let source = try readSource("Features/Companion/DynamicContinent/DynamicContinentTemplateV2.swift")
        XCTAssertTrue(source.contains("ScrollView(.vertical, showsIndicators: false)"))
        XCTAssertTrue(source.contains("GeometryReader"))
        XCTAssertTrue(source.contains("height: safeContentHeight"))
        XCTAssertTrue(source.contains("safeContentHeight"))
        XCTAssertTrue(source.contains("NotchV2LightStatusStrip"))
    }

    func testDynamicContinentFooterHasEnoughReservedHeight() throws {
        let tokenSource = try readSource("Features/Companion/NotchV2DesignTokens.swift")
        let templateSource = try readSource("Features/Companion/DynamicContinent/DynamicContinentTemplateV2.swift")

        XCTAssertTrue(tokenSource.contains("static let dashboardFooterHeight: CGFloat = 28"))
        XCTAssertFalse(templateSource.contains(".padding(.vertical, 6)\n                .frame(height: NotchV2DesignTokens.dashboardFooterHeight)"))
    }

    func testExpandedHeightMatchesDesignLayoutBudget() throws {
        let designSource = try readSource("Design/AcMindDesignTokens.swift")
        let layoutSource = try readSource("AcMindKit/Services/UI/CompanionLayout.swift")

        XCTAssertTrue(designSource.contains("static let expandedOverviewHeight: CGFloat = 300"))
        XCTAssertTrue(designSource.contains("static let dashboardFooterHeight: CGFloat = 28"))
        XCTAssertTrue(layoutSource.contains("public static let expandedHeight: CGFloat = 300"))
    }

    func testNotchPanelPositionsExpandedFrameUsingCurrentPageHeight() throws {
        let source = try readSource("Features/Companion/NotchPanel.swift")
        XCTAssertTrue(source.contains("CompanionScreenPositioning.expandedFrame(on: screenFrame, height: viewModel.expandedHeight)"))
    }

    func testAgentPageRightColumnIsMoreCompact() throws {
        let source = try readSource("Features/Companion/NotchV2AgentPage.swift")
        XCTAssertTrue(source.contains("leftColumnWidth: 136"))
        XCTAssertTrue(source.contains("fillHeight: true"))
        XCTAssertTrue(source.contains("suffix(3)"))
        XCTAssertFalse(source.contains("LazyVGrid"))
    }

    func testAgentPageCenterCardUsesRemainingHeight() throws {
        let source = try readSource("Features/Companion/NotchV2AgentPage.swift")
        XCTAssertTrue(source.contains("fillHeight: true"))
        XCTAssertTrue(source.contains("Spacer(minLength: 0)"))
        XCTAssertTrue(source.contains("suffix(3)"))
    }

    func testOverviewPageMovesStatusActionIntoSystemQuickView() throws {
        let source = try readSource("Features/Companion/NotchV2OverviewPage.swift")
        XCTAssertFalse(source.contains("title: \"状态入口\""))
        XCTAssertTrue(source.contains("进入状态页"))
        XCTAssertTrue(source.contains("title: \"系统快览\""))
        XCTAssertFalse(source.contains("音乐常驻"))
        XCTAssertEqual(source.components(separatedBy: "GridItem(.flexible(), spacing: 8)").count - 1, 6)
        XCTAssertEqual(source.components(separatedBy: "fillHeight: true").count - 1, 3)
        XCTAssertFalse(source.contains("fillHeight: false"))
    }

    func testMusicPageRightControlCardUsesFillHeight() throws {
        let source = try readSource("Features/Companion/NotchV2MusicPage.swift")
        XCTAssertTrue(source.contains("controlCard"))
        XCTAssertTrue(source.contains("fillHeight: true"))
        XCTAssertTrue(source.contains("viewModel.musicService.openMusicApp()"))
        XCTAssertTrue(source.contains("播放控制"))
    }

    func testSystemStatusViewUsesFillHeightCardsForDenseSections() throws {
        let source = try readSource("Features/Native/SystemStatus/SystemStatusView.swift")
        XCTAssertTrue(source.contains("fillHeight: true"))
        XCTAssertTrue(source.contains(".frame(maxHeight: .infinity, alignment: .topLeading)"))
    }

    func testDashboardLayoutLetsColumnsStretchVertically() throws {
        let source = try readSource("Features/Companion/NotchV2DashboardLayout.swift")
        XCTAssertTrue(source.contains("frame(maxHeight: .infinity, alignment: .topLeading)"))
    }

    func testSystemStatusPageUsesSixCoreTilesAndNarrowRails() throws {
        let source = try readSource("Features/Companion/DynamicContinent/DynamicContinentPages.swift")
        XCTAssertTrue(source.contains("leftColumnWidth: 176"))
        XCTAssertTrue(source.contains("rightColumnWidth: 176"))
        XCTAssertTrue(source.contains("电池电量"))
        XCTAssertTrue(source.contains("网速（上传下载量）"))
        XCTAssertTrue(source.contains("当前设备温度"))
        XCTAssertTrue(source.contains("当前设备风扇转速"))
        XCTAssertTrue(source.contains("CPU 负载率"))
        XCTAssertTrue(source.contains("内存负载率"))
        XCTAssertTrue(source.contains("NotchV2SegmentedPill"))
    }

    func testTopBarStatusButtonPrefersSystemStatusPage() throws {
        let source = try readSource("Features/Companion/NotchV2TopBar.swift")
        XCTAssertTrue(source.contains("viewModel.openSystemStatusPage()"))
        XCTAssertTrue(source.contains("isSelected: viewModel.effectiveSelectedPage == .systemStatus"))
    }

    func testStatusPillSupportsSelectedFeedback() throws {
        let source = try readSource("Features/Companion/NotchV2Card.swift")
        XCTAssertTrue(source.contains("let isSelected: Bool"))
        XCTAssertTrue(source.contains("isSelected ? accent.opacity(1.0)"))
        XCTAssertTrue(source.contains("scaleEffect(isSelected ? 1.02 : 1.0)"))
    }

    func testCollapsedMusicLayoutUsesWidthBasedFallbacks() throws {
        let source = try readSource("Features/Companion/NotchV2CollapsedView.swift")
        XCTAssertTrue(source.contains("ViewThatFits(in: .horizontal)"))
        XCTAssertTrue(source.contains("musicCollapsedRichLayout"))
        XCTAssertTrue(source.contains("musicCollapsedCompactLayout"))
        XCTAssertTrue(source.contains("musicCollapsedTinyLayout"))
    }

    func testLightStatusStripUsesStrongerHighlightedFeedback() throws {
        let source = try readSource("Features/Companion/NotchV2StatusStrip.swift")
        XCTAssertTrue(source.contains("scaleEffect(item.highlighted ? 1.02 : 1.0)"))
        XCTAssertTrue(source.contains("cornerRadius: 11"))
        XCTAssertTrue(source.contains(".padding(.vertical, 2)"))
        XCTAssertTrue(source.contains("font(.system(size: 8, weight: .medium, design: .rounded))"))
        XCTAssertTrue(source.contains("highlighted: playbackState.isPlaying || playbackState.title.isEmpty == false"))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
