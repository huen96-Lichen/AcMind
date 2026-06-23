import SwiftUI
import AppKit

enum AcMindDesignTokens {

    // MARK: - Layout
    enum Layout {
        static let sidebarWidth: CGFloat = AppSurfaceTokens.Layout.sidebarWidth
        static let contentPadding: CGFloat = AppSurfaceTokens.Layout.pagePadding
        static let pageRadius: CGFloat = AppSurfaceTokens.mainCardRadius
        static let cardRadius: CGFloat = AppSurfaceTokens.cardRadius
        static let secondaryCardRadius: CGFloat = AppSurfaceTokens.Radius.section
        static let inlineBlockRadius: CGFloat = AppSurfaceTokens.inlineBlockRadius
        static let controlHeight: CGFloat = 36
        static let smallSpacing: CGFloat = AppSurfaceTokens.Spacing.xs
        static let mediumSpacing: CGFloat = AppSurfaceTokens.Spacing.md
        static let largeSpacing: CGFloat = AppSurfaceTokens.Spacing.xl
        static let sectionSpacing: CGFloat = AppSurfaceTokens.Spacing.xxl
    }

    // MARK: - Colors (通用)
    enum Colors {
        static let appBackground = Color(NSColor.windowBackgroundColor)
        static let surface = Color(NSColor.controlBackgroundColor).opacity(0.82)
        static let surfaceStrong = Color(NSColor.controlBackgroundColor)
        static let border = Color(NSColor.separatorColor)
        static let textPrimary = Color(NSColor.labelColor)
        static let textSecondary = Color(NSColor.secondaryLabelColor)
        static let textTertiary = Color(NSColor.tertiaryLabelColor)
        static let accent = Color.accentColor

        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
    }

    // MARK: - Native (亮色模式，Mac 主窗口)
    enum Native {
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
        static let primaryText = Color(NSColor.labelColor)
        static let secondaryText = Color(NSColor.secondaryLabelColor)
        static let tertiaryText = Color(NSColor.tertiaryLabelColor)
        static let accentBlue = Color(nsColor: .systemBlue)
        static let accentPrimary = Color(nsColor: .systemBlue)
        static let accentGreen = Color(nsColor: .systemGreen)
        static let accentOrange = Color(nsColor: .systemOrange)
        static let accentSecondary = Color(nsColor: .systemGray)
        static let accentCyan = Color(nsColor: .systemTeal)

        static let mainCardRadius: CGFloat = AppSurfaceTokens.mainCardRadius
        static let cardRadius: CGFloat = AppSurfaceTokens.cardRadius
        static let secondaryCardRadius: CGFloat = AppSurfaceTokens.secondaryCardRadius
        static let inlineBlockRadius: CGFloat = AppSurfaceTokens.inlineBlockRadius
        static let sidebarRadius: CGFloat = AppSurfaceTokens.sidebarRadius

        enum Typography {
            static let pageTitle: CGFloat = AppSurfaceTokens.Typography.pageTitle
            static let pageSubtitle: CGFloat = AppSurfaceTokens.Typography.pageSubtitle
            static let sectionTitle: CGFloat = AppSurfaceTokens.Typography.sectionTitle
            static let sectionDesc: CGFloat = AppSurfaceTokens.Typography.sectionDesc
            static let cardTitle: CGFloat = AppSurfaceTokens.Typography.cardTitle
            static let body: CGFloat = AppSurfaceTokens.Typography.body
            static let caption: CGFloat = AppSurfaceTokens.Typography.caption
            static let rowTitle: CGFloat = AppSurfaceTokens.Typography.rowTitle
            static let rowDesc: CGFloat = AppSurfaceTokens.Typography.rowDesc
        }

        enum Layout {
            static let pageMaxWidth: CGFloat = 1360
            static let pagePadding: CGFloat = AppSurfaceTokens.Layout.pagePadding
            static let sectionSpacing: CGFloat = AppSurfaceTokens.Layout.sectionSpacing
            static let cardSpacing: CGFloat = AppSurfaceTokens.Layout.cardSpacing
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

