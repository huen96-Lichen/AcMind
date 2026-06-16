import AppKit
import CoreGraphics
import XCTest
@testable import AcMindKit

final class ClipboardPinLayoutTests: XCTestCase {
    func testClipboardCardPresentationUsesThumbnailFirstRules() {
        let imageItem = ClipboardItem(
            type: .image,
            content: "asset-id",
            textContent: "图片说明",
            sourceApp: "Safari"
        )
        let textItem = ClipboardItem(
            type: .text,
            content: nil,
            textContent: "这是一段很长的文本内容，用来验证两行预览规则是否生效。",
            sourceApp: "Notes"
        )

        XCTAssertEqual(ClipboardCardPresentation.thumbnailHeight(for: imageItem), ContentCardPresentation.thumbnailHeight)
        XCTAssertEqual(ClipboardCardPresentation.previewLineLimit(for: imageItem), 1)
        XCTAssertEqual(ClipboardCardPresentation.previewLineLimit(for: textItem), 2)
        XCTAssertEqual(ClipboardCardPresentation.previewText(for: imageItem), "图片说明")
        XCTAssertEqual(ClipboardCardPresentation.previewText(for: textItem), "这是一段很长的文本内容，用来验证两行预览规则是否生效。")
        XCTAssertEqual(ClipboardCardPresentation.subtitleText(for: imageItem), "Safari · 图片")
        XCTAssertEqual(ClipboardCardPresentation.subtitleText(for: textItem), "Notes · 文本")
    }

    func testMaterialCardMetadataUsesSharedSubtitleRules() {
        let createdAt = Date(timeIntervalSince1970: 1_780_000_000)
        let clipboardItem = ClipboardItem(
            type: .text,
            content: nil,
            textContent: "复制内容",
            sourceApp: "Safari",
            createdAt: createdAt
        )

        let clipboardMetadata = MaterialCardMetadataFactory.clipboard(item: clipboardItem)
        let sourceMetadata = MaterialCardMetadataFactory.source(
            title: nil,
            kind: "图片",
            source: nil,
            timestamp: createdAt
        )

        XCTAssertEqual(clipboardMetadata.title, "复制内容")
        XCTAssertEqual(clipboardMetadata.subtitle, "Safari · 文本")
        XCTAssertEqual(sourceMetadata.title, "未命名")
        XCTAssertEqual(sourceMetadata.subtitle, "未知来源 · 图片")
    }

    func testClipboardPinStateIsReflectedInTheBadgeAndActionSurface() {
        XCTAssertEqual(ClipboardCardPresentation.pinFeedbackTitle(isPinned: true), "已固定")
        XCTAssertEqual(ClipboardCardPresentation.pinFeedbackTitle(isPinned: false), "Pin")
    }

