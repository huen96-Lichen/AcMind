import SwiftUI

enum WorkbenchV2Metrics {
    static let defaultWindowWidth: CGFloat = 1500
    static let defaultWindowHeight: CGFloat = 920
    // 不包含 macOS 标题栏
    static let defaultContentWidth: CGFloat = 1500
    static let defaultContentHeight: CGFloat = 888
    static let titleBarHeight: CGFloat = 32
    static let minimumWindowWidth: CGFloat = 1180
    static let minimumWindowHeight: CGFloat = 720
    static let sidebarWidth: CGFloat = 216
    static let separatorWidth: CGFloat = 1
}

enum WorkbenchV2Routing {
#if DEBUG
    static let defaultUseWorkbenchV2 = true
#else
    static let defaultUseWorkbenchV2 = false
#endif
}

enum WorkbenchV2Tokens {
    enum Layout {
        static let sidebarWidth: CGFloat = WorkbenchV2Metrics.sidebarWidth
        static let separatorWidth: CGFloat = WorkbenchV2Metrics.separatorWidth
        // 16pt leaves a visible 12pt rhythm after the soft card shadows overlap the gutter.
        static let containerGap: CGFloat = 16
        static let pagePaddingTop: CGFloat = containerGap
        static let pagePaddingLeading: CGFloat = 24
        static let pagePaddingBottom: CGFloat = containerGap
        static let pagePaddingTrailing: CGFloat = 24
        static let contentWidth: CGFloat = 1235
        static let headerHeight: CGFloat = 48
        static let headerBottomGap: CGFloat = containerGap
        static let dashboardColumnGap: CGFloat = containerGap
        static let dashboardRowGap: CGFloat = containerGap
        static let footerHeight: CGFloat = 56
        static let compactContentPadding: CGFloat = 16
        static let compactRightColumnWidth: CGFloat = 252
        static let compactColumnGap: CGFloat = containerGap
        static let compactInnerPadding: CGFloat = 16
        static let compactBodyHeight: CGFloat = 520
        static let compactFooterHeight: CGFloat = 52
        static let compactHeaderHeight: CGFloat = 44
        static let heroHeight: CGFloat = 232
        static let secondaryCardHeight: CGFloat = 196
        static let trendHeight: CGFloat = 170
        static let compactHeroHeight: CGFloat = 204
        static let compactSecondaryCardHeight: CGFloat = 196
        static let compactTrendHeight: CGFloat = 128
        static let todayOverviewHeight: CGFloat = 480
        static let quickActionsHeight: CGFloat = 210
        static let compactTodayOverviewHeight: CGFloat = 366
        static let compactQuickActionsHeight: CGFloat = 188
        static let heroButtonHeight: CGFloat = 26
        static let heroPrimaryActionHeight: CGFloat = 34
        static let heroSecondaryActionHeight: CGFloat = 34
        static let heroMetaBlockHeight: CGFloat = 36
        static let heroSummaryBlockHeight: CGFloat = 32
        static let overviewTileHeight: CGFloat = 66
        static let overviewToggleHeight: CGFloat = 46
        static let overviewStatusHeight: CGFloat = 56
        static let quickActionTileHeight: CGFloat = 46
        static let quickActionGridSpacing: CGFloat = 10
        static let overviewTileSpacing: CGFloat = 8
        static let deviceStatusDotSize: CGFloat = 7
        static let deviceStatusDividerHeight: CGFloat = 22
        static let deviceStatusDetailsButtonHeight: CGFloat = 28
    }

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    enum Radius {
        static let panel: CGFloat = 16
        static let card: CGFloat = 16
        static let chip: CGFloat = 12
        static let small: CGFloat = 12
        static let control: CGFloat = 10
    }

    enum Typography {
        static let pageTitle: CGFloat = 24
        static let headerKicker: CGFloat = 12
        static let sectionTitle: CGFloat = 15
        static let cardTitle: CGFloat = 14
        static let body: CGFloat = 13
        static let caption: CGFloat = 11
        static let data: CGFloat = 28
        static let value: CGFloat = 19
        static let tiny: CGFloat = 10
    }

    enum Color {
        static let background = SwiftUI.Color(nsColor: .windowBackgroundColor)
        static let surface = SwiftUI.Color(nsColor: .controlBackgroundColor)
        static let surfaceSoft = SwiftUI.Color(nsColor: .underPageBackgroundColor)
        static let surfaceStrong = SwiftUI.Color(nsColor: .textBackgroundColor)
        static let separator = SwiftUI.Color(nsColor: .separatorColor)
        static let textPrimary = SwiftUI.Color(nsColor: .labelColor)
        static let textSecondary = SwiftUI.Color(nsColor: .secondaryLabelColor)
        static let textTertiary = SwiftUI.Color(nsColor: .tertiaryLabelColor)
        static let accent = SwiftUI.Color(nsColor: .systemBlue)
        static let accentGreen = SwiftUI.Color(nsColor: .systemGreen)
        static let accentOrange = SwiftUI.Color(nsColor: .systemOrange)
        static let accentTeal = SwiftUI.Color(nsColor: .systemTeal)
        static let heroTextPrimary = SwiftUI.Color.white
        static let heroTextSecondary = SwiftUI.Color.white.opacity(0.84)
        static let heroTextTertiary = SwiftUI.Color.white.opacity(0.66)
        static let heroTextMuted = SwiftUI.Color.white.opacity(0.48)
        static let heroSurface = SwiftUI.Color.white.opacity(0.08)
        static let heroSurfaceStrong = SwiftUI.Color.white.opacity(0.14)
        static let heroSurfaceBorder = SwiftUI.Color.white.opacity(0.18)
        static let heroButtonPrimaryFill = SwiftUI.Color.white
        static let heroButtonPrimaryText = SwiftUI.Color.black.opacity(0.92)
        static let heroButtonSecondaryFill = SwiftUI.Color.white.opacity(0.12)
        static let heroButtonSecondaryText = SwiftUI.Color.white
        static let heroButtonSecondaryBorder = SwiftUI.Color.white.opacity(0.22)
        static let heroBackgroundMaskLeading = SwiftUI.Color.black.opacity(0.92)
        static let heroBackgroundMaskMiddle = SwiftUI.Color.black.opacity(0.72)
        static let heroBackgroundMaskTrailing = SwiftUI.Color.black.opacity(0.24)
        static let heroBackgroundShade = SwiftUI.Color.black.opacity(0.18)
    }

    enum Border {
        static let width: CGFloat = 1
    }

    enum Shadow {
        static let radius: CGFloat = 0
        static let x: CGFloat = 0
        static let y: CGFloat = 0
        static let opacity: Double = 0.0
    }
}

enum WorkbenchV2State: String, CaseIterable, Identifiable {
    case empty
    case normal
    case warning

    var id: String { rawValue }
}

struct WorkbenchV2Badge: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let systemImage: String
    let tint: Color
}