    // MARK: - Notch (暗色模式，Notch/Companion 面板)
    enum Notch {
        static let rootBackground = Color(red: 0.03, green: 0.03, blue: 0.035)
        static let panelBackground = Color(red: 0.055, green: 0.055, blue: 0.07)
        static let innerCardBackground = Color(red: 0.08, green: 0.08, blue: 0.095)
        static let innerCardActive = Color(red: 0.10, green: 0.10, blue: 0.12)
        static let panelBorder = Color.white.opacity(0.06)
        static let innerBorder = Color.white.opacity(0.08)
        static let backdropGradientTop = Color(red: 0.04, green: 0.04, blue: 0.06)
        static let backdropGradientBottom = Color(red: 0.015, green: 0.015, blue: 0.02)
        static let accentPurple = Color(nsColor: .systemBlue)
        static let accentPurpleLight = accentPurple
        static let accentPurpleDark = accentPurple
        static let accentGreen = Color(nsColor: .systemGreen)
        static let accentBlue = Color(nsColor: .systemBlue)
        static let primaryText = Color.white.opacity(0.95)
        static let secondaryText = Color.white.opacity(0.72)
        static let tertiaryText = Color.white.opacity(0.52)
        static let weakText = Color.white.opacity(0.35)
        static let islandBackground = rootBackground
        static let islandBackgroundSoft = Color(red: 0.04, green: 0.04, blue: 0.045)
        static let cardBackground = panelBackground
        static let cardBackgroundStrong = innerCardBackground
        static let cardBackgroundDeep = innerCardActive
        static let separator = panelBorder

        static let collapsedWidth: CGFloat = 228
        static let expandedWidth: CGFloat = 880
        static let collapsedHeight: CGFloat = 30
        static let expandedOverviewHeight: CGFloat = 300
        static let expandedMusicHeight: CGFloat = 300
        static let expandedAgentHeight: CGFloat = 300
        static let expandedScheduleHeight: CGFloat = 300
        static let expandedSystemStatusHeight: CGFloat = 300
        static let topBarHeight: CGFloat = 30
        static let dashboardFooterHeight: CGFloat = 28
        static let transitionInsertScale: CGFloat = 0.995
        static let transitionRemoveScale: CGFloat = 0.997
        static let springResponse: Double = 0.30
        static let springDampingFraction: Double = 0.92
        static let windowExpandDuration: TimeInterval = 0.24
        static let windowCollapseDuration: TimeInterval = 0.20
        static let notchSafeZoneX: CGFloat = 360
        static let notchSafeZoneY: CGFloat = 0
        static let notchSafeZoneWidth: CGFloat = 236
        static let notchSafeZoneHeight: CGFloat = 30
        static let cardRadius: CGFloat = 18
        static let rightCardRadius: CGFloat = 14
        static let largeRadius: CGFloat = 24
        static let islandBottomRadius: CGFloat = 14
        static let pagePadding: CGFloat = 18
        static let cardSpacing: CGFloat = 10
        static let bottomPadding: CGFloat = 8
        static let pillRadius: CGFloat = 999
        static let smallButtonRadius: CGFloat = 14
    }

    // MARK: - Typography
    enum Typography {
        static let largeTitle = Font.system(size: 28, weight: .bold)
        static let title = Font.system(size: 22, weight: .semibold)
        static let title2 = Font.system(size: 17, weight: .semibold)
        static let title3 = Font.system(size: 15, weight: .semibold)
        static let body = Font.system(size: 13)
        static let bodyLarge = Font.system(size: 15)
        static let caption = Font.system(size: 12)
        static let captionSmall = Font.system(size: 11)
        static let monospace = Font.system(size: 13, design: .monospaced)
    }

    // MARK: - Shadows
    enum Shadows {
        static let small = ShadowStyle(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        static let medium = ShadowStyle(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        static let large = ShadowStyle(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }

    // MARK: - Animation
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let smooth = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
    }
}

// MARK: - Shadow Style

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    func apply<V: View>(_ view: V) -> some View {
        view.shadow(color: color, radius: radius, x: x, y: y)
    }
}

// MARK: - Notch 复用组件

struct NotchCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(
        cornerRadius: CGFloat = AcMindDesignTokens.Notch.cardRadius,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AcMindDesignTokens.Notch.cardBackgroundStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AcMindDesignTokens.Notch.innerBorder, lineWidth: 1)
            )
    }
}

