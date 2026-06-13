import SwiftUI

struct NotchV2DashboardLayout<Left: View, Center: View, Right: View>: View {
    let leftColumnWidth: CGFloat
    let rightColumnWidth: CGFloat
    let topInset: CGFloat
    let leftColumn: Left
    let centerColumn: Center
    let rightColumn: Right

    init(
        leftColumnWidth: CGFloat = 216,
        rightColumnWidth: CGFloat = 240,
        topInset: CGFloat = 6,
        @ViewBuilder leftColumn: () -> Left,
        @ViewBuilder centerColumn: () -> Center,
        @ViewBuilder rightColumn: () -> Right
    ) {
        self.leftColumnWidth = leftColumnWidth
        self.rightColumnWidth = rightColumnWidth
        self.topInset = topInset
        self.leftColumn = leftColumn()
        self.centerColumn = centerColumn()
        self.rightColumn = rightColumn()
    }

    var body: some View {
        HStack(alignment: .top, spacing: NotchV2DesignTokens.cardSpacing) {
            leftColumn
                .frame(width: leftColumnWidth, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .topLeading)

            centerColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            rightColumn
                .frame(width: rightColumnWidth, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, NotchV2DesignTokens.pagePadding)
        .padding(.top, topInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
