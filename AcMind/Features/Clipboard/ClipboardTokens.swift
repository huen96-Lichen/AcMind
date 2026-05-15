import SwiftUI

enum ClipboardLayout {
    static let appSidebarWidth: CGFloat = ACDimension.sidebarWidth
    static let workspacePaddingX: CGFloat = ACDimension.pagePaddingX
    static let workspacePaddingBottom: CGFloat = ACDimension.pagePaddingBottom
    static let headerHeight: CGFloat = ACDimension.headerHeightLarge
    static let statsBarHeight: CGFloat = ACDimension.headerHeightLarge
    static let categorySidebarWidth: CGFloat = 220
    static let detailPanelWidth: CGFloat = ACDimension.detailPanelWidth
    static let mainColumnGap: CGFloat = ACDimension.gapL
    static let cardRadius: CGFloat = ACDimension.cardRadius
    static let smallRadius: CGFloat = ACDimension.smallRadius
    static let tinyRadius: CGFloat = ACDimension.tinyRadius
    static let pillRadius: CGFloat = ACDimension.capsuleRadius
    static let statCardHeight: CGFloat = ACDimension.statCardHeight
    static let categoryPanelTop: CGFloat = 0
    static let listToolbarHeight: CGFloat = 48
    static let listRowHeight: CGFloat = ACDimension.listRowMedium
    static let listRowIconSize: CGFloat = 48
    static let detailPadding: CGFloat = 20
    static let detailPreviewHeight: CGFloat = 250
    static let searchWidth: CGFloat = 340
    static let searchHeight: CGFloat = 38
    static let addButtonWidth: CGFloat = 78
    static let addButtonHeight: CGFloat = 38
}

enum ClipboardColors {
    static let pageBackground = ACColors.pageBackground
    static let sidebarBackground = ACColors.sidebarBackground
    static let cardBackground = ACColors.cardBackground
    static let primaryText = ACColors.primaryText
    static let secondaryText = ACColors.secondaryText
    static let tertiaryText = ACColors.tertiaryText
    static let border = ACColors.border
    static let softBorder = ACColors.softBorder
    static let softFill = ACColors.softFill
    static let selectedFill = ACColors.selectedFill
    static let accentBlue = ACColors.accentBlue
    static let accentPurple = ACColors.accentPurple
    static let accentGreen = ACColors.accentGreen
    static let accentOrange = ACColors.accentOrange
    static let accentRed = ACColors.accentRed
    static let accentYellow = ACColors.accentYellow
    static let accentTeal = ACColors.accentTeal
    static let textTypeFill = ACColors.selectedFill
    static let imageTypeFill = ACColors.accentPurple.opacity(0.12)
    static let linkTypeFill = ACColors.accentGreen.opacity(0.12)
    static let fileTypeFill = ACColors.accentPurple.opacity(0.12)
    static let codeTypeFill = ACColors.accentOrange.opacity(0.12)
}

enum ClipboardTypography {
    static let pageTitle = ACTypography.pageTitle
    static let pageSubtitle = ACTypography.caption
    static let statNumber = Font.system(size: 26, weight: .semibold)
    static let statTitle = ACTypography.captionMedium
    static let statSubtitle = ACTypography.caption
    static let sectionTitle = ACTypography.panelTitle
    static let itemTitle = ACTypography.itemTitle
    static let body = ACTypography.body
    static let bodyMedium = ACTypography.bodyMedium
    static let caption = ACTypography.caption
    static let mini = ACTypography.mini
}