// MARK: - View Extensions

extension View {
    func acmindCardStyle() -> some View {
        self
            .background(AcMindDesignTokens.Native.cardBackground)
            .cornerRadius(AcMindDesignTokens.Native.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AcMindDesignTokens.Native.cardRadius)
                    .stroke(AcMindDesignTokens.Native.separator, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 4)
    }

    func acmindPageStyle() -> some View {
        self
            .background(AcMindDesignTokens.Native.background)
            .ignoresSafeArea()
    }

    func acmindCapsuleStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(AcMindDesignTokens.Native.cardBackgroundStrong)
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
            )
    }
}

// MARK: - Sidebar Style

struct SidebarItemStyle: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(AcMindDesignTokens.Layout.inlineBlockRadius)
            .foregroundStyle(isSelected ? .white : .primary)
    }
}

extension View {
    func sidebarItemStyle(isSelected: Bool) -> some View {
        modifier(SidebarItemStyle(isSelected: isSelected))
    }
}

// MARK: - Product Panel Tokens

enum ProductPanelTokens {

    enum Layout {
        static let defaultWidth: CGFloat = 1160
        static let narrowWidth: CGFloat = 760
        static let pagePadding: CGFloat = 28
        static let sectionSpacing: CGFloat = 20
        static let cardSpacing: CGFloat = 14
        static let cardRadius: CGFloat = 18
        static let prominentCardRadius: CGFloat = 22
        static let compactCardRadius: CGFloat = 14
        static let iconSize: CGFloat = 30
        static let compactIconSize: CGFloat = 26
    }

    enum Typography {
        static let pageTitle = Font.system(size: 24, weight: .semibold)
        static let pageSubtitle = Font.system(size: 13, weight: .medium)
        static let cardTitle = Font.system(size: 15, weight: .semibold)
        static let cardBody = Font.system(size: 13, weight: .regular)
        static let cardCaption = Font.system(size: 11, weight: .medium)
        static let monoValue = Font.system(size: 19, weight: .semibold, design: .monospaced)
    }

    enum Animation {
        static let hover = SwiftUI.Animation.easeInOut(duration: 0.14)
        static let settle = SwiftUI.Animation.easeInOut(duration: 0.2)
    }

    struct Palette {
        let canvas: Color
        let sidebar: Color
        let surfacePrimary: Color
        let surfaceSecondary: Color
        let surfaceRaised: Color
        let surfaceInteractive: Color
        let strokeSubtle: Color
        let strokeEmphasis: Color
        let textPrimary: Color
        let textSecondary: Color
        let textTertiary: Color
        let accent: Color
        let success: Color
        let warning: Color
        let danger: Color
        let info: Color
        let agent: Color
        let muted: Color
    }

    enum StatusTone {
        case neutral
        case info
        case success
        case warning
        case danger
        case unavailable
    }

    enum CardVariant {
        case standard
        case prominent
        case compact
        case interactive
        case warning
    }

