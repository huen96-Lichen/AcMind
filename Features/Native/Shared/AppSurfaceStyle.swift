import SwiftUI
import AppKit

enum AppSurfaceTokens {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: .windowBackgroundColor)
    static let secondarySidebarBackground = Color(nsColor: .windowBackgroundColor)
    static let contentBackground = Color(nsColor: .windowBackgroundColor)
    static let islandBackground = background
    static let islandBackgroundSoft = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .textBackgroundColor)
    static let cardBackgroundSoft = Color(nsColor: .controlBackgroundColor)
    static let cardBackgroundStrong = Color(nsColor: .selectedContentBackgroundColor)
    static let separator = Color(nsColor: .separatorColor).opacity(0.72)
    static let primaryText = Color(nsColor: .labelColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
    static let accentBlue = Color(nsColor: .systemBlue)
    static let accentPurple = Color(red: 0.72, green: 0.12, blue: 0.90)
    static let accentGreen = Color(red: 0.25, green: 0.75, blue: 0.35)
    static let accentOrange = Color(nsColor: .systemOrange)

    static let mainCardRadius: CGFloat = 18
    static let cardRadius: CGFloat = 16
    static let secondaryCardRadius: CGFloat = 14
    static let inlineBlockRadius: CGFloat = 10
    static let sidebarRadius: CGFloat = 24

    enum Typography {
        static let pageTitle: CGFloat = 28
        static let pageSubtitle: CGFloat = 13
        static let sectionTitle: CGFloat = 16
        static let sectionDesc: CGFloat = 12
        static let cardTitle: CGFloat = 14
        static let body: CGFloat = 13
        static let caption: CGFloat = 11
        static let rowTitle: CGFloat = 14.5
        static let rowDesc: CGFloat = 12.5
    }

    enum Layout {
        static let pageMaxWidth: CGFloat = 1360
        static let pagePadding: CGFloat = 24
        static let sectionSpacing: CGFloat = 16
        static let cardSpacing: CGFloat = 12
        static let rowHeight: CGFloat = 46
        static let toggleRowHeight: CGFloat = 46
        static let tabHeight: CGFloat = 40
        static let tabMinWidth: CGFloat = 112
        static let chipHeight: CGFloat = 28
        static let buttonHeight: CGFloat = 32
        static let keycapHeight: CGFloat = 28
        static let summaryWidth: CGFloat = 300
    }
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
                        .font(.system(size: AppSurfaceTokens.Typography.cardTitle, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: AppSurfaceTokens.Typography.caption, weight: .medium))
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

struct AppSurfaceSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: AppSurfaceTokens.Typography.sectionTitle, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: AppSurfaceTokens.Typography.sectionDesc))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }

            content
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.8), lineWidth: 1)
        )
    }
}
