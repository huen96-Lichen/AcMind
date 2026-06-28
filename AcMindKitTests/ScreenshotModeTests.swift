import XCTest
@testable import AcMindKit

final class ScreenshotModeTests: XCTestCase {
    func testScrollModeRoundTrips() {
        XCTAssertEqual(ScreenshotMode(rawValue: "scroll"), .scroll)
        XCTAssertEqual(ScreenshotMode.scroll.displayName, "滚动")
    }

    func testScreenshotFileNameRulesUseModeSpecificPrefixes() {
        XCTAssertEqual(
            CaptureService.screenshotFileName(mode: .fullscreen, timestamp: "123456"),
            "screenshot_123456.png"
        )
        XCTAssertEqual(
            CaptureService.screenshotFileName(mode: .area, timestamp: "123456"),
            "screenshot_123456.png"
        )
        XCTAssertEqual(
            CaptureService.screenshotFileName(mode: .window, timestamp: "123456"),
            "screenshot_123456.png"
        )
        XCTAssertEqual(
            CaptureService.screenshotFileName(mode: .scroll, timestamp: "123456"),
            "scrollshot_123456.png"
        )
    }

    func testScreenshotTitleRulesUseModeSpecificLabels() {
        XCTAssertEqual(CaptureService.screenshotTitle(mode: .fullscreen, dateText: "2026-06-25"), "截图 2026-06-25")
        XCTAssertEqual(CaptureService.screenshotTitle(mode: .scroll, dateText: "2026-06-25"), "滚动截图 2026-06-25")
    }

    func testScreenshotModeMetadataKeyIsStable() {
        XCTAssertEqual(CaptureService.screenshotModeMetadataKey, "screenshotMode")
        XCTAssertEqual(CaptureService.screenshotPresetIDMetadataKey, "screenshotPresetID")
        XCTAssertEqual(CaptureService.screenshotPresetNameMetadataKey, "screenshotPresetName")
        XCTAssertEqual(CaptureService.screenshotPresetOutputActionMetadataKey, "screenshotPresetOutputAction")
    }

    func testScreenshotMetadataCapturesPresetIdentityAndOutputAction() {
        let preset = ScreenshotPreset(
            id: "copy-first",
            name: "复制优先",
            captureAutoRedactionEnabled: false,
            captureCensorModeRawValue: CensorMode.blur.rawValue,
            captureScreenshotCornerRadius: 4,
            captureScreenshotMaxWidth: 0,
            captureScreenshotMaxHeight: 0,
            defaultOutputAction: .copyToClipboard
        )

        let metadata = CaptureService.screenshotMetadata(mode: .window, preset: preset)

        XCTAssertEqual(metadata[CaptureService.screenshotModeMetadataKey], "window")
        XCTAssertEqual(metadata[CaptureService.screenshotPresetIDMetadataKey], "copy-first")
        XCTAssertEqual(metadata[CaptureService.screenshotPresetNameMetadataKey], "复制优先")
        XCTAssertEqual(metadata[CaptureService.screenshotPresetOutputActionMetadataKey], ScreenshotPresetOutputAction.copyToClipboard.rawValue)
    }

    func testCollectionSourceScreenshotMappingRemainsDistinct() {
        let source = CollectionSource(sourceOrigin: .screenshot, metadata: [:])

        XCTAssertEqual(source, .screenshot)
        XCTAssertEqual(CollectionSource.screenshot.displayName, "截图")
        XCTAssertEqual(CollectionSource.screenshotOCR.displayName, "截图 OCR")
    }

    func testBlankScreenshotPresetUsesNeutralDefaults() {
        let preset = ScreenshotPreset.blankPreset(id: "blank", name: "空白")

        XCTAssertEqual(preset.id, "blank")
        XCTAssertEqual(preset.name, "空白")
        XCTAssertFalse(preset.captureAutoRedactionEnabled)
        XCTAssertEqual(preset.captureCensorMode, .pixelate)
        XCTAssertEqual(preset.captureScreenshotCornerRadius, 0)
        XCTAssertEqual(preset.captureScreenshotMaxWidth, 0)
        XCTAssertEqual(preset.captureScreenshotMaxHeight, 0)
        XCTAssertEqual(preset.defaultOutputAction, .saveToInbox)
    }
}