    static func palette(for colorScheme: ColorScheme, contrast: ColorSchemeContrast) -> Palette {
        let increasedContrast = contrast == .increased

        switch colorScheme {
        case .dark:
            return Palette(
                canvas: Color(red: 0.045, green: 0.05, blue: 0.06),
                sidebar: Color(red: 0.06, green: 0.065, blue: 0.08),
                surfacePrimary: Color(red: 0.085, green: 0.09, blue: 0.105),
                surfaceSecondary: Color(red: 0.11, green: 0.115, blue: 0.13),
                surfaceRaised: Color(red: 0.135, green: 0.14, blue: 0.16),
                surfaceInteractive: Color(red: 0.102, green: 0.108, blue: 0.125),
                strokeSubtle: Color.white.opacity(increasedContrast ? 0.16 : 0.09),
                strokeEmphasis: Color.white.opacity(increasedContrast ? 0.3 : 0.18),
                textPrimary: Color.white.opacity(0.95),
                textSecondary: Color.white.opacity(0.74),
                textTertiary: Color.white.opacity(0.55),
                accent: Color(red: 0.43, green: 0.63, blue: 0.98),
                success: Color(red: 0.36, green: 0.79, blue: 0.5),
                warning: Color(red: 0.97, green: 0.68, blue: 0.24),
                danger: Color(red: 0.97, green: 0.45, blue: 0.39),
                info: Color(red: 0.28, green: 0.77, blue: 0.93),
                agent: Color(red: 0.68, green: 0.55, blue: 0.98),
                muted: Color.white.opacity(0.56)
            )
        case .light:
            return Palette(
                canvas: Color(NSColor.windowBackgroundColor),
                sidebar: Color(NSColor.controlBackgroundColor),
                surfacePrimary: Color(NSColor.controlBackgroundColor),
                surfaceSecondary: Color(NSColor.controlBackgroundColor).opacity(increasedContrast ? 1.0 : 0.94),
                surfaceRaised: Color(NSColor.windowBackgroundColor),
                surfaceInteractive: Color(NSColor.controlBackgroundColor).opacity(0.88),
                strokeSubtle: Color(NSColor.separatorColor).opacity(increasedContrast ? 0.9 : 0.65),
                strokeEmphasis: Color.accentColor.opacity(increasedContrast ? 0.45 : 0.28),
                textPrimary: Color(NSColor.labelColor),
                textSecondary: Color(NSColor.secondaryLabelColor),
                textTertiary: Color(NSColor.tertiaryLabelColor),
                accent: Color.accentColor,
                success: Color(nsColor: .systemGreen),
                warning: Color(nsColor: .systemOrange),
                danger: Color(nsColor: .systemRed),
                info: Color(nsColor: .systemTeal),
                agent: Color(nsColor: .systemPurple),
                muted: Color(NSColor.tertiaryLabelColor)
            )
        @unknown default:
            return Palette(
                canvas: Color(NSColor.windowBackgroundColor),
                sidebar: Color(NSColor.controlBackgroundColor),
                surfacePrimary: Color(NSColor.controlBackgroundColor),
                surfaceSecondary: Color(NSColor.controlBackgroundColor).opacity(increasedContrast ? 1.0 : 0.94),
                surfaceRaised: Color(NSColor.windowBackgroundColor),
                surfaceInteractive: Color(NSColor.controlBackgroundColor).opacity(0.88),
                strokeSubtle: Color(NSColor.separatorColor).opacity(increasedContrast ? 0.9 : 0.65),
                strokeEmphasis: Color.accentColor.opacity(increasedContrast ? 0.45 : 0.28),
                textPrimary: Color(NSColor.labelColor),
                textSecondary: Color(NSColor.secondaryLabelColor),
                textTertiary: Color(NSColor.tertiaryLabelColor),
                accent: Color.accentColor,
                success: Color(nsColor: .systemGreen),
                warning: Color(nsColor: .systemOrange),
                danger: Color(nsColor: .systemRed),
                info: Color(nsColor: .systemTeal),
                agent: Color(nsColor: .systemPurple),
                muted: Color(NSColor.tertiaryLabelColor)
            )
        }
    }

    static func cardRadius(for variant: CardVariant) -> CGFloat {
        switch variant {
        case .standard, .interactive:
            return Layout.cardRadius
        case .prominent:
            return Layout.prominentCardRadius
        case .compact:
            return Layout.compactCardRadius
        case .warning:
            return Layout.cardRadius
        }
    }

    static func cardPadding(for variant: CardVariant) -> CGFloat {
        switch variant {
        case .standard, .interactive:
            return 16
        case .prominent:
            return 18
        case .compact:
            return 12
        case .warning:
            return 16
        }
    }

    static func cardSpacing(for variant: CardVariant) -> CGFloat {
        switch variant {
        case .compact:
            return 8
        default:
            return 10
        }
    }

    static func iconSize(for variant: CardVariant) -> CGFloat {
        switch variant {
        case .compact:
            return Layout.compactIconSize
        default:
            return Layout.iconSize
        }
    }

