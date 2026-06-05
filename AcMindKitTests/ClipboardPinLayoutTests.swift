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
        XCTAssertTrue(ClipboardPinWindowPresentation.collectionBehavior(isAlwaysOnTop: true).contains(.moveToActiveSpace))
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

    func testClipboardCardPresentationPreviewRulesStayAlignedAcrossKinds() {
        let imageItem = ClipboardItem(type: .image, content: "asset-id", textContent: "截图说明", sourceApp: "Safari")
        let fileItem = ClipboardItem(type: .file, content: "/tmp/a.txt", textContent: "路径 A\n路径 B", sourceApp: "Files")
        let urlItem = ClipboardItem(type: .url, content: "https://openai.com", textContent: nil, sourceApp: "Safari")

        XCTAssertEqual(ClipboardCardPresentation.previewLineLimit(for: imageItem), 1)
        XCTAssertEqual(ClipboardCardPresentation.previewLineLimit(for: fileItem), 2)
        XCTAssertEqual(ClipboardCardPresentation.previewLineLimit(for: urlItem), 2)
        XCTAssertEqual(ClipboardCardPresentation.previewText(for: urlItem), "https://openai.com")
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
