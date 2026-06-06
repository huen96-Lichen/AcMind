import SwiftUI
import AppKit

enum AppSurfaceTokens {
    static let background = Color(NSColor.windowBackgroundColor)
    static let sidebarBackground = Color(NSColor.controlBackgroundColor)
    static let secondarySidebarBackground = Color(NSColor.controlBackgroundColor)
    static let contentBackground = Color(NSColor.windowBackgroundColor)
    static let islandBackground = Color(NSColor.windowBackgroundColor)
    static let islandBackgroundSoft = Color(NSColor.controlBackgroundColor)
    static let cardBackground = Color(NSColor.controlBackgroundColor)
    static let cardBackgroundSoft = Color(NSColor.controlBackgroundColor).opacity(0.92)
    static let cardBackgroundStrong = Color(NSColor.controlBackgroundColor)
    static let separator = Color(NSColor.separatorColor)
    static let primaryText = Color(nsColor: .labelColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
    static let accentBlue = Color(nsColor: .systemBlue)
    static let accentPrimary = Color(nsColor: .systemBlue)
    static let accentGreen = Color(nsColor: .systemGreen)
    static let accentOrange = Color(nsColor: .systemOrange)
    static let accentSecondary = Color(nsColor: .systemGray)
    static let accentCyan = Color(nsColor: .systemTeal)

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
        static let pageMaxWidth: CGFloat = 1040
        static let sidebarWidth: CGFloat = 208
        static let leadingRailWidth: CGFloat = 200
        static let trailingRailWidth: CGFloat = 224
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
        static let summaryWidth: CGFloat = 224
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
        VStack(alignment: .leading, spacing: 12) {
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
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 4)
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
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 3)
    }
}

struct AppSurfaceMetricTile: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let tint: Color

    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        tint: Color = AppSurfaceTokens.accentBlue
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.12))
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 30, height: 30)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: AppSurfaceTokens.Typography.caption, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.tertiaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppSurfaceTokens.cardBackground,
                            AppSurfaceTokens.cardBackgroundSoft.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.32), AppSurfaceTokens.separator.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: tint.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

struct AppSurfaceEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    let tint: Color

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        tint: Color = AppSurfaceTokens.accentBlue,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.tint = tint
        self.action = action
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 58, height: 58)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text(message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppSurfaceTokens.cardBackground, AppSurfaceTokens.cardBackgroundSoft],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

struct WorkspacePageShell<Leading: View, Content: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let headerActions: AnyView?
    let leadingRailWidth: CGFloat
    let trailingRailWidth: CGFloat
    @ViewBuilder let leadingRail: () -> Leading
    @ViewBuilder let content: () -> Content
    @ViewBuilder let trailingRail: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        headerActions: AnyView? = nil,
        leadingRailWidth: CGFloat = AppSurfaceTokens.Layout.leadingRailWidth,
        trailingRailWidth: CGFloat = AppSurfaceTokens.Layout.trailingRailWidth,
        @ViewBuilder leadingRail: @escaping () -> Leading,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailingRail: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.headerActions = headerActions
        self.leadingRailWidth = leadingRailWidth
        self.trailingRailWidth = trailingRailWidth
        self.leadingRail = leadingRail
        self.content = content
        self.trailingRail = trailingRail
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                Divider()

                HStack(spacing: 0) {
                    leadingRail()
                        .frame(width: leadingRailWidth, alignment: .topLeading)
                        .frame(maxHeight: .infinity, alignment: .topLeading)

                    Divider()

                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    Divider()

                    trailingRail()
                        .frame(width: trailingRailWidth, alignment: .topLeading)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
            .background(AppSurfaceTokens.background)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            if let headerActions {
                headerActions
            }
        }
    }
}

struct AppVisualBackdrop: View {
    var body: some View {
        AppSurfaceTokens.background
            .ignoresSafeArea()
    }
}
