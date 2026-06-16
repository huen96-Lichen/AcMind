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
            return AnyShapeStyle(NotchV2DesignTokens.panelBackground)
        case .music(_):
            return AnyShapeStyle(NotchV2DesignTokens.innerCardBackground.opacity(0.96))
        case .agent:
            return AnyShapeStyle(NotchV2DesignTokens.innerCardBackground.opacity(0.96))
        case .timeline:
            return AnyShapeStyle(NotchV2DesignTokens.innerCardBackground.opacity(0.96))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    cardAccent?.opacity(0.22) ?? NotchV2DesignTokens.panelBorder,
                    lineWidth: 0.8
                )
        )
        .shadow(color: cardAccent?.opacity(0.03) ?? .black.opacity(0.08), radius: 8, x: 0, y: 4)
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
                        .fill(isSelected ? AnyShapeStyle(NotchV2DesignTokens.accentBlue.opacity(0.10)) : AnyShapeStyle(Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NotchV2DesignTokens.pillRadius, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.06) : Color.clear, lineWidth: 1)
                )
                .shadow(color: isSelected ? NotchV2DesignTokens.accentBlue.opacity(0.10) : .clear, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct NotchV2ActionButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    init(
        icon: String,
        title: String,
        isSelected: Bool,
        accent: Color = NotchV2DesignTokens.accentBlue,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.isSelected = isSelected
        self.accent = accent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                        .fill(isSelected ? accent.opacity(0.14) : NotchV2DesignTokens.innerCardBackground.opacity(0.95))
                        .frame(width: 24, height: 24)

                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? accent : NotchV2DesignTokens.secondaryText)
                }

                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                    .fill(isSelected ? NotchV2DesignTokens.panelBackground : NotchV2DesignTokens.panelBackground.opacity(0.90))
            )
                .overlay(
                    RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                        .stroke(isSelected ? NotchV2DesignTokens.separator.opacity(0.50) : NotchV2DesignTokens.separator.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: isSelected ? .black.opacity(0.05) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct NotchV2StatusPill: View {
    let icon: String?
    let title: String
    let accent: Color
    let isSelected: Bool
    let action: (() -> Void)?

    init(
        icon: String? = nil,
        title: String,
        accent: Color = NotchV2DesignTokens.cardBackgroundStrong,
        isSelected: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.accent = accent
        self.isSelected = isSelected
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
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .background(
            Capsule(style: .continuous)
                .fill(isSelected ? accent.opacity(0.92) : accent.opacity(0.92))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.16), value: isSelected)
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
                        .fill(isSelected ? AnyShapeStyle(NotchV2DesignTokens.panelBackground) : AnyShapeStyle(Color.clear))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isSelected ? NotchV2DesignTokens.separator.opacity(0.55) : Color.white.opacity(0.02), lineWidth: 1)
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

struct NotchV2InfoRow: View {
    let title: String
    let value: String
    let icon: String?
    let accent: Color
    let compactValue: Bool

    init(
        title: String,
        value: String,
        icon: String? = nil,
        accent: Color = NotchV2DesignTokens.secondaryText,
        compactValue: Bool = false
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.accent = accent
        self.compactValue = compactValue
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 14)
            }

            Text(title)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(value)
                .font(compactValue ? NotchV2DesignTokens.Typography.caption : NotchV2DesignTokens.Typography.body)
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground.opacity(0.90))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(accent.opacity(0.10), lineWidth: 1)
        )
    }
}