    static func surfaceColor(
        for variant: CardVariant,
        isSelected: Bool,
        isHovering: Bool,
        isDisabled: Bool,
        unavailableReason: String?,
        palette: Palette
    ) -> Color {
        if isDisabled {
            return palette.surfacePrimary.opacity(0.55)
        }
        if unavailableReason != nil {
            return palette.surfacePrimary
        }
        if isSelected {
            return palette.surfaceRaised
        }
        if isHovering && variant == .interactive {
            return palette.surfaceInteractive
        }
        switch variant {
        case .prominent:
            return palette.surfaceSecondary
        case .warning:
            return palette.surfaceInteractive
        default:
            return palette.surfacePrimary
        }
    }

    static func borderColor(
        for variant: CardVariant,
        isSelected: Bool,
        isHovering: Bool,
        isDisabled: Bool,
        unavailableReason: String?,
        tone: StatusTone,
        palette: Palette
    ) -> Color {
        if isDisabled {
            return palette.strokeSubtle.opacity(0.55)
        }
        if unavailableReason != nil {
            return palette.warning.opacity(0.55)
        }
        if isSelected {
            return palette.strokeEmphasis
        }
        if isHovering && variant == .interactive {
            return palette.strokeEmphasis.opacity(0.8)
        }
        switch tone {
        case .success:
            return palette.success.opacity(0.28)
        case .warning:
            return palette.warning.opacity(0.38)
        case .danger:
            return palette.danger.opacity(0.35)
        case .info:
            return palette.info.opacity(0.3)
        case .unavailable:
            return palette.warning.opacity(0.3)
        case .neutral:
            return palette.strokeSubtle
        }
    }

    static func tint(for tone: StatusTone, palette: Palette) -> Color {
        switch tone {
        case .neutral:
            return palette.accent
        case .info:
            return palette.info
        case .success:
            return palette.success
        case .warning:
            return palette.warning
        case .danger:
            return palette.danger
        case .unavailable:
            return palette.muted
        }
    }

    static func statusLabel(for tone: StatusTone) -> String {
        switch tone {
        case .neutral:
            return "Normal"
        case .info:
            return "Info"
        case .success:
            return "Ready"
        case .warning:
            return "Warning"
        case .danger:
            return "Error"
        case .unavailable:
            return "Unavailable"
        }
    }
}

enum ProductPanelCardVariant: String {
    case standard
    case prominent
    case compact
    case interactive
    case warning
}

enum ProductPanelStatusTone {
    case neutral
    case info
    case success
    case warning
    case danger
    case unavailable

    fileprivate var semanticTone: ProductPanelTokens.StatusTone {
        switch self {
        case .neutral:
            return .neutral
        case .info:
            return .info
        case .success:
            return .success
        case .warning:
            return .warning
        case .danger:
            return .danger
        case .unavailable:
            return .unavailable
        }
    }
}

struct ProductPanelCard<Content: View>: View {
    let variant: ProductPanelCardVariant
    let title: String
    let icon: String
    let status: String?
    let statusTone: ProductPanelStatusTone
    let footer: String?
    let actionTitle: String?
    let actionSystemImage: String?
    let action: (() -> Void)?
    let isSelected: Bool
    let isDisabled: Bool
    let unavailableReason: String?
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    init(
        variant: ProductPanelCardVariant = .standard,
        title: String,
        icon: String,
        status: String? = nil,
        statusTone: ProductPanelStatusTone = .neutral,
        footer: String? = nil,
        actionTitle: String? = nil,
        actionSystemImage: String? = nil,
        action: (() -> Void)? = nil,
        isSelected: Bool = false,
        isDisabled: Bool = false,
        unavailableReason: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.variant = variant
        self.title = title
        self.icon = icon
        self.status = status
        self.statusTone = statusTone
        self.footer = footer
        self.actionTitle = actionTitle
        self.actionSystemImage = actionSystemImage
        self.action = action
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.unavailableReason = unavailableReason
        self.content = content
    }

    private var resolvedVariant: ProductPanelTokens.CardVariant {
        switch variant {
        case .standard:
            return .standard
        case .prominent:
            return .prominent
        case .compact:
            return .compact
        case .interactive:
            return .interactive
        case .warning:
            return .warning
        }
    }

    private var resolvedTone: ProductPanelTokens.StatusTone {
        if unavailableReason != nil {
            return .unavailable
        }
        if variant == .warning {
            return .warning
        }
        return statusTone.semanticTone
    }

