import SwiftUI
import AppKit
import AcMindKit

enum AppSurfaceTokens {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: .controlBackgroundColor)
    static let secondarySidebarBackground = Color(nsColor: .underPageBackgroundColor)
    static let contentBackground = Color(nsColor: .windowBackgroundColor)
    static let islandBackground = Color(nsColor: .windowBackgroundColor)
    static let islandBackgroundSoft = Color(nsColor: .controlBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let cardBackgroundSoft = Color(nsColor: .controlBackgroundColor).opacity(0.96)
    static let cardBackgroundStrong = Color(nsColor: .textBackgroundColor)
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

    enum Radius {
        static let main: CGFloat = 16
        static let card: CGFloat = 12
        static let section: CGFloat = 10
        static let control: CGFloat = 9
        static let sidebar: CGFloat = 18
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32

        static let page: CGFloat = lg
        static let section: CGFloat = md
        static let card: CGFloat = sm
    }

    static let mainCardRadius: CGFloat = Radius.main
    static let cardRadius: CGFloat = Radius.card
    static let secondaryCardRadius: CGFloat = Radius.card
    static let inlineBlockRadius: CGFloat = Radius.section
    static let sidebarRadius: CGFloat = Radius.sidebar

    enum Typography {
        static let display: CGFloat = 28
        static let pageTitle: CGFloat = 24
        static let pageSubtitle: CGFloat = 13
        static let pageEyebrow: CGFloat = 11
        static let sectionTitle: CGFloat = 15
        static let sectionDesc: CGFloat = 12
        static let cardTitle: CGFloat = 14
        static let bodyLarge: CGFloat = 15
        static let body: CGFloat = 13
        static let caption: CGFloat = 11
        static let control: CGFloat = 12
        static let controlStrong: CGFloat = 13
        static let rowTitle: CGFloat = 13
        static let rowDesc: CGFloat = 12
        static let metricValue: CGFloat = 18
        static let metricUnit: CGFloat = 11
        static let metricLabel: CGFloat = 11
        static let badge: CGFloat = 10.5
        static let dialogTitle: CGFloat = 22
    }

    enum Layout {
        static let pageMaxWidth: CGFloat = 1240
        static let sidebarWidth: CGFloat = 250
        static let toolbarHeight: CGFloat = 60
        static let leadingRailWidth: CGFloat = 220
        static let trailingRailWidth: CGFloat = 304
        static let pagePadding: CGFloat = Spacing.page
        static let sectionSpacing: CGFloat = Spacing.section
        static let cardSpacing: CGFloat = Spacing.card
        static let compactInspectorThreshold: CGFloat = 1320
        static let minimumWindowWidth: CGFloat = 1180
        static let minimumWindowHeight: CGFloat = 720
        static let rowHeight: CGFloat = 46
        static let toggleRowHeight: CGFloat = 46
        static let tabHeight: CGFloat = 40
        static let tabMinWidth: CGFloat = 112
        static let chipHeight: CGFloat = 28
        static let compactChipHeight: CGFloat = 24
        static let buttonHeight: CGFloat = 32
        static let keycapHeight: CGFloat = 28
        static let inputHeight: CGFloat = 36
        static let summaryWidth: CGFloat = 224
        static let rowMinHeight: CGFloat = 42
    }
}

struct AppSurfaceCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let padding: CGFloat
    let fillHeight: Bool
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        padding: CGFloat = 20,
        fillHeight: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.padding = padding
        self.fillHeight = fillHeight
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
                            .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }
            }

            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.card, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.card, style: .continuous)
                .stroke(AppSurfaceTokens.separator, lineWidth: 1)
        )
        .shadow(color: AppSurfaceTokens.separator.opacity(0.08), radius: 2, x: 0, y: 1)
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
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: AppSurfaceTokens.separator.opacity(0.06), radius: 2, x: 0, y: 1)
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
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.control, style: .continuous)
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
                    .font(.system(size: AppSurfaceTokens.Typography.metricLabel, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)

                Text(value)
                    .font(.system(size: AppSurfaceTokens.Typography.metricValue, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.tertiaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(AppSurfaceTokens.Spacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .stroke(
                    tint.opacity(0.18),
                    lineWidth: 1
                )
        )
        .shadow(color: AppSurfaceTokens.separator.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct AppSurfaceSummaryChip: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: AppSurfaceTokens.Typography.caption, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)

            Text(value)
                .font(.system(size: AppSurfaceTokens.Typography.controlStrong, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSurfaceTokens.Spacing.sm)
        .padding(.vertical, AppSurfaceTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.Radius.section, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

struct AppSurfaceSummaryStrip: View {
    let chips: [AppSurfaceSummaryChip]

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: AppSurfaceTokens.Spacing.sm),
                GridItem(.flexible(), spacing: AppSurfaceTokens.Spacing.sm),
                GridItem(.flexible(), spacing: AppSurfaceTokens.Spacing.sm)
            ],
            spacing: AppSurfaceTokens.Spacing.sm
        ) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                chip
            }
        }
    }
}

