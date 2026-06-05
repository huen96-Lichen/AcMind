import CoreGraphics
import SwiftUI

public enum MaterialCardGridLayout {
    public static let spacing: CGFloat = ContentCardPresentation.cardSpacing
    public static let outerPadding: CGFloat = 16

    public static func columnCount(
        availableWidth: CGFloat,
        minimumColumnWidth: CGFloat,
        maximumColumns: Int = 3
    ) -> Int {
        guard maximumColumns > 0 else { return 1 }
        let usableWidth = max(0, availableWidth - outerPadding)
        let rawCount = Int(floor((usableWidth + spacing) / (minimumColumnWidth + spacing)))
        return max(1, min(maximumColumns, rawCount))
    }

    public static func columns(
        availableWidth: CGFloat,
        minimumColumnWidth: CGFloat,
        maximumColumns: Int = 3
    ) -> [GridItem] {
        let count = columnCount(
            availableWidth: availableWidth,
            minimumColumnWidth: minimumColumnWidth,
            maximumColumns: maximumColumns
        )
        let fittedMinimumWidth = columnMinimumWidth(
            availableWidth: availableWidth,
            requestedMinimumColumnWidth: minimumColumnWidth,
            columnCount: count
        )
        return Array(repeating: GridItem(.flexible(minimum: fittedMinimumWidth), spacing: spacing), count: count)
    }

    public static func columnMinimumWidth(
        availableWidth: CGFloat,
        requestedMinimumColumnWidth: CGFloat,
        columnCount: Int
    ) -> CGFloat {
        let safeColumnCount = max(1, columnCount)
        let usableWidth = max(1, availableWidth - outerPadding - CGFloat(max(0, safeColumnCount - 1)) * spacing)
        return max(1, min(requestedMinimumColumnWidth, floor(usableWidth / CGFloat(safeColumnCount))))
    }
}
