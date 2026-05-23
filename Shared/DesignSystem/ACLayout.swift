import SwiftUI

enum ACLayout {
    // MARK: - Window Size
    static let windowMinWidth: CGFloat = 960
    static let windowIdealWidth: CGFloat = 1250
    static let windowMaxReferenceWidth: CGFloat = 1728
    static let windowMinHeight: CGFloat = 650
    static let windowIdealHeight: CGFloat = 650
    static let windowMaxReferenceHeight: CGFloat = 1117

    // MARK: - Responsive Breakpoints
    enum Breakpoint {
        static let compact: CGFloat = 1024
        static let regular: CGFloat = 1200
        static let wide: CGFloat = 1440
    }

    // MARK: - Minimum Width Calculation
    static func minWindowWidth(for railStyle: RailStyle) -> CGFloat {
        switch railStyle {
        case .compact:
            return primaryRailCompact + 32
        case .expanded:
            return primaryRailExpanded + mainContentMinWidth + 32
        }
    }

    // MARK: - Workspace Layout Modes
    enum WorkspaceLayoutMode {
        case tripleColumn
        case doubleColumn
        case singleColumn
    }

    static func workspaceLayoutMode(for width: CGFloat) -> WorkspaceLayoutMode {
        if width >= Breakpoint.wide {
            return .tripleColumn
        } else if width >= Breakpoint.regular {
            return .doubleColumn
        } else {
            return .singleColumn
        }
    }

    // MARK: - Settings Layout Modes
    enum SettingsLayoutMode {
        case withSidebar
        case stacked
    }

    static func settingsLayoutMode(for width: CGFloat) -> SettingsLayoutMode {
        if width >= Breakpoint.compact {
            return .withSidebar
        } else {
            return .stacked
        }
    }

    static func secondaryPageLayoutMode(for width: CGFloat) -> SettingsLayoutMode {
        settingsLayoutMode(for: width)
    }

    // MARK: - Rail Style
    enum RailStyle {
        case compact
        case expanded
    }

    static func railStyle(for width: CGFloat) -> RailStyle {
        if width >= Breakpoint.regular {
            return .expanded
        } else {
            return .compact
        }
    }

    static let sidebarWidth: CGFloat = 244
    static let secondarySidebarWidth: CGFloat = 248
    static let pagePaddingX: CGFloat = 28
    static let pagePaddingY: CGFloat = 24
    static let pagePaddingBottom: CGFloat = 28
    static let pageHorizontalPadding: CGFloat = 28

    static let headerHeightLarge: CGFloat = 96
    static let headerHeightMedium: CGFloat = 76
    static let headerHeightCompact: CGFloat = 56

    static let gapXS: CGFloat = 4
    static let gapS: CGFloat = 8
    static let gapM: CGFloat = 12
    static let gapL: CGFloat = 16
    static let gapXL: CGFloat = 20
    static let gapXXL: CGFloat = 24
    static let gapPage: CGFloat = 28

    static let controlHeightS: CGFloat = 28
    static let controlHeightM: CGFloat = 32
    static let controlHeightL: CGFloat = 36
    static let controlHeightXL: CGFloat = 38

    static let iconS: CGFloat = 14
    static let iconM: CGFloat = 16
    static let iconL: CGFloat = 18
    static let iconXL: CGFloat = 24

    static let listRowCompact: CGFloat = 64
    static let listRowMedium: CGFloat = 76
    static let listRowLarge: CGFloat = 96
    static let listRowHeight: CGFloat = 76
    static let statCardHeight: CGFloat = 74

    static let sidebarNavHeight: CGFloat = 48
    static let sidebarNavWidth: CGFloat = 212
    static let sidebarUserHeight: CGFloat = 52
    static let sidebarUserWidth: CGFloat = 212

    static let searchFieldWidth: CGFloat = 260
    static let searchFieldWideWidth: CGFloat = 340
    static let searchFieldHeight: CGFloat = 36
    static let searchFieldWideHeight: CGFloat = 38

    static let buttonHeightS: CGFloat = 28
    static let buttonHeightM: CGFloat = 32
    static let buttonHeightL: CGFloat = 36
    static let buttonHeightXL: CGFloat = 38

    static let detailPanelWidth: CGFloat = 430
    static let detailPanelWideWidth: CGFloat = 486
    static let mainContentMinWidth: CGFloat = 560
    static let maxReadableContentWidth: CGFloat = 1440
    static let maxCardContentWidth: CGFloat = 1280

    static let cardRadius: CGFloat = 18
    static let smallRadius: CGFloat = 12
    static let controlRadius: CGFloat = 10
    static let badgeRadius: CGFloat = 8
    static let tinyRadius: CGFloat = 6
    static let capsuleRadius: CGFloat = 999

    static let borderWidth: CGFloat = 1

    static let secondaryPageMaxWidth: CGFloat = 1512
    static let secondaryPageContentMaxWidth: CGFloat = 1060
    static let workspaceContentMaxWidth: CGFloat = 1280
    static let secondaryPageHeaderHeight: CGFloat = 76

    static let shellGutter: CGFloat = 24
    static let panelGap: CGFloat = 16
    static let sectionGap: CGFloat = 20
    static let cardGap: CGFloat = 12
    static let radiusShell: CGFloat = 28
    static let radiusPanel: CGFloat = 24
    static let radiusPill: CGFloat = 999
    static let pageHeaderHeight: CGFloat = 76
    static let toolbarHeight: CGFloat = 44
    static let controlHeight: CGFloat = 40
    static let primaryRailCompact: CGFloat = 52
    static let primaryRailExpanded: CGFloat = 152
    static let primaryRailMaxWidth: CGFloat = 208
    static let primaryRailDragHandleWidth: CGFloat = 10
    static let primaryRailContentGap: CGFloat = 24
    static let primaryRailBrandHeight: CGFloat = 52
    static let primaryRailNavItemHeight: CGFloat = 36
    static let primaryRailFooterHeight: CGFloat = 30
    static let primaryRailLabelThreshold: CGFloat = 96
    static let inspectorWidth: CGFloat = 320
    static let workspaceLeftPanel: CGFloat = 360
    static let workspaceMainMin: CGFloat = 520
}

typealias ACDimension = ACLayout