struct AcCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let padding: CGFloat
    let fillHeight: Bool
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        padding: CGFloat = 20,
        fillHeight: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.padding = padding
        self.fillHeight = fillHeight
        self.content = content()
    }

    var body: some View {
        AppSurfaceCard(title: title, subtitle: subtitle, padding: padding, fillHeight: fillHeight) {
            content
        }
    }
}

struct AcSection<Content: View>: View {
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
        AppSurfaceSectionCard(title: title, subtitle: subtitle, padding: padding) {
            content
        }
    }
}

struct AcStatusBadge: View {
    enum Tone {
        case neutral
        case active
        case success
        case warning
        case danger
    }

    let text: String
    let tone: Tone

    init(text: String, tone: Tone = .neutral) {
        self.text = text
        self.tone = tone
    }

    private var tint: Color {
        switch tone {
        case .neutral: return AppSurfaceTokens.secondaryText
        case .active: return AppSurfaceTokens.accentBlue
        case .success: return AppSurfaceTokens.accentGreen
        case .warning: return AppSurfaceTokens.accentOrange
        case .danger: return .red
        }
    }

    var body: some View {
                Text(text)
                    .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            )
    }
}

struct AcSearchField: View {
    @Binding var text: String
    let placeholder: String
    let width: CGFloat
    let onClear: (() -> Void)?
    let focusBinding: FocusState<Bool>.Binding?

    init(
        text: Binding<String>,
        placeholder: String = "搜索",
        width: CGFloat = 260,
        onClear: (() -> Void)? = nil,
        focusBinding: FocusState<Bool>.Binding? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.width = width
        self.onClear = onClear
        self.focusBinding = focusBinding
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            if let focusBinding {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: AppSurfaceTokens.Typography.control))
                    .focused(focusBinding)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: AppSurfaceTokens.Typography.control))
            }
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Button {
                    text = ""
                    onClear?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator, lineWidth: 1)
        )
        .frame(minHeight: AppSurfaceTokens.Layout.inputHeight)
        .frame(width: width)
    }
}