    private var currentPalette: ProductPanelTokens.Palette {
        ProductPanelTokens.palette(for: colorScheme, contrast: colorSchemeContrast)
    }

    private var isEffectivelyHovered: Bool {
        variant == .interactive && isHovering && isDisabled == false && unavailableReason == nil
    }

    private var cardRadius: CGFloat {
        ProductPanelTokens.cardRadius(for: resolvedVariant)
    }

    private var cardPadding: CGFloat {
        ProductPanelTokens.cardPadding(for: resolvedVariant)
    }

    private var cardSpacing: CGFloat {
        ProductPanelTokens.cardSpacing(for: resolvedVariant)
    }

    private var iconSize: CGFloat {
        ProductPanelTokens.iconSize(for: resolvedVariant)
    }

    private var statusText: String? {
        if let unavailableReason {
            return unavailableReason
        }
        return status
    }

    var body: some View {
        let palette = currentPalette
        let radius = cardRadius
        let background = ProductPanelTokens.surfaceColor(
            for: resolvedVariant,
            isSelected: isSelected,
            isHovering: isEffectivelyHovered,
            isDisabled: isDisabled,
            unavailableReason: unavailableReason,
            palette: palette
        )
        let border = ProductPanelTokens.borderColor(
            for: resolvedVariant,
            isSelected: isSelected,
            isHovering: isEffectivelyHovered,
            isDisabled: isDisabled,
            unavailableReason: unavailableReason,
            tone: resolvedTone,
            palette: palette
        )

        VStack(alignment: .leading, spacing: cardSpacing) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: max(10, radius * 0.45), style: .continuous)
                        .fill(ProductPanelTokens.tint(for: resolvedTone, palette: palette).opacity(0.18))
                    Image(systemName: icon)
                        .font(.system(size: resolvedVariant == .compact ? 12 : 13, weight: .semibold))
                        .foregroundStyle(ProductPanelTokens.tint(for: resolvedTone, palette: palette))
                }
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(ProductPanelTokens.Typography.cardTitle)
                            .foregroundStyle(palette.textPrimary)
                            .lineLimit(1)

                        if statusText != nil {
                            Text(ProductPanelTokens.statusLabel(for: resolvedTone))
                                .font(ProductPanelTokens.Typography.cardCaption)
                                .foregroundStyle(ProductPanelTokens.tint(for: resolvedTone, palette: palette))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(ProductPanelTokens.tint(for: resolvedTone, palette: palette).opacity(0.16))
                                )
                        }
                    }

                    if let statusText {
                        Text(statusText)
                            .font(ProductPanelTokens.Typography.cardCaption)
                            .foregroundStyle(isDisabled ? palette.textTertiary : palette.textSecondary)
                            .lineLimit(resolvedVariant == .compact ? 1 : 2)
                    }
                }

                Spacer(minLength: 0)

                if let actionTitle, isDisabled == false, unavailableReason == nil {
                    Button {
                        action?()
                    } label: {
                        Label(actionTitle, systemImage: actionSystemImage ?? "arrow.right")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ProductPanelTokens.tint(for: resolvedTone, palette: palette))
                    .controlSize(.small)
                } else if let actionTitle {
                    Text(actionTitle)
                        .font(ProductPanelTokens.Typography.cardCaption)
                        .foregroundStyle(palette.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(palette.surfaceSecondary)
                        )
                }
            }

            content()
                .font(ProductPanelTokens.Typography.cardBody)
                .foregroundStyle(isDisabled ? palette.textTertiary : palette.textPrimary)

            if let footer {
                Text(footer)
                    .font(ProductPanelTokens.Typography.cardCaption)
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(border, lineWidth: colorSchemeContrast == .increased ? 1.5 : 1)
        )
        .opacity(isDisabled ? 0.62 : 1)
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .onHover { hovering in
            guard variant == .interactive, isDisabled == false, unavailableReason == nil else { return }
            let update = {
                isHovering = hovering
            }
            if reduceMotion {
                update()
            } else {
                withAnimation(ProductPanelTokens.Animation.hover) {
                    update()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(accessibilityValueText))
    }

    private var accessibilityValueText: String {
        var parts: [String] = []
        if let statusText {
            parts.append(statusText)
        }
        if isSelected {
            parts.append("Selected")
        }
        if isDisabled {
            parts.append("Disabled")
        }
        if let unavailableReason {
            parts.append(unavailableReason)
        }
        return parts.isEmpty ? ProductPanelTokens.statusLabel(for: resolvedTone) : parts.joined(separator: ", ")
    }
}