    func testPinWindowPresentationUsesMenuPlusLevelAndNonActivatingPanel() {
        XCTAssertTrue(ClipboardPinWindowPresentation.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(ClipboardPinWindowPresentation.styleMask.contains(.borderless))
        XCTAssertTrue(ClipboardPinWindowPresentation.styleMask.contains(.hudWindow))
        XCTAssertTrue(ClipboardPinWindowPresentation.styleMask.contains(.fullSizeContentView))
        XCTAssertEqual(ClipboardPinWindowPresentation.alwaysOnTopLevel, .screenSaver)
        XCTAssertGreaterThan(ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue, NSWindow.Level.mainMenu.rawValue)
        XCTAssertGreaterThan(ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue, NSWindow.Level.floating.rawValue)
        XCTAssertEqual(ClipboardPinWindowPresentation.reassertionDelays.count, 3)
        XCTAssertLessThanOrEqual(ClipboardPinWindowPresentation.reassertionDelays.first ?? 1, 0.10)
        XCTAssertLessThanOrEqual(ClipboardPinWindowPresentation.reassertionDelays.last ?? 10, 1.0)
        XCTAssertTrue(ClipboardPinWindowPresentation.collectionBehavior(isAlwaysOnTop: true).contains(.canJoinAllSpaces))
        XCTAssertTrue(ClipboardPinWindowPresentation.collectionBehavior(isAlwaysOnTop: true).contains(.stationary))
        XCTAssertFalse(ClipboardPinWindowPresentation.collectionBehavior(isAlwaysOnTop: true).contains(.moveToActiveSpace))
        XCTAssertEqual(
            ClipboardPinWindowPresentation.collectionBehavior(isAlwaysOnTop: false),
            [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        )
    }

    func testMaterialCardsHaveEnoughVerticalBudgetForPreviewAndMetadata() {
        let fixedChrome = ContentCardPresentation.innerPadding * 2
            + ContentCardPresentation.headerMinHeight
            + ContentCardPresentation.cardSpacing
            + ContentCardPresentation.cardSpacing
            + ContentCardPresentation.materialMetadataMinHeight

        XCTAssertGreaterThanOrEqual(
            ContentCardPresentation.cardMinHeight,
            fixedChrome + ContentCardPresentation.thumbnailHeight
        )
        XCTAssertGreaterThanOrEqual(
            ContentCardPresentation.cardMinHeight,
            fixedChrome + ContentCardPresentation.textPreviewHeight
        )
        XCTAssertEqual(ContentCardPresentation.cardMinHeight, ContentCardPresentation.imageCardMinHeight)
    }

    func testMaterialCardMetadataBudgetMatchesSharedClipboardAndInboxCards() {
        XCTAssertEqual(ContentCardPresentation.materialMetadataMinHeight, ContentCardPresentation.metadataHeight * 2)
        XCTAssertGreaterThanOrEqual(ContentCardPresentation.materialMetadataMinHeight, 44)
        XCTAssertEqual(
            ContentCardPresentation.cardHeight(for: SourceType.image, text: "任意"),
            ContentCardPresentation.cardMinHeight
        )
        XCTAssertEqual(
            ContentCardPresentation.cardHeight(for: SourceType.text, text: "短文本"),
            ContentCardPresentation.cardMinHeight
        )
    }

    func testMaterialGridDropsToOneColumnBeforeOverflowing() {
        XCTAssertEqual(
            MaterialCardGridLayout.columnCount(availableWidth: 560, minimumColumnWidth: 320),
            1
        )
        XCTAssertEqual(
            MaterialCardGridLayout.columnCount(availableWidth: 720, minimumColumnWidth: 320),
            2
        )
        XCTAssertEqual(
            MaterialCardGridLayout.columnCount(availableWidth: 1280, minimumColumnWidth: 320),
            3
        )
        XCTAssertEqual(
            MaterialCardGridLayout.columnCount(availableWidth: 720, minimumColumnWidth: 240),
            2,
            "Inbox detail width at the 1180 pt window breakpoint must retain two columns"
        )
    }

    func testMaterialGridColumnMinimumFitsNarrowContainers() {
        let columns = MaterialCardGridLayout.columns(availableWidth: 240, minimumColumnWidth: 320)
        let fittedMinimumWidth = MaterialCardGridLayout.columnMinimumWidth(
            availableWidth: 240,
            requestedMinimumColumnWidth: 320,
            columnCount: columns.count
        )

        XCTAssertEqual(columns.count, 1)
        XCTAssertLessThanOrEqual(fittedMinimumWidth, 224)
    }

    func testMaterialPreviewHeightsAreUnifiedForClipboardAndInboxDensity() {
        XCTAssertEqual(ContentCardPresentation.thumbnailHeight, ContentCardPresentation.textPreviewHeight)
        XCTAssertGreaterThanOrEqual(ContentCardPresentation.thumbnailHeight, 136)
        XCTAssertLessThanOrEqual(ContentCardPresentation.cardMinHeight - ContentCardPresentation.thumbnailHeight, 136)
    }

    func testMaterialPreviewHeightGrowsWithLongerTextWithoutBreakingImageDensity() {
        let shortTextHeight = ContentCardPresentation.previewHeight(for: SourceType.text, text: "短文本")
        let longTextHeight = ContentCardPresentation.previewHeight(for: SourceType.text, text: String(repeating: "这是更长的一段文本，用于验证预览高度会适度增长。", count: 6))

        XCTAssertGreaterThan(longTextHeight, shortTextHeight)
        XCTAssertLessThanOrEqual(longTextHeight, 188)
        XCTAssertEqual(ContentCardPresentation.previewHeight(for: SourceType.image, text: "任意"), ContentCardPresentation.thumbnailHeight)
    }

    func testMaterialCardHeightGrowsWithLongerPreviewWithoutShrinkingImageCards() {
        let shortHeight = ContentCardPresentation.cardHeight(for: SourceType.text, text: "短文本")
        let longHeight = ContentCardPresentation.cardHeight(for: SourceType.text, text: String(repeating: "这是更长的一段文本，用于验证卡片高度会适度增长。", count: 6))

        XCTAssertGreaterThanOrEqual(shortHeight, ContentCardPresentation.cardMinHeight)
        XCTAssertGreaterThan(longHeight, shortHeight)
        XCTAssertEqual(
            ContentCardPresentation.cardHeight(for: SourceType.image, text: "任意"),
            ContentCardPresentation.cardMinHeight
        )
    }

    func testPinWindowSnapshotReportsExpectedAlwaysOnTopLevel() {
        let displayFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let pinned = ClipboardPinWindowSnapshot(
            itemId: "item-1",
            isVisible: true,
            isAlwaysOnTop: true,
            levelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            expectedAlwaysOnTopLevelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            frame: CGRect(x: 100, y: 100, width: 320, height: 240),
            screenFrame: displayFrame,
            displayFrame: displayFrame
        )
        let notPinned = ClipboardPinWindowSnapshot(
            itemId: "item-2",
            isVisible: true,
            isAlwaysOnTop: true,
            levelRawValue: ClipboardPinWindowPresentation.fallbackLevel.rawValue,
            expectedAlwaysOnTopLevelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            frame: CGRect(x: 100, y: 100, width: 320, height: 240),
            screenFrame: displayFrame,
            displayFrame: displayFrame
        )

        XCTAssertTrue(pinned.isAtExpectedAlwaysOnTopLevel)
        XCTAssertFalse(notPinned.isAtExpectedAlwaysOnTopLevel)
    }

    func testPinWindowSnapshotDiagnosticReasonExplainsWhyAWindowIsNotStable() {
        let displayFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

        let hidden = ClipboardPinWindowSnapshot(
            itemId: "hidden",
            isVisible: false,
            isAlwaysOnTop: true,
            levelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            expectedAlwaysOnTopLevelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            frame: CGRect(x: 100, y: 100, width: 320, height: 240),
            screenFrame: displayFrame,
            displayFrame: displayFrame
        )
        let demoted = ClipboardPinWindowSnapshot(
            itemId: "demoted",
            isVisible: true,
            isAlwaysOnTop: true,
            levelRawValue: ClipboardPinWindowPresentation.fallbackLevel.rawValue,
            expectedAlwaysOnTopLevelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            frame: CGRect(x: 100, y: 100, width: 320, height: 240),
            screenFrame: displayFrame,
            displayFrame: displayFrame
        )
        let detached = ClipboardPinWindowSnapshot(
            itemId: "detached",
            isVisible: true,
            isAlwaysOnTop: true,
            levelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            expectedAlwaysOnTopLevelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            frame: CGRect(x: 100, y: 100, width: 320, height: 240),
            screenFrame: nil,
            displayFrame: displayFrame
        )
        let healthy = ClipboardPinWindowSnapshot(
            itemId: "healthy",
            isVisible: true,
            isAlwaysOnTop: true,
            levelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            expectedAlwaysOnTopLevelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            frame: CGRect(x: 100, y: 100, width: 320, height: 240),
            screenFrame: displayFrame,
            displayFrame: displayFrame
        )

        XCTAssertEqual(hidden.diagnosticReason, "hidden")
        XCTAssertEqual(demoted.diagnosticReason, "level mismatch")
        XCTAssertEqual(detached.diagnosticReason, "missing screen frame")
        XCTAssertEqual(healthy.diagnosticReason, "ok")
    }

    func testClipboardPinDiagnosticsReportMarksMismatchedWindowsAndSummarizesCounts() {
        let displayFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let snapshots = [
            ClipboardPinWindowSnapshot(
                itemId: "item-1",
                isVisible: true,
                isAlwaysOnTop: true,
                levelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
                expectedAlwaysOnTopLevelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
                frame: CGRect(x: 100, y: 100, width: 320, height: 240),
                screenFrame: displayFrame,
                displayFrame: displayFrame
            ),
            ClipboardPinWindowSnapshot(
                itemId: "item-2",
                isVisible: true,
                isAlwaysOnTop: true,
                levelRawValue: ClipboardPinWindowPresentation.fallbackLevel.rawValue,
                expectedAlwaysOnTopLevelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
                frame: CGRect(x: 200, y: 120, width: 320, height: 240),
                screenFrame: displayFrame,
                displayFrame: displayFrame
            )
        ]

        let report = ClipboardPinWindowManager.diagnosticsReport(
            from: snapshots,
            generatedAt: Date(timeIntervalSince1970: 1_780_000_000)
        )

        XCTAssertTrue(report.contains("Window Count: 2"))
        XCTAssertTrue(report.contains("Visible Count: 2"))
        XCTAssertTrue(report.contains("Always-On-Top Count: 2"))
        XCTAssertTrue(report.contains("At Expected Level: 1"))
        XCTAssertTrue(report.contains("Keep-Alive Eligible Count: 2"))
        XCTAssertTrue(report.contains("Keep-Alive Active: true"))
        XCTAssertTrue(report.contains("Unstable Window Count: 1"))
        XCTAssertTrue(report.contains("Reason Summary: level mismatch=1, ok=1"))
        XCTAssertTrue(report.contains("reason=level mismatch"))
        XCTAssertTrue(report.contains("reason=ok"))
        XCTAssertTrue(report.contains("item=item-2"))
        XCTAssertTrue(report.contains("status=mismatch"))
        XCTAssertTrue(report.contains("matchesExpected=false"))
        XCTAssertLessThan(report.range(of: "item=item-2")!.lowerBound, report.range(of: "item=item-1")!.lowerBound)
    }

    func testClipboardPinDiagnosticsReportHandlesEmptyStateCleanly() {
        let report = ClipboardPinWindowManager.diagnosticsReport(
            from: [],
            generatedAt: Date(timeIntervalSince1970: 1_780_000_000)
        )

        XCTAssertTrue(report.contains("Window Count: 0"))
        XCTAssertTrue(report.contains("Visible Count: 0"))
        XCTAssertTrue(report.contains("No open pin windows."))
    }

    func testClipboardPinKeepAliveOnlyDependsOnVisibleAlwaysOnTopWindows() {
        let displayFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visiblePinned = ClipboardPinWindowSnapshot(
            itemId: "item-visible",
            isVisible: true,
            isAlwaysOnTop: true,
            levelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            expectedAlwaysOnTopLevelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            frame: CGRect(x: 120, y: 120, width: 320, height: 240),
            screenFrame: displayFrame,
            displayFrame: displayFrame
        )
        let hiddenPinned = ClipboardPinWindowSnapshot(
            itemId: "item-hidden",
            isVisible: false,
            isAlwaysOnTop: true,
            levelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            expectedAlwaysOnTopLevelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            frame: CGRect(x: 160, y: 160, width: 320, height: 240),
            screenFrame: displayFrame,
            displayFrame: displayFrame
        )
        let visibleUnpinned = ClipboardPinWindowSnapshot(
            itemId: "item-unpinned",
            isVisible: true,
            isAlwaysOnTop: false,
            levelRawValue: ClipboardPinWindowPresentation.fallbackLevel.rawValue,
            expectedAlwaysOnTopLevelRawValue: ClipboardPinWindowPresentation.alwaysOnTopLevel.rawValue,
            frame: CGRect(x: 200, y: 200, width: 320, height: 240),
            screenFrame: displayFrame,
            displayFrame: displayFrame
        )

        XCTAssertTrue(ClipboardPinWindowManager.shouldKeepAlive(using: [visiblePinned]))
        XCTAssertFalse(ClipboardPinWindowManager.shouldKeepAlive(using: [hiddenPinned]))
        XCTAssertFalse(ClipboardPinWindowManager.shouldKeepAlive(using: [visibleUnpinned]))
        XCTAssertTrue(ClipboardPinWindowManager.shouldKeepAlive(using: [hiddenPinned, visiblePinned, visibleUnpinned]))
    }

    @MainActor
    func testClipboardPinManagerKeepsNewWindowRegisteredAfterShow() {
        let manager = ClipboardPinWindowManager(assetStore: AssetStore())
        let item = ClipboardItem(
            type: .text,
            content: nil,
            textContent: "pin test",
            sourceApp: "Notes"
        )

        manager.show(item: item)

        XCTAssertEqual(manager.openWindowCount, 1)
        XCTAssertEqual(manager.windowSnapshots.count, 1)
        XCTAssertTrue(manager.windowSnapshots.first?.isVisible == true)
        XCTAssertTrue(manager.windowSnapshots.first?.isAlwaysOnTop == true)

        manager.closeAll()
    }

    @MainActor
    func testClipboardPinViewModelResizeUpdatesPreferredWindowSizeWithinBounds() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let item = ClipboardItem(
            type: .text,
            content: nil,
            textContent: "pin resize verification text",
            sourceApp: "Notes"
        )
        let viewModel = ClipboardPinWindowViewModel(
            item: item,
            assetStore: AssetStore(),
            displayFrame: display
        )
        let original = viewModel.preferredWindowSize

        viewModel.resize(by: CGSize(width: 140, height: 120))

        XCTAssertGreaterThan(viewModel.preferredWindowSize.width, original.width)
        XCTAssertGreaterThan(viewModel.preferredWindowSize.height, original.height)
        XCTAssertLessThanOrEqual(viewModel.preferredWindowSize.width, ClipboardPinWindowSizing.manualResizeMaxTextWindowWidth)
        XCTAssertLessThanOrEqual(viewModel.preferredWindowSize.height, ClipboardPinWindowSizing.manualResizeMaxWindowHeight)
    }

    @MainActor
    func testClipboardPinViewModelResizeUsesUpdatedDisplayFrameBounds() {
        let initialDisplay = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        let smallerDisplay = CGRect(x: 0, y: 0, width: 900, height: 700)
        let item = ClipboardItem(
            type: .text,
            content: nil,
            textContent: "pin resize verification text",
            sourceApp: "Notes"
        )
        let viewModel = ClipboardPinWindowViewModel(
            item: item,
            assetStore: AssetStore(),
            displayFrame: initialDisplay
        )

        viewModel.updateDisplayFrame(smallerDisplay)
        viewModel.resize(by: CGSize(width: 400, height: 400))

        XCTAssertLessThanOrEqual(viewModel.preferredWindowSize.width, smallerDisplay.width * 0.58)
        XCTAssertLessThanOrEqual(viewModel.preferredWindowSize.height, ClipboardPinWindowSizing.manualResizeMaxWindowHeight)
    }

    func testTextWindowHeightGrowsWithLongerTextAndRespectsMaximum() {
        let shortText = "短文本"
        let longText = String(repeating: "这是一段用于测试悬浮窗高度的较长文本。", count: 80)

        let shortHeight = ClipboardPinWindowSizing.textContentHeight(for: shortText, contentWidth: 640)
        let longHeight = ClipboardPinWindowSizing.textContentHeight(for: longText, contentWidth: 640)

        XCTAssertGreaterThan(longHeight, shortHeight)
        XCTAssertLessThanOrEqual(longHeight, ClipboardPinWindowSizing.maxContentHeight)
    }

    func testTextWindowWidthTracksContentInsteadOfAlwaysExpanding() {
        let display = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        let shortText = "短文本"
        let longText = "Adobe After Effects 9.0 Keyframe Data\nUnits Per Second 50\nSource Width 1\nSource Height 1"

        let shortWidth = ClipboardPinWindowSizing.textWindowWidth(for: shortText, displayFrame: display)
        let longWidth = ClipboardPinWindowSizing.textWindowWidth(for: longText, displayFrame: display)

        XCTAssertEqual(shortWidth, ClipboardPinWindowSizing.minimumWindowWidth)
        XCTAssertGreaterThan(longWidth, shortWidth)
        XCTAssertLessThanOrEqual(longWidth, ClipboardPinWindowSizing.maxTextWindowWidth)
    }

    func testImageWindowSizeFitsDisplayAndPreservesAspectRatio() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let imageSize = CGSize(width: 2400, height: 900)

        let size = ClipboardPinWindowSizing.imageWindowSize(for: imageSize, displayFrame: display)

        XCTAssertLessThanOrEqual(size.width, ClipboardPinWindowSizing.maxWindowWidth)
        XCTAssertLessThanOrEqual(size.height, ClipboardPinWindowSizing.maxContentHeight + ClipboardPinWindowSizing.chromeHeight)
        XCTAssertGreaterThan(size.width, size.height)
        XCTAssertEqual(size.width / size.height, imageSize.width / imageSize.height, accuracy: 0.6)
    }

