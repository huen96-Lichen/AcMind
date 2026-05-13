import SwiftUI
import AppKit

enum AppSurfaceTokens {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let islandBackground = background
    static let islandBackgroundSoft = Color(nsColor: .underPageBackgroundColor)
    static let cardBackground = Color.white
    static let cardBackgroundSoft = Color(nsColor: .controlBackgroundColor)
    static let cardBackgroundStrong = Color(nsColor: .selectedContentBackgroundColor)
    static let separator = Color.black.opacity(0.08)
    static let primaryText = Color(nsColor: .labelColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
    static let accentPurple = Color(red: 0.72, green: 0.12, blue: 0.90)
    static let accentGreen = Color(red: 0.25, green: 0.75, blue: 0.35)
    static let cardRadius: CGFloat = 20
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
