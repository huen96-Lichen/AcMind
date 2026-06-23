import SwiftUI

enum CompanionLayoutTokens {
    static let expandedWindowWidth: CGFloat = 880
    static let expandedWindowHeight: CGFloat = 300
    static let topBarHeight: CGFloat = 34
    static let bottomBarHeight: CGFloat = 28

    static let pageHorizontalPadding: CGFloat = 14
    static let pageVerticalPadding: CGFloat = 8
    static let majorColumnSpacing: CGFloat = 12
    static let panelSpacing: CGFloat = 10

    static let panelPadding: CGFloat = 12
    static let panelHeaderHeight: CGFloat = 28
    static let panelCornerRadius: CGFloat = 18
    static let panelBorderWidth: CGFloat = 0.8

    static let cardPadding: CGFloat = 10
    static let cardSpacing: CGFloat = 8
    static let cardCornerRadius: CGFloat = 13

    static let controlHeightSmall: CGFloat = 24
    static let controlHeightMedium: CGFloat = 30
    static let controlCornerRadius: CGFloat = 9

    static let panelTitleSize: CGFloat = 15
    static let sectionTitleSize: CGFloat = 12
    static let bodySize: CGFloat = 11
    static let metadataSize: CGFloat = 10

    static let panelHeaderIconBox: CGFloat = 28
    static let panelHeaderIconSize: CGFloat = 13
    static let rowIconSize: CGFloat = 12

    static let panelBorderOpacity: Double = 0.08
    static let cardBorderOpacity: Double = 0.06
    static let hoverFillOpacity: Double = 0.07
    static let pressedFillOpacity: Double = 0.10

    static let templateAColumnWidth: CGFloat = 232
    static let templateBLeftColumnWidth: CGFloat = 248
}

enum CompanionPageTemplate {
    @MainActor
    static func triple<Left: View, Center: View, Right: View>(
        leftWidth: CGFloat = CompanionLayoutTokens.templateAColumnWidth,
        rightWidth: CGFloat = CompanionLayoutTokens.templateAColumnWidth,
        topInset: CGFloat = CompanionLayoutTokens.pageVerticalPadding,
        @ViewBuilder left: () -> Left,
        @ViewBuilder center: () -> Center,
        @ViewBuilder right: () -> Right
    ) -> some View {
        NotchV2DashboardLayout(leftColumnWidth: leftWidth, rightColumnWidth: rightWidth, topInset: topInset) {
            left()
        } centerColumn: {
            center()
        } rightColumn: {
            right()
        }
    }

    @MainActor
    static func double<Left: View, Center: View>(
        leftWidth: CGFloat = CompanionLayoutTokens.templateBLeftColumnWidth,
        topInset: CGFloat = CompanionLayoutTokens.pageVerticalPadding,
        @ViewBuilder left: () -> Left,
        @ViewBuilder center: () -> Center
    ) -> some View {
        NotchV2DashboardLayout(leftColumnWidth: leftWidth, rightColumnWidth: 0, topInset: topInset) {
            left()
        } centerColumn: {
            center()
        } rightColumn: {
            EmptyView()
        }
    }

    @MainActor
    static func single<Content: View>(
        topInset: CGFloat = CompanionLayoutTokens.pageVerticalPadding,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, CompanionLayoutTokens.pageHorizontalPadding)
        .padding(.top, topInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct CompanionPanel<Content: View>: View {
    let title: String
    let subtitle: String?
    let symbol: String?
    let fillHeight: Bool
    let accent: Color?
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        symbol: String? = nil,
        fillHeight: Bool = false,
        accent: Color? = nil,
        padding: CGFloat = CompanionLayoutTokens.panelPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.fillHeight = fillHeight
        self.accent = accent
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CompanionPanelHeader(title: title, subtitle: subtitle, symbol: symbol)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .topLeading)
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.panelCornerRadius, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.panelCornerRadius, style: .continuous)
                .stroke(accent?.opacity(0.18) ?? NotchV2DesignTokens.panelBorder.opacity(0.9), lineWidth: CompanionLayoutTokens.panelBorderWidth)
        )
        .shadow(color: accent?.opacity(0.02) ?? .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct CompanionPanelHeader: View {
    let title: String
    let subtitle: String?
    let symbol: String?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let symbol {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.92))
                        .frame(width: CompanionLayoutTokens.panelHeaderIconBox, height: CompanionLayoutTokens.panelHeaderIconBox)
                    NotchV2Glyph(symbol: symbol, role: .cardTitle, tint: NotchV2DesignTokens.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: CompanionLayoutTokens.panelTitleSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .medium, design: .rounded))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(height: CompanionLayoutTokens.panelHeaderHeight, alignment: .center)
    }
}

