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
        VStack(alignment: .leading, spacing: 7) {
            if let title {
                HStack(alignment: .center, spacing: 7) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NotchV2DesignTokens.primaryText)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        }
                    }
                    Spacer()
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
