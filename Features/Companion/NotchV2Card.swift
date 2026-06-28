import SwiftUI

enum NotchV2CardStyle {
    case `default`
    case music(Color)
    case agent
    case timeline
}

struct NotchV2Glyph: View {
    enum Role {
        case cardTitle
        case action
        case pill
        case infoRow
        case statusStrip

        var fontSize: CGFloat {
            switch self {
            case .cardTitle: return 10
            case .action: return 10
            case .pill: return 9
            case .infoRow: return 9
            case .statusStrip: return 8
            }
        }

        var frameSize: CGSize {
            switch self {
            case .cardTitle: return CGSize(width: 16, height: 16)
            case .action: return CGSize(width: 24, height: 24)
            case .pill: return CGSize(width: 12, height: 12)
            case .infoRow: return CGSize(width: 14, height: 14)
            case .statusStrip: return CGSize(width: 11, height: 11)
            }
        }

        var backgroundOpacity: Double {
            switch self {
            case .cardTitle: return 0.08
            case .action: return 0.12
            case .pill, .infoRow, .statusStrip: return 0
            }
        }
    }

    let symbol: String
    var role: Role = .pill
    var tint: Color = NotchV2DesignTokens.secondaryText
    var isActive: Bool = false

    var body: some View {
        let size = role.frameSize

        ZStack {
            if role.backgroundOpacity > 0 {
                RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.28, style: .continuous)
                    .fill(tint.opacity(isActive ? role.backgroundOpacity + 0.04 : role.backgroundOpacity))
            }

            Image(systemName: symbol)
                .symbolRenderingMode(.monochrome)
                .imageScale(.small)
                .font(.system(size: role.fontSize, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: size.width, height: size.height, alignment: .center)
        }
        .frame(width: size.width, height: size.height, alignment: .center)
        .accessibilityHidden(true)
    }
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
            return AnyShapeStyle(NotchV2DesignTokens.panelBackground.opacity(0.82))
        case .music(_):
            return AnyShapeStyle(NotchV2DesignTokens.innerCardBackground.opacity(0.92))
        case .agent:
            return AnyShapeStyle(NotchV2DesignTokens.innerCardBackground.opacity(0.88))
        case .timeline:
            return AnyShapeStyle(NotchV2DesignTokens.innerCardBackground.opacity(0.92))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                HStack(alignment: .center, spacing: 6) {
                    if let symbol {
                        NotchV2Glyph(symbol: symbol, role: .cardTitle)
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
                    cardAccent?.opacity(0.16) ?? NotchV2DesignTokens.panelBorder.opacity(0.92),
                    lineWidth: 0.75
                )
        )
        .shadow(color: cardAccent?.opacity(0.06) ?? .black.opacity(0.12), radius: 10, x: 0, y: 5)
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
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)

                Text(title)
                    .font(NotchV2DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .frame(minHeight: 68, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.14) : NotchV2DesignTokens.innerCardBackground.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.28) : NotchV2DesignTokens.separator.opacity(0.20), lineWidth: 1)
            )
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
                NotchV2Glyph(symbol: icon, role: .pill, tint: NotchV2DesignTokens.primaryText, isActive: isSelected)
            }
            Text(title)
                .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .semibold, design: .rounded))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(isSelected ? accent.opacity(1.0) : accent.opacity(0.92))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
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
        CompanionValueRow(title: title, value: value, icon: icon, accent: accent)
    }
}
