import SwiftUI

struct ACFrostedCard<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: ACLayout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ACLayout.cardRadius, style: .continuous)
                    .stroke(ACColors.border.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 6)
    }
}
