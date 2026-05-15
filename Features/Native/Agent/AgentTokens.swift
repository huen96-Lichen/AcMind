import SwiftUI

enum AgentLayout {
    static let sidebarWidth: CGFloat = ACLayout.sidebarWidth
    static let workspacePaddingX: CGFloat = ACLayout.pagePaddingX
    static let workspacePaddingBottom: CGFloat = ACLayout.pagePaddingBottom
    static let headerHeight: CGFloat = ACLayout.headerHeightMedium
    static let leftPanelWidth: CGFloat = 300
    static let rightPanelWidth: CGFloat = 280
    static let columnGap: CGFloat = ACLayout.gapL
    static let cardRadius: CGFloat = ACLayout.cardRadius
    static let smallRadius: CGFloat = ACLayout.smallRadius
    static let pillRadius: CGFloat = ACLayout.capsuleRadius
    static let leftPanelTop: CGFloat = 0
    static let mainPanelMinWidth: CGFloat = 640
    static let chatInputHeight: CGFloat = 116
    static let mainContentGap: CGFloat = ACLayout.gapL
}

enum AgentColors {
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
    static let progressPurple = ACColors.accentPurple
}

enum AgentTypography {
    static let pageTitle = Font.system(size: 26, weight: .semibold)
    static let pageSubtitle = Font.system(size: 14, weight: .regular)
    static let panelTitle = Font.system(size: 15, weight: .semibold)
    static let sectionTitle = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 13, weight: .regular)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 12, weight: .regular)
    static let mini = Font.system(size: 11, weight: .regular)
}

struct AgentShadow {
    static let cardColor = Color.black.opacity(0.04)
    static let cardRadius: CGFloat = 8
    static let cardOffsetY: CGFloat = 2
}

extension View {
    func agentCardStyle() -> some View {
        self
            .background(AgentColors.cardBackground)
            .cornerRadius(AgentLayout.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AgentLayout.cardRadius)
                    .stroke(AgentColors.border, lineWidth: 1)
            )
    }
    
    func agentSmallCardStyle() -> some View {
        self
            .background(AgentColors.cardBackground)
            .cornerRadius(AgentLayout.smallRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AgentLayout.smallRadius)
                    .stroke(AgentColors.border, lineWidth: 1)
            )
    }
}