#if DEBUG
struct ProductPanelPreviewSample: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let palette = ProductPanelTokens.palette(for: colorScheme, contrast: colorSchemeContrast)

        GeometryReader { proxy in
            let isNarrow = proxy.size.width < ProductPanelTokens.Layout.defaultWidth * 0.72
            let columns = Array(
                repeating: GridItem(.flexible(), spacing: ProductPanelTokens.Layout.cardSpacing, alignment: .top),
                count: isNarrow ? 1 : 2
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: ProductPanelTokens.Layout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Product Panel")
                            .font(ProductPanelTokens.Typography.pageTitle)
                            .foregroundStyle(palette.textPrimary)
                        Text("Isolated surface tokens, foundation cards, and width-aware layouts.")
                            .font(ProductPanelTokens.Typography.pageSubtitle)
                            .foregroundStyle(palette.textSecondary)
                    }

                    LazyVGrid(columns: columns, alignment: .leading, spacing: ProductPanelTokens.Layout.cardSpacing) {
                        ProductPanelCard(
                            variant: .standard,
                            title: "System Overview",
                            icon: "rectangle.grid.2x2",
                            status: "Ready",
                            statusTone: .success,
                            footer: "Updated 2 minutes ago"
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("CPU 42% · Memory 58% · Network stable")
                                Text("This card keeps the main metric first, then explanation and timing.")
                                    .foregroundStyle(palette.textSecondary)
                            }
                        }

                        ProductPanelCard(
                            variant: .prominent,
                            title: "Agent Queue",
                            icon: "sparkles",
                            status: "Needs attention",
                            statusTone: .warning,
                            footer: "2 approvals pending",
                            actionTitle: "Open",
                            actionSystemImage: "arrow.right"
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("1 task is waiting for a response, 3 are running, and 1 is blocked.")
                                Text("The promoted surface keeps the primary action visible without turning into a dashboard wall.")
                                    .foregroundStyle(palette.textSecondary)
                            }
                        }

                        ProductPanelCard(
                            variant: .compact,
                            title: "Clipboard Shelf",
                            icon: "doc.on.clipboard",
                            status: "No selection yet",
                            statusTone: .neutral,
                            footer: "Compact cards keep dense contexts readable"
                        ) {
                            Text("Pinned items will appear here once the user starts selecting content.")
                        }

                        ProductPanelCard(
                            variant: .interactive,
                            title: "Network Probe",
                            icon: "dot.radiowaves.left.and.right",
                            status: "Unavailable",
                            statusTone: .unavailable,
                            footer: "Requires network permission and a detected interface",
                            actionTitle: "Check setup",
                            actionSystemImage: "arrow.up.right"
                        ) {
                            Text("The unavailable state explains why the card cannot yet provide a signal.")
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        ProductPanelCard(
                            variant: .warning,
                            title: "Storage Health",
                            icon: "externaldrive.badge.exclamationmark",
                            status: "Watch closely",
                            statusTone: .warning,
                            footer: "Stale readings must never masquerade as fresh data"
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("A slow reader is still acceptable, but the state must stay explicit.")
                                Text("Reduced motion and higher contrast should still keep this surface readable.")
                                    .foregroundStyle(palette.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .padding(ProductPanelTokens.Layout.pagePadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(palette.canvas.ignoresSafeArea())
    }
}

#Preview("Product Panel / Wide") {
    ProductPanelPreviewSample()
        .preferredColorScheme(.dark)
        .frame(width: ProductPanelTokens.Layout.defaultWidth, height: 820)
}

#Preview("Product Panel / Narrow") {
    ProductPanelPreviewSample()
        .preferredColorScheme(.dark)
        .frame(width: ProductPanelTokens.Layout.narrowWidth, height: 920)
}
#endif
