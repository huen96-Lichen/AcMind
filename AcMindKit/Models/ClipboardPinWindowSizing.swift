import CoreGraphics
import Foundation
import AppKit

public enum ClipboardPinWindowSizing {
    public static let maxWindowWidth: CGFloat = 480
    public static let maxTextWindowWidth: CGFloat = 420
    public static let maxContentHeight: CGFloat = 520
    public static let chromeHeight: CGFloat = 44
    public static let minimumWindowWidth: CGFloat = 280
    public static let minimumWindowHeight: CGFloat = 160

    private static let horizontalPadding: CGFloat = 28
    private static let verticalPadding: CGFloat = 24
    private static let contentTextWidthPadding: CGFloat = 8
    private static let textWidthSafetyPadding: CGFloat = 64

    public static func textContentHeight(for text: String, contentWidth: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 15, weight: .regular)
        let constrainedWidth = max(160, contentWidth - contentTextWidthPadding)
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: constrainedWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )

        let estimated = ceil(bounding.height) + verticalPadding
        return min(max(96, estimated), maxContentHeight)
    }

    public static func textWindowSize(for text: String, displayFrame: CGRect) -> CGSize {
        let width = textWindowWidth(for: text, displayFrame: displayFrame)
        let contentWidth = max(220, width - horizontalPadding)
        let contentHeight = textContentHeight(for: text, contentWidth: contentWidth)
        let height = min(maxContentHeight + chromeHeight, contentHeight + chromeHeight)
        return CGSize(width: round(width), height: round(max(minimumWindowHeight, height)))
    }

    public static func textWindowWidth(for text: String, displayFrame: CGRect) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 14, weight: .regular)
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(8)
            .map(String.init)
        let sample = lines.max(by: { $0.count < $1.count }) ?? text
        let measured = (sample.prefix(68).description as NSString).size(withAttributes: [.font: font]).width
        let displayCap = min(maxTextWindowWidth, max(minimumWindowWidth, displayFrame.width * 0.32))
        return min(displayCap, max(minimumWindowWidth, measured + textWidthSafetyPadding))
    }

    public static func imageWindowSize(for imageSize: CGSize, displayFrame: CGRect) -> CGSize {
        let maxWidth = min(maxWindowWidth, max(minimumWindowWidth, displayFrame.width * 0.40))
        let maxHeight = min(maxContentHeight + chromeHeight, max(minimumWindowHeight, displayFrame.height * 0.62))

        let contentMaxWidth = max(200, maxWidth - horizontalPadding)
        let contentMaxHeight = max(120, maxHeight - chromeHeight - 16)

        let widthScale = contentMaxWidth / max(imageSize.width, 1)
        let heightScale = contentMaxHeight / max(imageSize.height, 1)
        let scale = min(widthScale, heightScale, 1)

        let contentWidth = imageSize.width * scale
        let contentHeight = imageSize.height * scale
        let windowWidth = min(maxWindowWidth, max(minimumWindowWidth, contentWidth + horizontalPadding))
        let windowHeight = min(maxContentHeight + chromeHeight, max(minimumWindowHeight, contentHeight + chromeHeight + 16))

        return CGSize(width: round(windowWidth), height: round(windowHeight))
    }

    public static func imageZoomWindowSize(for imageSize: CGSize, displayFrame: CGRect) -> CGSize {
        let baseSize = imageWindowSize(for: imageSize, displayFrame: displayFrame)
        let expandedWidth = min(maxWindowWidth, max(baseSize.width * 1.15, baseSize.width + 84))
        let expandedHeight = min(maxContentHeight + chromeHeight, max(baseSize.height * 1.12, baseSize.height + 56))

        let width = min(displayFrame.width * 0.66, expandedWidth)
        let height = min(displayFrame.height * 0.72, expandedHeight)

        return CGSize(
            width: round(max(minimumWindowWidth, width)),
            height: round(max(minimumWindowHeight, height))
        )
    }
}
