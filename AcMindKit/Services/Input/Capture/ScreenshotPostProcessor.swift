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

        if let bitmapImage = renderBitmap(image, sourceRect: sourceRect, destinationRect: destinationRect, canvasSize: canvasSize, cornerRadius: options.cornerRadius) {
            return bitmapImage
        }

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

    private static func renderBitmap(
        _ image: NSImage,
        sourceRect: CGRect,
        destinationRect: CGRect,
        canvasSize: CGSize,
        cornerRadius: CGFloat
    ) -> NSImage? {
        let width = max(1, Int(canvasSize.width.rounded()))
        let height = max(1, Int(canvasSize.height.rounded()))
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let sourceImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let didDraw = data.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  )
            else {
                return false
            }

            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.interpolationQuality = .high
            context.draw(sourceImage, in: destinationRect)
            return true
        }

        guard didDraw else { return nil }

        if cornerRadius > 0 {
            applyRoundedCornerAlphaMask(
                to: &data,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                radius: min(cornerRadius, min(canvasSize.width, canvasSize.height) / 2)
            )
        }

        guard let provider = CGDataProvider(data: Data(data) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              )
        else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: canvasSize)
    }

    private static func applyRoundedCornerAlphaMask(
        to data: inout [UInt8],
        width: Int,
        height: Int,
        bytesPerRow: Int,
        radius: CGFloat
    ) {
        guard radius > 0 else { return }

        let radiusSquared = radius * radius

        for y in 0..<height {
            for x in 0..<width {
                let px = CGFloat(x) + 0.5
                let py = CGFloat(y) + 0.5
                var cornerCenter: CGPoint?

                if px < radius && py < radius {
                    cornerCenter = CGPoint(x: radius, y: radius)
                } else if px > CGFloat(width) - radius && py < radius {
                    cornerCenter = CGPoint(x: CGFloat(width) - radius, y: radius)
                } else if px < radius && py > CGFloat(height) - radius {
                    cornerCenter = CGPoint(x: radius, y: CGFloat(height) - radius)
                } else if px > CGFloat(width) - radius && py > CGFloat(height) - radius {
                    cornerCenter = CGPoint(x: CGFloat(width) - radius, y: CGFloat(height) - radius)
                }

                guard let cornerCenter else { continue }

                let dx = px - cornerCenter.x
                let dy = py - cornerCenter.y
                if dx * dx + dy * dy > radiusSquared {
                    let index = y * bytesPerRow + x * 4
                    data[index] = 0
                    data[index + 1] = 0
                    data[index + 2] = 0
                    data[index + 3] = 0
                }
            }
        }
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
