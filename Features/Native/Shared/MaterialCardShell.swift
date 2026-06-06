import SwiftUI
import AcMindKit

struct MaterialCardShell<Header: View, Preview: View, Footer: View, Actions: View>: View {
    let isSelected: Bool
    let isHovered: Bool
    let cardHeight: CGFloat
    let onSelect: () -> Void

    @ViewBuilder let header: () -> Header
    @ViewBuilder let preview: () -> Preview
    @ViewBuilder let footer: () -> Footer
    @ViewBuilder let actions: () -> Actions

    init(
        isSelected: Bool,
        isHovered: Bool,
        cardHeight: CGFloat,
        onSelect: @escaping () -> Void,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder preview: @escaping () -> Preview,
        @ViewBuilder footer: @escaping () -> Footer,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.isSelected = isSelected
        self.isHovered = isHovered
        self.cardHeight = cardHeight
        self.onSelect = onSelect
        self.header = header
        self.preview = preview
        self.footer = footer
        self.actions = actions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                header()
                    .frame(minHeight: ContentCardPresentation.headerMinHeight, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                actions()
                    .fixedSize(horizontal: true, vertical: true)
            }

            preview()
                .contentShape(Rectangle())
                .onTapGesture(perform: onSelect)
            footer()
                .contentShape(Rectangle())
                .onTapGesture(perform: onSelect)
        }
        .padding(ContentCardPresentation.innerPadding)
        .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: ContentCardPresentation.cornerRadius, style: .continuous)
                .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.08) : (isHovered ? AppSurfaceTokens.cardBackgroundSoft : AppSurfaceTokens.cardBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: ContentCardPresentation.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ContentCardPresentation.cornerRadius, style: .continuous)
                .stroke(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.30) : AppSurfaceTokens.separator, lineWidth: 1)
        )
    }
}
