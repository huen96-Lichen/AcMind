import XCTest

final class CompanionStatePolishTests: XCTestCase {
    func testOverviewRowsUseSharedActivityLabels() throws {
        let source = try readSource("Features/Companion/NotchV2ViewModel.swift")

        XCTAssertTrue(source.contains("ActivityStateLabelFormatter.activityLabel(isActive: isVoiceRecording"))
        XCTAssertTrue(source.contains("ActivityStateLabelFormatter.activityLabel(isActive: isCapturing"))
        XCTAssertTrue(source.contains("voiceDisplaySubtitle"))
    }

    func testStatusStripUsesSharedActivityLabels() throws {
        let source = try readSource("Features/Companion/NotchV2StatusStrip.swift")

        XCTAssertTrue(source.contains("detail: voiceDisplaySubtitle"))
        XCTAssertTrue(source.contains("ActivityStateLabelFormatter.activityLabel(isActive: isCapturing"))
    }

    func testRuntimeSurfaceUsesSharedActivityLabels() throws {
        let source = try readSource("Features/Companion/NotchRuntimeSurface.swift")

        XCTAssertTrue(source.contains("ActivityStateLabelFormatter.activityLabel"))
        XCTAssertTrue(source.contains("idleLabel: \"待命\""))
    }

    func testRuntimeIdleSurfaceUsesPolishedDefaultCopy() throws {
        let source = try readSource("Features/Companion/NotchRuntimeSurface.swift")

        XCTAssertTrue(source.contains("title: \"当前状态总览\""))
        XCTAssertTrue(source.contains("subtitle: \"当前状态总览\""))
        XCTAssertTrue(source.contains("activeLabel: \"执行中心已展开\""))
        XCTAssertTrue(source.contains("idleLabel: \"准备接收新的输入\""))
    }

    func testCompactVoiceSurfacesUseSharedVoiceLabels() throws {
        let topBarSource = try readSource("Features/Companion/NotchV2TopBar.swift")
        let collapsedViewSource = try readSource("Features/Companion/NotchV2CollapsedView.swift")
        let hudSource = try readSource("Features/Companion/SystemEventHUD.swift")
        let voicePanelSource = try readSource("Features/Companion/CompanionVoicePanel.swift")
        let viewModelSource = try readSource("Features/Companion/NotchV2ViewModel.swift")

        XCTAssertTrue(topBarSource.contains("ActivityStateLabelFormatter.voiceCompactLabel"))
        XCTAssertTrue(collapsedViewSource.contains("ActivityStateLabelFormatter.recordingSubtitleLabel"))
        XCTAssertTrue(hudSource.contains("SayInputPresentationLabelFormatter"))
        XCTAssertTrue(voicePanelSource.contains("SayInputPresentationLabelFormatter"))
        XCTAssertTrue(viewModelSource.contains("SayInputPresentationLabelFormatter"))
    }

    func testSystemEventHudShowsPendingQueueSummary() throws {
        let source = try readSource("Features/Companion/SystemEventHUD.swift")

        XCTAssertTrue(source.contains("pendingHUDKinds"))
        XCTAssertTrue(source.contains("排队中"))
        XCTAssertTrue(source.contains("pendingQueueText"))
    }

    func testCompanionViewModelUsesSharedFallbackLabelsForEmptyAIState() throws {
        let source = try readSource("Features/Companion/NotchV2ViewModel.swift")

        XCTAssertTrue(source.contains("SettingsStatusLabelFormatter.unconfiguredModelText"))
        XCTAssertTrue(source.contains("SettingsStatusLabelFormatter.unconfiguredProviderText"))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