struct AcEmptyState: View {
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
        AppSurfaceEmptyState(
            icon: icon,
            title: title,
            message: message,
            actionTitle: actionTitle,
            tint: tint,
            action: action
        )
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
                    .font(.system(size: AppSurfaceTokens.Typography.bodyLarge, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Text(message)
                    .font(.system(size: AppSurfaceTokens.Typography.body))
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
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: AppSurfaceTokens.separator.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

struct AcMetric<Accessory: View>: View {
    let label: String
    let primaryValue: String
    let unit: String?
    let trend: String?
    let state: String?
    let lastUpdated: String?
    let tint: Color
    @ViewBuilder let accessory: Accessory

    init(
        label: String,
        primaryValue: String,
        unit: String? = nil,
        trend: String? = nil,
        state: String? = nil,
        lastUpdated: String? = nil,
        tint: Color = AppSurfaceTokens.accentBlue,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.label = label
        self.primaryValue = primaryValue
        self.unit = unit
        self.trend = trend
        self.state = state
        self.lastUpdated = lastUpdated
        self.tint = tint
        self.accessory = accessory()
    }

    var body: some View {
        MetricCard(
            label: label,
            primaryValue: primaryValue,
            unit: unit,
            trend: trend,
            state: state,
            lastUpdated: lastUpdated,
            tint: tint
        ) {
            accessory
        }
    }
}

struct AcListRow: View {
    let title: String
    let subtitle: String?
    let metadata: String?
    let icon: String?
    let iconTint: Color
    let isSelected: Bool
    let isEnabled: Bool
    let showsChevron: Bool
    let trailingContent: AnyView?
    let action: (() -> Void)?

    @State private var isHovered = false

    init(
        title: String,
        subtitle: String? = nil,
        metadata: String? = nil,
        icon: String? = nil,
        iconTint: Color = AppSurfaceTokens.accentBlue,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        showsChevron: Bool = false,
        trailingContent: AnyView? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.metadata = metadata
        self.icon = icon
        self.iconTint = iconTint
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.showsChevron = showsChevron
        self.trailingContent = trailingContent
        self.action = action
    }

    var body: some View {
        Button {
            action?()
        } label: {
            content
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false || action == nil)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(action == nil ? "" : "按下可打开")
    }

    @ViewBuilder
    private var content: some View {
        HStack(spacing: 10) {
            if let icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconTint.opacity(0.12))
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(iconTint)
                }
                .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(1)

                    if let metadata, metadata.isEmpty == false {
                        Text(metadata)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .lineLimit(1)
                    }
                }

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            if let trailingContent {
                trailingContent
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText.opacity(0.75))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(isSelected ? AppSurfaceTokens.cardBackgroundSoft : isHovered ? AppSurfaceTokens.cardBackground.opacity(0.5) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var borderColor: Color {
        if isSelected {
            return AppSurfaceTokens.accentBlue.opacity(0.28)
        }
        if isHovered {
            return AppSurfaceTokens.separator.opacity(0.8)
        }
        return AppSurfaceTokens.separator.opacity(0.6)
    }

    private var accessibilityLabel: String {
        [title, subtitle, metadata]
            .compactMap { $0 }
            .filter { $0.isEmpty == false }
            .joined(separator: "，")
    }
}

struct AcInspector<Content: View>: View {
    let title: String
    let subtitle: String?
    let footerContent: AnyView?
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        footerContent: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.footerContent = footerContent
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Inspector")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                            .textCase(.uppercase)

                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                            .lineLimit(2)

                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .lineLimit(2)
                        }
                    }

                    content
                }
                .padding(16)
            }

            if let footerContent {
                footerContent
            }
        }
        .background(AppSurfaceBackdrop())
        .accessibilityLabel("\(title)检查器")
    }
}

struct AcSegmentedControl<Option: Hashable>: View {
    let title: String?
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String
    let accessibilityLabel: String?
    @State private var hoveredOption: Option?

    init(
        title: String? = nil,
        options: [Option],
        selection: Binding<Option>,
        accessibilityLabel: String? = nil,
        label: @escaping (Option) -> String
    ) {
        self.title = title
        self.options = options
        self._selection = selection
        self.accessibilityLabel = accessibilityLabel
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
            }

            HStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection == option
                    let isHovered = hoveredOption == option

                    Button {
                        selection = option
                    } label: {
                        Text(label(option))
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? AppSurfaceTokens.primaryText : AppSurfaceTokens.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                    .fill(isSelected ? AppSurfaceTokens.cardBackgroundSoft : isHovered ? AppSurfaceTokens.cardBackground.opacity(0.5) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                                    .stroke(
                                        isSelected ? AppSurfaceTokens.accentBlue.opacity(0.28) : AppSurfaceTokens.separator.opacity(isHovered ? 0.85 : 0.6),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hoveredOption = $0 ? option : (hoveredOption == option ? nil : hoveredOption) }
                    .accessibilityLabel(label(option))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .accessibilityLabel(accessibilityLabel ?? title ?? "分段控制")
    }
}

struct AcActionButton: View {
    let title: String
    let icon: String?
    let role: ButtonRole?
    let isProminent: Bool
    let isEnabled: Bool
    let isLoading: Bool
    let disabledReason: String
    let action: () -> Void

    init(
        title: String,
        icon: String? = nil,
        role: ButtonRole? = nil,
        isProminent: Bool = true,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        disabledReason: String = "当前操作暂不可用",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.role = role
        self.isProminent = isProminent
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.disabledReason = disabledReason
        self.action = action
    }

    var body: some View {
        if isProminent {
            buttonContent
                .buttonStyle(.borderedProminent)
        } else {
            buttonContent
                .buttonStyle(.bordered)
        }
    }

