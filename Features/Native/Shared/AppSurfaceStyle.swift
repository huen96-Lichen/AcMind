import SwiftUI
import AppKit

enum AppSurfaceTokens {
    static let background = ACColors.pageBackground
    static let islandBackground = background
    static let islandBackgroundSoft = ACColors.pageBackground
    static let cardBackground = ACColors.cardBackground
    static let cardBackgroundSoft = ACColors.softFill
    static let cardBackgroundStrong = ACColors.selectedFill
    static let separator = ACColors.border
    static let primaryText = ACColors.primaryText
    static let secondaryText = ACColors.secondaryText
    static let tertiaryText = ACColors.tertiaryText
    static let accentPurple = ACColors.accentPurple
    static let accentGreen = ACColors.accentGreen
    static let cardRadius: CGFloat = ACLayout.cardRadius
}

struct AppSurfaceCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        padding: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }
            }

            content
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator, lineWidth: 1)
        )
    }
}
