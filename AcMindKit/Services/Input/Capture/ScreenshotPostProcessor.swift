import AppKit
import Foundation

public struct ScreenshotPostProcessingOptions: Sendable, Equatable {
    public var cornerRadius: CGFloat
    public var maxWidth: CGFloat?
    public var maxHeight: CGFloat?

    public init(cornerRadius: CGFloat = 0, maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil) {
        self.cornerRadius = cornerRadius
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
    }
}

public enum ScreenshotImagePostProcessor {
    public static func process(_ image: NSImage, options: ScreenshotPostProcessingOptions) async -> NSImage {
        await MainActor.run {
            processSync(image, options: options)
        }
    }

    private static func processSync(_ image: NSImage, options: ScreenshotPostProcessingOptions) -> NSImage {
        let targetSize = resizedSize(for: image.size, options: options)
        let canvasSize = targetSize
        let sourceRect = CGRect(origin: .zero, size: image.size)
        let destinationRect = CGRect(origin: .zero, size: canvasSize)

        let processed = NSImage(size: canvasSize)
        processed.lockFocus()
        defer { processed.unlockFocus() }

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.draw(in: destinationRect, from: sourceRect, operation: .copy, fraction: 1)
            return processed
        }

        context.saveGState()
        if options.cornerRadius > 0 {
            let clippingPath = NSBezierPath(
                roundedRect: destinationRect,
                xRadius: options.cornerRadius,
                yRadius: options.cornerRadius
            )
            clippingPath.addClip()
        }

        image.draw(in: destinationRect, from: sourceRect, operation: .copy, fraction: 1)
        context.restoreGState()

        return processed
    }

    private static func resizedSize(for originalSize: CGSize, options: ScreenshotPostProcessingOptions) -> CGSize {
        let originalWidth = max(originalSize.width, 1)
        let originalHeight = max(originalSize.height, 1)

        let widthLimit = options.maxWidth.flatMap { $0 > 0 ? $0 : nil } ?? originalWidth
        let heightLimit = options.maxHeight.flatMap { $0 > 0 ? $0 : nil } ?? originalHeight

        let widthScale = widthLimit / originalWidth
        let heightScale = heightLimit / originalHeight
        let scale = min(widthScale, heightScale, 1)

        let width = max(1, round(originalWidth * scale))
        let height = max(1, round(originalHeight * scale))
        return CGSize(width: width, height: height)
    }
}

public extension ClipboardItem {
    static func pinItem(from captureResult: CaptureResult) -> ClipboardItem {
        let sourceItem = captureResult.sourceItem
        let assetId = captureResult.assetFiles.first?.id ?? sourceItem.assetFileIds.first

        return ClipboardItem(
            type: .image,
            content: assetId,
            textContent: sourceItem.previewText ?? sourceItem.ocrText ?? sourceItem.title,
            sourceApp: sourceItem.sourceApp,
            isPinned: false,
            createdAt: sourceItem.createdAt
        )
    }
}