    private var buttonContent: some View {
        Button(role: role) {
            action()
        } label: {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(.system(size: 12, weight: .semibold))
            .frame(minHeight: AppSurfaceTokens.Layout.buttonHeight)
        }
        .disabled(isEnabled == false || isLoading)
        .help(isEnabled == false ? disabledReason : title)
        .accessibilityLabel(title)
        .accessibilityHint(isEnabled == false ? disabledReason : title)
    }
}

struct AcSettingRow<Content: View>: View {
    let title: String
    let description: String?
    let trailingContent: Content
    let isStacked: Bool

    init(
        title: String,
        description: String? = nil,
        isStacked: Bool = false,
        @ViewBuilder trailingContent: () -> Content
    ) {
        self.title = title
        self.description = description
        self.trailingContent = trailingContent()
        self.isStacked = isStacked
    }

    var body: some View {
        Group {
            if isStacked {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    trailingContent
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    header
                    Spacer(minLength: 0)
                    trailingContent
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            if let description {
                Text(description)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct AcPermissionRow: View {
    let title: String
    let description: String
    let status: AppPermissionStatus
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(description)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                StatusBadge(status: status)

                switch status {
                case .unknown, .notDetermined:
                    AcActionButton(title: "申请", icon: "arrow.right.circle", isProminent: false) {
                        onRequest()
                    }
                    .controlSize(.small)

                case .requesting:
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.85)

                case .denied, .restricted, .needsSystemSettings, .failed:
                    AcActionButton(title: "去设置", icon: "gear", isProminent: false) {
                        onOpenSettings()
                    }
                    .controlSize(.small)

                case .authorized:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.75), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(status.displayName)")
    }
}

struct AcProgressRow: View {
    let title: String
    let value: Double?
    let trailingText: String?
    let tint: Color

    init(
        title: String,
        value: Double?,
        trailingText: String? = nil,
        tint: Color = AppSurfaceTokens.accentBlue
    ) {
        self.title = title
        self.value = value
        self.trailingText = trailingText
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .lineLimit(1)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(AppSurfaceTokens.separator.opacity(0.18))
                        .frame(height: 8)

                    if let value {
                        Capsule(style: .continuous)
                            .fill(tint)
                            .frame(width: proxy.size.width * CGFloat(max(0, min(value, 100))) / 100.0, height: 8)
                    }
                }
            }
            .frame(height: 8)

            if let trailingText {
                Text(trailingText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

struct AcTrendChart: View {
    let values: [Double]
    let tint: Color
    let lineWidth: CGFloat

    init(values: [Double], tint: Color = AppSurfaceTokens.accentBlue, lineWidth: CGFloat = 2.2) {
        self.values = values
        self.tint = tint
        self.lineWidth = lineWidth
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)

                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(AppSurfaceTokens.separator.opacity(0.12))
                            .frame(height: 1)
                        Spacer(minLength: 0)
                    }
                }

                trendFill(in: size)
                    .fill(tint.opacity(0.06))

                trendLine(in: size)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous))
    }

    private func trendLine(in size: CGSize) -> Path {
        path(in: size)
    }

    private func trendFill(in size: CGSize) -> Path {
        var path = path(in: size)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    private func path(in size: CGSize) -> Path {
        let points = samplePoints(in: size)
        return Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    private func samplePoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 1)
        let stepX = size.width / CGFloat(values.count - 1)

        return values.enumerated().map { index, value in
            let normalized = CGFloat((value - minValue) / range)
            let x = CGFloat(index) * stepX
            let y = size.height - (normalized * size.height)
            return CGPoint(x: x, y: y)
        }
    }
}

struct AppSurfaceDialogFrame<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let width: CGFloat
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        tint: Color = AppSurfaceTokens.accentBlue,
        width: CGFloat = 420,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.width = width
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.12))
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                }

                Spacer(minLength: 0)
            }

            content
        }
        .padding(18)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius + 2, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius + 2, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: AppSurfaceTokens.separator.opacity(0.08), radius: 5, x: 0, y: 2)
    }
}

struct AppSurfaceDialogActionRow: View {
    let primaryTitle: String
    let secondaryTitle: String
    let tertiaryTitle: String?
    let primaryRole: ButtonRole?
    let secondaryRole: ButtonRole?
    let tertiaryRole: ButtonRole?
    let primaryDisabled: Bool
    let secondaryDisabled: Bool
    let tertiaryDisabled: Bool
    let primaryDisabledReason: String
    let secondaryDisabledReason: String
    let tertiaryDisabledReason: String
    let primaryAction: () -> Void
    let secondaryAction: () -> Void
    let tertiaryAction: (() -> Void)?

