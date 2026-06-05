import SwiftUI

enum NotchV2CardStyle {
    case `default`
    case music(Color)
    case agent
    case timeline
}

struct NotchV2Card<Content: View>: View {
    let title: String?
    let subtitle: String?
    let symbol: String?
    let padding: CGFloat
    let fillHeight: Bool
    let cornerRadius: CGFloat
    let cardAccent: Color?
    let style: NotchV2CardStyle
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        symbol: String? = nil,
        padding: CGFloat = 14,
        fillHeight: Bool = false,
        cornerRadius: CGFloat = NotchV2DesignTokens.cardRadius,
        cardAccent: Color? = nil,
        style: NotchV2CardStyle = .default,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.padding = padding
        self.fillHeight = fillHeight
        self.cornerRadius = cornerRadius
        self.cardAccent = cardAccent
        self.style = style
        self.content = content()
    }

    private var backgroundFill: AnyShapeStyle {
        switch style {
        case .default:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        NotchV2DesignTokens.panelBackground,
                        NotchV2DesignTokens.innerCardBackground.opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .music(let accent):
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        accent.opacity(0.2),
                        NotchV2DesignTokens.innerCardBackground.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .agent:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        NotchV2DesignTokens.accentBlue.opacity(0.15),
                        NotchV2DesignTokens.innerCardBackground.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .timeline:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.1),
                        NotchV2DesignTokens.innerCardBackground.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack(alignment: .center, spacing: 6) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(NotchV2DesignTokens.Typography.title)
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if let subtitle {
                            Text(subtitle)
                                .font(NotchV2DesignTokens.Typography.caption)
                                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)
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
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    backgroundFill
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            cardAccent?.opacity(0.3) ?? NotchV2DesignTokens.panelBorder,
                            cardAccent?.opacity(0.1) ?? Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: cardAccent?.opacity(0.08) ?? .black.opacity(0.15), radius: 14, x: 0, y: 8)
    }
}

struct NotchV2TopTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isSelected ? NotchV2DesignTokens.primaryText : NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
                .frame(height: 25)
                .padding(.horizontal, 9)
                .background(
                    RoundedRectangle(cornerRadius: NotchV2DesignTokens.pillRadius, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(NotchV2DesignTokens.accentPurple.opacity(0.95)) : AnyShapeStyle(Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NotchV2DesignTokens.pillRadius, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.06) : Color.clear, lineWidth: 1)
                )
                .shadow(color: isSelected ? NotchV2DesignTokens.accentPurple.opacity(0.14) : .clear, radius: 6, x: 0, y: 3)
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
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(NotchV2DesignTokens.innerCardBackground)
                        .frame(height: 26)

                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.accentPurple)
                }

                Text(title)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
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
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(accent.opacity(0.96))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
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
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isSelected ? .white : NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(NotchV2DesignTokens.accentPurple.opacity(0.95)) : AnyShapeStyle(Color.clear))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.06) : Color.white.opacity(0.02), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct NotchV2SourceRow: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(NotchV2DesignTokens.primaryText)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
