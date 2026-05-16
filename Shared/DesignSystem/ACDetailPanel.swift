import SwiftUI

struct ACDetailPanel<Content: View>: View {
    let width: CGFloat?
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(
        width: CGFloat? = ACLayout.detailPanelWidth,
        padding: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.width = width
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(width: width, alignment: .topLeading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: ACLayout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ACLayout.cardRadius, style: .continuous)
                    .stroke(ACColors.border.opacity(0.5), lineWidth: 1)
            )
    }
}
