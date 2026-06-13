import AppKit
import XCTest
@testable import AcMindKit

final class ScreenshotProcessingTests: XCTestCase {
    func testScreenshotPostProcessorResizesAndRoundsCorners() async {
        let image = makeSolidImage(width: 10, height: 10, color: .systemRed)

        let result = await ScreenshotImagePostProcessor.process(
            image,
            options: ScreenshotPostProcessingOptions(
                cornerRadius: 3,
                maxWidth: 6,
                maxHeight: 6
            )
        )

        XCTAssertEqual(Int(result.size.width), 6)
        XCTAssertEqual(Int(result.size.height), 6)
        XCTAssertEqual(alphaComponent(atX: 0, y: 0, in: result), 0)
    }

    func testScreenshotCaptureResultBuildsPinItemFromScreenshotAsset() {
        let assetFile = AssetFile(
            id: "asset-1",
            sourceItemId: "source-1",
            fileName: "screenshot.png",
            filePath: "/tmp/screenshot.png",
            mimeType: "image/png",
            fileSize: 42,
            kind: .image
        )
        let sourceItem = SourceItem(
            id: "source-1",
            type: .screenshot,
            source: .screenshot,
            status: .captured,
            title: "截图 2026-06-11 10:00",
            previewText: "截图预览",
            sourceApp: "Safari",
            assetFileIds: [assetFile.id]
        )
        let captureResult = CaptureResult(sourceItem: sourceItem, assetFiles: [assetFile])

        let pinItem = ClipboardItem.pinItem(from: captureResult)

        XCTAssertEqual(pinItem.type, .image)
        XCTAssertEqual(pinItem.content, assetFile.id)
        XCTAssertEqual(pinItem.textContent, "截图预览")
        XCTAssertEqual(pinItem.sourceApp, "Safari")
        XCTAssertEqual(pinItem.isPinned, false)
    }

    private func makeSolidImage(width: Int, height: Int, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        image.unlockFocus()
        return image
    }

    private func alphaComponent(atX x: Int, y: Int, in image: NSImage) -> CGFloat {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let color = bitmap.colorAt(x: x, y: y)
        else {
            XCTFail("Failed to read bitmap color")
            return 1
        }
        return color.alphaComponent
    }
}