    init(
        primaryTitle: String,
        secondaryTitle: String,
        tertiaryTitle: String? = nil,
        primaryRole: ButtonRole? = nil,
        secondaryRole: ButtonRole? = nil,
        tertiaryRole: ButtonRole? = nil,
        primaryDisabled: Bool = false,
        secondaryDisabled: Bool = false,
        tertiaryDisabled: Bool = false,
        primaryDisabledReason: String = "主要操作当前不可用",
        secondaryDisabledReason: String = "次要操作当前不可用",
        tertiaryDisabledReason: String = "此操作当前不可用",
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void,
        tertiaryAction: (() -> Void)? = nil
    ) {
        self.primaryTitle = primaryTitle
        self.secondaryTitle = secondaryTitle
        self.tertiaryTitle = tertiaryTitle
        self.primaryRole = primaryRole
        self.secondaryRole = secondaryRole
        self.tertiaryRole = tertiaryRole
        self.primaryDisabled = primaryDisabled
        self.secondaryDisabled = secondaryDisabled
        self.tertiaryDisabled = tertiaryDisabled
        self.primaryDisabledReason = primaryDisabledReason
        self.secondaryDisabledReason = secondaryDisabledReason
        self.tertiaryDisabledReason = tertiaryDisabledReason
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.tertiaryAction = tertiaryAction
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(role: secondaryRole) {
                secondaryAction()
            } label: {
                Text(secondaryTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(secondaryDisabled)
            .help(secondaryDisabled ? secondaryDisabledReason : secondaryTitle)
            .accessibilityHint(secondaryDisabled ? secondaryDisabledReason : secondaryTitle)

            if let tertiaryTitle, let tertiaryAction {
                Button(role: tertiaryRole) {
                    tertiaryAction()
                } label: {
                    Text(tertiaryTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(tertiaryDisabled)
                .help(tertiaryDisabled ? tertiaryDisabledReason : tertiaryTitle)
                .accessibilityHint(tertiaryDisabled ? tertiaryDisabledReason : tertiaryTitle)
            }

            Spacer(minLength: 0)

            Button(role: primaryRole) {
                primaryAction()
            } label: {
                Text(primaryTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(primaryDisabled)
            .help(primaryDisabled ? primaryDisabledReason : primaryTitle)
            .accessibilityHint(primaryDisabled ? primaryDisabledReason : primaryTitle)
        }
    }
}

struct AppSurfaceConfirmationCard: View {
    let title: String
    let message: String
    let icon: String
    let tint: Color
    let primaryTitle: String
    let secondaryTitle: String
    let tertiaryTitle: String?
    let footerNote: String?
    let primaryAction: () -> Void
    let secondaryAction: () -> Void
    let tertiaryAction: (() -> Void)?

    init(
        title: String,
        message: String,
        icon: String,
        tint: Color = AppSurfaceTokens.accentBlue,
        primaryTitle: String,
        secondaryTitle: String,
        tertiaryTitle: String? = nil,
        footerNote: String? = "选完就会关闭窗口，不会再额外弹系统对话框。",
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void,
        tertiaryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.tint = tint
        self.primaryTitle = primaryTitle
        self.secondaryTitle = secondaryTitle
        self.tertiaryTitle = tertiaryTitle
        self.footerNote = footerNote
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.tertiaryAction = tertiaryAction
    }

    var body: some View {
        AppSurfaceDialogFrame(
            title: title,
            subtitle: message,
            icon: icon,
            tint: tint
        ) {
            VStack(alignment: .leading, spacing: 12) {
                AppSurfaceDialogActionRow(
                    primaryTitle: primaryTitle,
                    secondaryTitle: secondaryTitle,
                    tertiaryTitle: tertiaryTitle,
                    primaryAction: primaryAction,
                    secondaryAction: secondaryAction,
                    tertiaryAction: tertiaryAction
                )

                if let footerNote {
                    Text(footerNote)
                        .font(.system(size: 11.5))
                        .foregroundStyle(AppSurfaceTokens.tertiaryText)
                }
            }
        }
    }
}

struct AppSurfaceReminderCard: View {
    let title: String
    let message: String
    let icon: String
    let tint: Color
    let actionTitle: String
    let action: () -> Void

    init(
        title: String,
        message: String,
        icon: String,
        tint: Color = AppSurfaceTokens.accentBlue,
        actionTitle: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.tint = tint
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        AppSurfaceDialogFrame(
            title: title,
            subtitle: message,
            icon: icon,
            tint: tint
        ) {
            HStack {
                Spacer(minLength: 0)
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }
}

struct AppSurfacePromptCard: View {
    let title: String
    let message: String
    let icon: String
    let tint: Color
    let placeholder: String
    @Binding var text: String
    let confirmTitle: String
    let cancelTitle: String
    let footerNote: String?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    init(
        title: String,
        message: String,
        icon: String,
        tint: Color = AppSurfaceTokens.accentBlue,
        placeholder: String,
        text: Binding<String>,
        confirmTitle: String,
        cancelTitle: String,
        footerNote: String? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.tint = tint
        self.placeholder = placeholder
        self._text = text
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.footerNote = footerNote
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        AppSurfaceDialogFrame(
            title: title,
            subtitle: message,
            icon: icon,
            tint: tint
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)

                AppSurfaceDialogActionRow(
                    primaryTitle: confirmTitle,
                    secondaryTitle: cancelTitle,
                    primaryRole: nil,
                    secondaryRole: nil,
                    primaryDisabled: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    primaryAction: onConfirm,
                    secondaryAction: onCancel
                )

                if let footerNote {
                    Text(footerNote)
                        .font(.system(size: 11.5))
                        .foregroundStyle(AppSurfaceTokens.tertiaryText)
                }
            }
        }
    }
}

struct WorkspacePageShell<Leading: View, Content: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let headerActions: AnyView?
    let searchContent: AnyView?
    let leadingRailWidth: CGFloat
    let trailingRailWidth: CGFloat
    let usesResponsiveInspector: Bool
    let windowWidthOffset: CGFloat
    let compactInspectorTitle: String
    @ViewBuilder let leadingRail: () -> Leading
    @ViewBuilder let content: () -> Content
    @ViewBuilder let trailingRail: () -> Trailing
    @State private var showsCompactInspector = false

    init(
        title: String,
        subtitle: String? = nil,
        headerActions: AnyView? = nil,
        searchContent: AnyView? = nil,
        leadingRailWidth: CGFloat = AppSurfaceTokens.Layout.leadingRailWidth,
        trailingRailWidth: CGFloat = AppSurfaceTokens.Layout.trailingRailWidth,
        usesResponsiveInspector: Bool = false,
        windowWidthOffset: CGFloat = AppSurfaceTokens.Layout.sidebarWidth,
        compactInspectorTitle: String = "详情",
        @ViewBuilder leadingRail: @escaping () -> Leading,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailingRail: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.headerActions = headerActions
        self.searchContent = searchContent
        self.leadingRailWidth = leadingRailWidth
        self.trailingRailWidth = trailingRailWidth
        self.usesResponsiveInspector = usesResponsiveInspector
        self.windowWidthOffset = windowWidthOffset
        self.compactInspectorTitle = compactInspectorTitle
        self.leadingRail = leadingRail
        self.content = content
        self.trailingRail = trailingRail
    }

    var body: some View {
        AcWorkShell(
            title: title,
            subtitle: subtitle,
            headerActions: headerActions,
            searchContent: searchContent,
            leadingRailWidth: leadingRailWidth,
            trailingRailWidth: trailingRailWidth,
            usesResponsiveInspector: usesResponsiveInspector,
            windowWidthOffset: windowWidthOffset,
            compactInspectorTitle: compactInspectorTitle,
            leadingRail: leadingRail,
            content: content,
            trailingRail: trailingRail
        )
    }
}

struct AcPageToolbar: View {
    let title: String
    let context: String?
    let searchContent: AnyView?
    let trailingContent: AnyView?
    let compactInspectorTitle: String?
    let compactInspectorAction: (() -> Void)?

    init(
        title: String,
        context: String? = nil,
        searchContent: AnyView? = nil,
        trailingContent: AnyView? = nil,
        compactInspectorTitle: String? = nil,
        compactInspectorAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.context = context
        self.searchContent = searchContent
        self.trailingContent = trailingContent
        self.compactInspectorTitle = compactInspectorTitle
        self.compactInspectorAction = compactInspectorAction
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                    .lineLimit(1)

                if let context {
                    Text(context)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            if let searchContent {
                searchContent
            }

            if let trailingContent {
                trailingContent
            }

            if let compactInspectorTitle, let compactInspectorAction {
                Button(action: compactInspectorAction) {
                    Label(compactInspectorTitle, systemImage: "sidebar.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("打开\(compactInspectorTitle)")
            }
        }
        .frame(minHeight: 60, alignment: .center)
    }
}

struct AcSidebar: View {
    var body: some View {
        SidebarView()
    }
}

struct AcWorkShell<Leading: View, Content: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let headerActions: AnyView?
    let searchContent: AnyView?
    let leadingRailWidth: CGFloat
    let trailingRailWidth: CGFloat
    let usesResponsiveInspector: Bool
    let windowWidthOffset: CGFloat
    let compactInspectorTitle: String
    @ViewBuilder let leadingRail: () -> Leading
    @ViewBuilder let content: () -> Content
    @ViewBuilder let trailingRail: () -> Trailing
    @State private var showsCompactInspector = false
#if DEBUG
    @StateObject private var layoutDebugStore = LayoutDebugStore.shared
#endif

    init(
        title: String,
        subtitle: String? = nil,
        headerActions: AnyView? = nil,
        searchContent: AnyView? = nil,
        leadingRailWidth: CGFloat = AppSurfaceTokens.Layout.leadingRailWidth,
        trailingRailWidth: CGFloat = AppSurfaceTokens.Layout.trailingRailWidth,
        usesResponsiveInspector: Bool = false,
        windowWidthOffset: CGFloat = AppSurfaceTokens.Layout.sidebarWidth,
        compactInspectorTitle: String = "详情",
        @ViewBuilder leadingRail: @escaping () -> Leading,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailingRail: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.headerActions = headerActions
        self.searchContent = searchContent
        self.leadingRailWidth = leadingRailWidth
        self.trailingRailWidth = trailingRailWidth
        self.usesResponsiveInspector = usesResponsiveInspector
        self.windowWidthOffset = windowWidthOffset
        self.compactInspectorTitle = compactInspectorTitle
        self.leadingRail = leadingRail
        self.content = content
        self.trailingRail = trailingRail
    }

    var body: some View {
        GeometryReader { proxy in
            let isCompactHeight = proxy.size.height < 760
            let inspectorPresentation = AcWorkResponsiveLayout.inspectorPresentation(
                windowWidth: proxy.size.width + windowWidthOffset,
                hasInspector: trailingRailWidth > 0
            )
            let usesCompactInspector = usesResponsiveInspector && inspectorPresentation == .sheet

            VStack(spacing: 0) {
                AcPageToolbar(
                    title: title,
                    context: subtitle,
                    searchContent: searchContent,
                    trailingContent: headerActions,
                    compactInspectorTitle: usesCompactInspector ? compactInspectorTitle : nil,
                    compactInspectorAction: usesCompactInspector ? { showsCompactInspector = true } : nil
                )
                .padding(.horizontal, AppSurfaceTokens.Spacing.lg)
                .padding(.vertical, isCompactHeight ? AppSurfaceTokens.Spacing.xxs + 2 : AppSurfaceTokens.Spacing.xs + 2)
                .layoutDebugRegion("TopToolbar")
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(title)工具栏")
                .accessibilitySortPriority(90)

                Divider()

                HStack(spacing: 0) {
                    if leadingRailWidth > 0 {
                        leadingRail()
                            .frame(width: leadingRailWidth, alignment: .topLeading)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                            .layoutDebugRegion("PrimarySidebarPanel")
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("\(title)筛选栏")
                            .accessibilitySortPriority(80)

                        Divider()
                    }

                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .layoutDebugRegion("WorkbenchContent")
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("\(title)内容区")
                        .accessibilitySortPriority(70)

                    if trailingRailWidth > 0 && usesCompactInspector == false {
                        Divider()

                        trailingRail()
                            .frame(width: trailingRailWidth, alignment: .topLeading)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                            .layoutDebugRegion("RightStatusRail")
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("\(title)详情栏")
                            .accessibilitySortPriority(60)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .coordinateSpace(name: "AcWorkWindow")
            .layoutDebugRegion("AppShell")
            .background(AppSurfaceBackdrop())
            .sheet(isPresented: $showsCompactInspector) {
                trailingRail()
                    .frame(minWidth: trailingRailWidth, idealWidth: max(trailingRailWidth, 420))
                    .frame(minHeight: 520, idealHeight: 680)
            }
            #if DEBUG
            .onPreferenceChange(LayoutMeasurementPreferenceKey.self) { measurements in
                layoutDebugStore.update(measurements)
            }
            .overlay {
                if layoutDebugStore.isOverlayVisible {
                    LayoutDebugOverlay(measurements: layoutDebugStore.measurements)
                        .allowsHitTesting(false)
                }
            }
            #endif
            .onChange(of: usesCompactInspector) { _, isCompact in
                if isCompact == false {
                    showsCompactInspector = false
                }
            }
        }
    }
}

struct AppVisualBackdrop: View {
    var body: some View {
        AppSurfaceBackdrop()
    }
}

struct AppSurfaceBackdrop: View {
    var body: some View {
        AppSurfaceTokens.background
        .ignoresSafeArea()
    }
}

#if DEBUG
struct LayoutMeasurement: Identifiable, Equatable {
    let id: String
    let name: String
    let frame: CGRect
    let coordinateSpace: String
}

struct LayoutMeasurementPreferenceKey: PreferenceKey {
    static let defaultValue: [LayoutMeasurement] = []

    static func reduce(value: inout [LayoutMeasurement], nextValue: () -> [LayoutMeasurement]) {
        value.append(contentsOf: nextValue())
    }
}

@MainActor
final class LayoutDebugStore: ObservableObject {
    static let shared = LayoutDebugStore()

    @Published var measurements: [LayoutMeasurement] = []
    @Published var isOverlayVisible: Bool = false

    func update(_ measurements: [LayoutMeasurement]) {
        self.measurements = measurements
    }
}

private struct LayoutDebugProbe: View {
    let name: String
    let coordinateSpace: String

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named(coordinateSpace))
            Color.clear.preference(
                key: LayoutMeasurementPreferenceKey.self,
                value: [
                    LayoutMeasurement(
                        id: name,
                        name: name,
                        frame: frame,
                        coordinateSpace: coordinateSpace
                    )
                ]
            )
        }
        .allowsHitTesting(false)
    }
}

struct LayoutDebugOverlay: View {
    let measurements: [LayoutMeasurement]
    var coordinateSpace: String = "AcWorkWindow"

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(measurements) { measurement in
                    let color = color(for: measurement.name)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(width: max(measurement.frame.width, 0), height: max(measurement.frame.height, 0))
                        .position(x: measurement.frame.midX, y: measurement.frame.midY)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(measurement.name)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        Text(
                            "x:\(Int(measurement.frame.minX)) y:\(Int(measurement.frame.minY)) w:\(Int(measurement.frame.width)) h:\(Int(measurement.frame.height))"
                        )
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(color)
                    .padding(4)
                    .background(.black.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .position(
                        x: min(max(measurement.frame.minX + 70, 50), proxy.size.width - 70),
                        y: min(max(measurement.frame.minY + 18, 16), proxy.size.height - 16)
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func color(for name: String) -> Color {
        let palette: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .pink, .purple]
        let index = abs(name.hashValue) % palette.count
        return palette[index]
    }
}

extension View {
    func layoutDebugRegion(_ name: String, coordinateSpace: String = "AcWorkWindow") -> some View {
        background(LayoutDebugProbe(name: name, coordinateSpace: coordinateSpace))
    }
}
#else
extension View {
    func layoutDebugRegion(_ name: String, coordinateSpace: String = "AcWorkWindow") -> some View {
        self
    }
}
#endif

struct AppSurfaceTextEditorShell: View {
    @Binding var text: String
    var minHeight: CGFloat = 220
    var font: Font = .system(.body, design: .monospaced)
    var showsBackgroundStroke: Bool = true

    var body: some View {
        TextEditor(text: $text)
            .font(font)
            .scrollContentBackground(.hidden)
            .padding(10)
            .frame(minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                    .stroke(
                        showsBackgroundStroke ? AppSurfaceTokens.separator.opacity(0.8) : .clear,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous))
    }
}