    func testImageZoomWindowSizeIsLargerThanBaseImageWindowSize() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let imageSize = CGSize(width: 1280, height: 960)

        let baseSize = ClipboardPinWindowSizing.imageWindowSize(for: imageSize, displayFrame: display)
        let zoomSize = ClipboardPinWindowSizing.imageZoomWindowSize(for: imageSize, displayFrame: display)

        XCTAssertGreaterThanOrEqual(zoomSize.width, baseSize.width)
        XCTAssertGreaterThanOrEqual(zoomSize.height, baseSize.height)
        XCTAssertLessThanOrEqual(zoomSize.width, display.width * 0.72)
        XCTAssertLessThanOrEqual(zoomSize.height, display.height * 0.78)
    }

    func testClipboardPinManualResizeWindowSizeKeepsTextWindowsWithinDisplayBounds() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let oversized = CGSize(width: 999, height: 999)

        let clamped = ClipboardPinWindowSizing.manualResizeWindowSize(
            oversized,
            itemType: .text,
            displayFrame: display
        )

        XCTAssertGreaterThanOrEqual(clamped.width, ClipboardPinWindowSizing.minimumWindowWidth)
        XCTAssertGreaterThanOrEqual(clamped.height, ClipboardPinWindowSizing.minimumWindowHeight)
        XCTAssertLessThanOrEqual(clamped.width, ClipboardPinWindowSizing.manualResizeMaxTextWindowWidth)
        XCTAssertLessThanOrEqual(clamped.height, ClipboardPinWindowSizing.manualResizeMaxWindowHeight)
    }

    func testClipboardPinManualResizeWindowSizeCanExceedOldZoomLimit() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let imageSize = CGSize(width: 1280, height: 960)
        let zoom = ClipboardPinWindowSizing.imageZoomWindowSize(for: imageSize, displayFrame: display)

        let clamped = ClipboardPinWindowSizing.manualResizeWindowSize(
            CGSize(width: zoom.width + 120, height: zoom.height + 120),
            itemType: .image,
            displayFrame: display,
            imageSize: imageSize
        )

        XCTAssertGreaterThanOrEqual(clamped.width, zoom.width)
        XCTAssertGreaterThanOrEqual(clamped.height, zoom.height)
        XCTAssertLessThanOrEqual(clamped.width, ClipboardPinWindowSizing.manualResizeMaxWindowWidth)
        XCTAssertLessThanOrEqual(clamped.height, ClipboardPinWindowSizing.manualResizeMaxWindowHeight)
    }

    func testClipboardPinExpandedPresetWindowSizeIsLargerThanBaseForText() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let base = ClipboardPinWindowSizing.textWindowSize(for: "这是一段用于测试的文本内容。", displayFrame: display)
        let expanded = ClipboardPinWindowSizing.expandedPresetWindowSize(
            for: .text,
            displayFrame: display
        )

        XCTAssertGreaterThanOrEqual(expanded.width, base.width)
        XCTAssertGreaterThanOrEqual(expanded.height, base.height)
    }

    @MainActor
    func testClipboardPinViewModelToggleExpandedSizeRestoresPreviousManualSize() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let item = ClipboardItem(
            type: .text,
            content: nil,
            textContent: "pin resize verification text",
            sourceApp: "Notes"
        )
        let viewModel = ClipboardPinWindowViewModel(
            item: item,
            assetStore: AssetStore(),
            displayFrame: display
        )
        let original = viewModel.preferredWindowSize

        viewModel.toggleExpandedSize()
        let expanded = viewModel.preferredWindowSize
        viewModel.toggleExpandedSize()

        XCTAssertGreaterThanOrEqual(expanded.width, original.width)
        XCTAssertGreaterThanOrEqual(expanded.height, original.height)
        XCTAssertEqual(viewModel.preferredWindowSize.width, original.width, accuracy: 2)
        XCTAssertEqual(viewModel.preferredWindowSize.height, original.height, accuracy: 2)
    }

    func testClipboardCardPresentationPreviewRulesStayAlignedAcrossKinds() {
        let imageItem = ClipboardItem(type: .image, content: "asset-id", textContent: "截图说明", sourceApp: "Safari")
        let fileItem = ClipboardItem(type: .file, content: "/tmp/a.txt", textContent: "路径 A\n路径 B", sourceApp: "Files")
        let urlItem = ClipboardItem(type: .url, content: "https://openai.com", textContent: nil, sourceApp: "Safari")

        XCTAssertEqual(ClipboardCardPresentation.previewLineLimit(for: imageItem), 1)
        XCTAssertEqual(ClipboardCardPresentation.previewLineLimit(for: fileItem), 2)
        XCTAssertEqual(ClipboardCardPresentation.previewLineLimit(for: urlItem), 2)
        XCTAssertEqual(ClipboardCardPresentation.previewText(for: urlItem), "https://openai.com")
    }

    @MainActor
    func testClipboardPinStructuredTextParserCompactsProfileCardContent() {
        let input = """
        小张师傅
        00后 入行1年 租车
        工作机：Redmi K30 Pro/小米14
        日均时长：10小时
        月均收入：9-10K
        """

        let parsed = ClipboardPinWindowViewModel.parseStructuredTextContent(from: input)

        XCTAssertEqual(parsed?.title, "小张师傅")
        XCTAssertEqual(parsed?.metaLine, "00后 · 入行1年 · 租车")
        XCTAssertEqual(
            parsed?.detailRows,
            [
                .init(label: "工作机", value: "Redmi K30 Pro / 小米14"),
                .init(label: "时长", value: "10小时 / 日"),
                .init(label: "收入", value: "9–10K / 月")
            ]
        )
    }

    @MainActor
    func testClipboardPinStructuredTextParserIgnoresPlainParagraphs() {
        let input = "这是一段普通文本，没有明确字段，只需要保留为正文展示。"

        XCTAssertNil(ClipboardPinWindowViewModel.parseStructuredTextContent(from: input))
    }

    @MainActor
    func testClipboardPinStructuredTextInitialSizeProvidesMoreVerticalBudget() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let structuredText = """
        小张师傅
        00后 入行1年 租车
        工作机：Redmi K30 Pro/小米14
        日均时长：10小时
        月均收入：9-10K
        """
        let plainText = "短文本"

        let structuredViewModel = ClipboardPinWindowViewModel(
            item: ClipboardItem(type: .text, content: nil, textContent: structuredText, sourceApp: "Notes"),
            assetStore: AssetStore(),
            displayFrame: display
        )
        let plainViewModel = ClipboardPinWindowViewModel(
            item: ClipboardItem(type: .text, content: nil, textContent: plainText, sourceApp: "Notes"),
            assetStore: AssetStore(),
            displayFrame: display
        )

        XCTAssertGreaterThan(structuredViewModel.preferredWindowSize.height, plainViewModel.preferredWindowSize.height)
        XCTAssertGreaterThanOrEqual(structuredViewModel.preferredWindowSize.width, 360)
    }
}