struct CompanionSectionHeader: View {
    let title: String
    let subtitle: String?
    let symbol: String?

    init(title: String, subtitle: String? = nil, symbol: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                NotchV2Glyph(symbol: symbol, role: .action, tint: NotchV2DesignTokens.secondaryText)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: CompanionLayoutTokens.sectionTitleSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .medium, design: .rounded))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct CompanionCard<Content: View>: View {
    let accent: Color?
    let fillHeight: Bool
    let padding: CGFloat
    let content: Content

    init(accent: Color? = nil, fillHeight: Bool = false, padding: CGFloat = CompanionLayoutTokens.cardPadding, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.fillHeight = fillHeight
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .topLeading)
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous)
                    .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous)
                    .stroke(accent?.opacity(0.12) ?? NotchV2DesignTokens.innerBorder.opacity(0.62), lineWidth: 0.8)
            )
    }
}

struct CompanionRow<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            leading
            Spacer(minLength: 0)
            trailing
        }
        .font(.system(size: CompanionLayoutTokens.bodySize, weight: .medium, design: .rounded))
    }
}

struct CompanionValueRow: View {
    let title: String
    let value: String
    let icon: String?
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                NotchV2Glyph(symbol: icon, role: .infoRow, tint: accent)
            }
            Text(title)
                .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .medium, design: .rounded))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: CompanionLayoutTokens.bodySize, weight: .medium, design: .rounded))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius - 3, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground.opacity(0.90))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius - 3, style: .continuous)
                .stroke(accent.opacity(0.10), lineWidth: 1)
        )
    }
}

struct CompanionStatusRow: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        CompanionValueRow(title: title, value: value, icon: nil, accent: accent)
    }
}

struct CompanionStatusPill: View {
    let icon: String?
    let title: String
    let accent: Color
    let isSelected: Bool
    let action: (() -> Void)?

    init(icon: String? = nil, title: String, accent: Color = NotchV2DesignTokens.cardBackgroundStrong, isSelected: Bool = false, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.accent = accent
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        let content = HStack(spacing: 5) {
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
                .fill(accent.opacity(0.92))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.06), lineWidth: 1)
        )

        Group {
            if let action {
                Button(action: action) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
    }
}

struct CompanionActionButton: View {
    let icon: String
    let title: String
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    init(icon: String, title: String, accent: Color = NotchV2DesignTokens.accentBlue, isSelected: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.accent = accent
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: CompanionLayoutTokens.controlCornerRadius, style: .continuous)
                        .fill(isSelected ? accent.opacity(0.14) : NotchV2DesignTokens.innerCardBackground.opacity(0.95))
                        .frame(width: 24, height: 24)
                    NotchV2Glyph(symbol: icon, role: .action, tint: isSelected ? accent : NotchV2DesignTokens.secondaryText, isActive: isSelected)
                }

                Text(title)
                    .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minHeight: CompanionLayoutTokens.controlHeightMedium)
            .background(
                RoundedRectangle(cornerRadius: CompanionLayoutTokens.controlCornerRadius, style: .continuous)
                    .fill(isSelected ? NotchV2DesignTokens.innerCardActive.opacity(0.85) : NotchV2DesignTokens.panelBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CompanionLayoutTokens.controlCornerRadius, style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.26) : NotchV2DesignTokens.panelBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CompanionSearchField: View {
    @Binding var text: String
    var placeholder: String = "搜索"
    var isFocused: Bool = false
    var focusAction: (() -> Void)? = nil
    var clearAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .medium, design: .rounded))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
                .onTapGesture {
                    focusAction?()
                }

            if text.isEmpty == false {
                Button {
                    clearAction?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: CompanionLayoutTokens.controlHeightSmall)
        .background(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.controlCornerRadius, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.controlCornerRadius, style: .continuous)
                .stroke(isFocused ? NotchV2DesignTokens.accentBlue.opacity(0.28) : NotchV2DesignTokens.separator.opacity(0.36), lineWidth: 1)
        )
    }
}

