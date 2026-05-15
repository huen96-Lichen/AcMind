import SwiftUI

struct NotchV2Card<Content: View>: View {
    let title: String?
    let subtitle: String?
    let symbol: String?
    let padding: CGFloat
    let fillHeight: Bool
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        symbol: String? = nil,
        padding: CGFloat = 20,
        fillHeight: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.padding = padding
        self.fillHeight = fillHeight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: NotchV2DesignTokens.cardTitleSize, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: NotchV2DesignTokens.captionSize, weight: .medium))
                                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }

            content
        }
        .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .topLeading)
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                .stroke(NotchV2DesignTokens.panelBorder, lineWidth: 1)
        )
    }
}

struct NotchModuleCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let symbol: String?
    let height: CGFloat?
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        symbol: String? = nil,
        height: CGFloat? = nil,
        padding: CGFloat = 28,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.height = height
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: NotchV2DesignTokens.cardTitleSize, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: NotchV2DesignTokens.captionSize, weight: .medium))
                                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            content
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height ?? .infinity, alignment: .topLeading)
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                .stroke(NotchV2DesignTokens.panelBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous))
    }
}

typealias NotchModuleCardLegacy<Content: View> = NotchV2Card<Content>

struct NotchThreeColumnLayout<Left: View, Center: View, Right: View>: View {
    let left: Left
    let center: Center
    let right: Right

    init(
        @ViewBuilder left: () -> Left,
        @ViewBuilder center: () -> Center,
        @ViewBuilder right: () -> Right
    ) {
        self.left = left()
        self.center = center()
        self.right = right()
    }

    var body: some View {
        HStack(alignment: .top, spacing: NotchV2DesignTokens.columnGap) {
            left.frame(width: NotchV2DesignTokens.leftColumnWidth, alignment: .topLeading)
            center.frame(width: NotchV2DesignTokens.centerColumnWidth, alignment: .topLeading)
            right.frame(width: NotchV2DesignTokens.rightColumnWidth, alignment: .topLeading)
        }
        .padding(.horizontal, NotchV2DesignTokens.pagePadding)
        .padding(.top, NotchV2DesignTokens.contentTopGap)
        .padding(.bottom, NotchV2DesignTokens.contentBottomGap)
        .frame(width: NotchV2DesignTokens.expandedWidth, alignment: .topLeading)
    }
}

struct NotchStatusRow: View {
    let icon: String?
    let title: String
    let subtitle: String?
    let status: String?
    let accent: Bool

    init(icon: String? = nil, title: String, subtitle: String? = nil, status: String? = nil, accent: Bool = false) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.accent = accent
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(NotchV2DesignTokens.innerCardActive)
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent ? NotchV2DesignTokens.accentPurple : NotchV2DesignTokens.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                }
            }

            Spacer(minLength: 0)

            if let status {
                Text(status)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent ? NotchV2DesignTokens.accentPurple : NotchV2DesignTokens.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardActive)
        )
    }
}

struct NotchQuickActionGrid: View {
    let actions: [NotchV2ViewModel.QuickAction]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                Button(action: action.action) {
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(NotchV2DesignTokens.innerCardActive)
                                .frame(height: 42)
                            Image(systemName: action.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(NotchV2DesignTokens.accentPurple)
                        }
                        Text(action.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct NotchSectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: NotchV2DesignTokens.pageTitleSize, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: NotchV2DesignTokens.captionSize, weight: .medium))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
            }
        }
    }
}

struct NotchV2TopTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? NotchV2DesignTokens.primaryText : NotchV2DesignTokens.secondaryText)
                .frame(height: 24)
                .padding(.horizontal, 11)
                .background(
                    RoundedRectangle(cornerRadius: NotchV2DesignTokens.pillRadius, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(NotchV2DesignTokens.accentPurple) : AnyShapeStyle(Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NotchV2DesignTokens.pillRadius, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1)
                )
                .shadow(color: isSelected ? NotchV2DesignTokens.accentPurple.opacity(0.22) : .clear, radius: 8, x: 0, y: 4)
                .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

struct NotchV2ActionButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(NotchV2DesignTokens.innerCardBackground)
                        .frame(height: 34)

                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.accentPurple)
                }

                Text(title)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }
}

struct NotchV2StatusPill: View {
    let icon: String?
    let title: String
    let accent: Color
    let action: (() -> Void)?

    init(icon: String? = nil, title: String, accent: Color = NotchV2DesignTokens.cardBackgroundStrong, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.accent = accent
        self.action = action
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { pillContent }
                    .buttonStyle(.plain)
            } else {
                pillContent
            }
        }
    }

    private var pillContent: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
            }
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(accent)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct NotchV2SegmentedPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : NotchV2DesignTokens.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(NotchV2DesignTokens.accentPurple) : AnyShapeStyle(Color.clear))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.03), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct NotchV2SourceRow: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(NotchV2DesignTokens.primaryText)
    }
}