final class CompanionPresentationStateTests: XCTestCase {
    func testTransitionPhasesExposeTargetVisibilityAndAnimationDuration() {
        XCTAssertFalse(CompanionPresentationState.hidden.isExpandedVisual)
        XCTAssertFalse(CompanionPresentationState.compact.isExpandedVisual)
        XCTAssertTrue(CompanionPresentationState.expanding.isExpandedVisual)
        XCTAssertTrue(CompanionPresentationState.expanded.isExpandedVisual)
        XCTAssertTrue(CompanionPresentationState.blockedClose.isExpandedVisual)
        XCTAssertFalse(CompanionPresentationState.collapsing.isExpandedVisual)
        XCTAssertFalse(CompanionPresentationState.transientHUD.isExpandedVisual)
        XCTAssertFalse(CompanionPresentationState.hidden.targetFrameIsExpanded)
        XCTAssertTrue(CompanionPresentationState.expanding.targetFrameIsExpanded)

        XCTAssertEqual(CompanionPresentationState.expanding.targetFrameIsExpanded, true)
        XCTAssertEqual(CompanionPresentationState.collapsing.targetFrameIsExpanded, false)
        XCTAssertEqual(CompanionPresentationState.expanded.animationDuration, CompanionPresentationState.expanding.animationDuration)
    }
}