struct CompanionEmptyState: View {
    let title: String
    let detail: String
    let icon: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                NotchV2Glyph(symbol: icon, role: .action, tint: NotchV2DesignTokens.secondaryText)
                Text(title)
                    .font(.system(size: CompanionLayoutTokens.bodySize, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
            }
            Text(detail)
                .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .medium, design: .rounded))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(2)
                .truncationMode(.tail)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .semibold, design: .rounded))
                    .buttonStyle(.plain)
                    .foregroundStyle(NotchV2DesignTokens.accentBlue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.90))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.18), lineWidth: 1)
        )
    }
}

struct CompanionDivider: View {
    var body: some View {
        Divider()
            .overlay(NotchV2DesignTokens.separator.opacity(0.45))
    }
}

struct CompanionMetricCard<Content: View>: View {
    let title: String
    let value: String
    let detail: String?
    let accent: Color
    @ViewBuilder let footer: Content

    init(title: String, value: String, detail: String? = nil, accent: Color = NotchV2DesignTokens.primaryText, @ViewBuilder footer: () -> Content = { EmptyView() }) {
        self.title = title
        self.value = value
        self.detail = detail
        self.accent = accent
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .medium, design: .rounded))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
            if let detail, detail.isEmpty == false {
                Text(detail)
                    .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .medium, design: .rounded))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            footer
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardBackground)
        )
    }
}

struct CompanionToggleRow: View {
    let title: String
    let subtitle: String?
    let isOn: Binding<Bool>

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: CompanionLayoutTokens.bodySize, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .medium, design: .rounded))
                        .foregroundStyle(NotchV2DesignTokens.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius - 3, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius - 3, style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.18), lineWidth: 1)
        )
    }
}

struct CompanionSliderRow: View {
    let title: String
    let valueText: String
    let range: ClosedRange<Double>
    let step: Double
    let value: Binding<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: CompanionLayoutTokens.bodySize, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                Spacer(minLength: 0)
                Text(valueText)
                    .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
            }
            Slider(value: value, in: range, step: step)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius - 3, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius - 3, style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.18), lineWidth: 1)
        )
    }
}

struct CompanionPickerRow<Option: Hashable & Identifiable & CustomStringConvertible>: View {
    let title: String
    let selection: Binding<Option>
    let options: [Option]

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: CompanionLayoutTokens.bodySize, weight: .semibold, design: .rounded))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
            Spacer(minLength: 0)
            Picker("", selection: selection) {
                ForEach(options) { option in
                    Text(option.description).tag(option)
                }
            }
            .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius - 3, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius - 3, style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.18), lineWidth: 1)
        )
    }
}

struct CompanionModuleRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isEnabled: Binding<Bool>

    var body: some View {
        HStack(spacing: 8) {
            NotchV2Glyph(symbol: symbol, role: .infoRow, tint: NotchV2DesignTokens.primaryText)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: CompanionLayoutTokens.bodySize, weight: .semibold, design: .rounded))
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: CompanionLayoutTokens.metadataSize, weight: .medium, design: .rounded))
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: isEnabled)
                .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius - 3, style: .continuous)
                .fill(NotchV2DesignTokens.panelBackground.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompanionLayoutTokens.cardCornerRadius - 3, style: .continuous)
                .stroke(NotchV2DesignTokens.separator.opacity(0.18), lineWidth: 1)
        )
    }
}
