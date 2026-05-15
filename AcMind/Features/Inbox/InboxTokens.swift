import SwiftUI

enum InboxLayout {
    static let sidebarWidth: CGFloat = 244
    static let workspacePaddingX: CGFloat = 28
    static let headerHeight: CGFloat = 92
    static let detailPanelWidth: CGFloat = 486
    static let listContentPaddingX: CGFloat = 28
    static let listTopPadding: CGFloat = 20
    static let cardRadius: CGFloat = 16
    static let smallRadius: CGFloat = 12
    static let pillRadius: CGFloat = 999
    static let listRowHeight: CGFloat = 96
    static let listRowIconSize: CGFloat = 42
    static let listRowHorizontalPadding: CGFloat = 18
    static let detailPaddingX: CGFloat = 28
    static let detailPaddingTop: CGFloat = 28
    static let searchWidth: CGFloat = 260
    static let searchHeight: CGFloat = 36
    static let newButtonWidth: CGFloat = 72
    static let newButtonHeight: CGFloat = 32
    static let categoryTabHeight: CGFloat = 30
    static let sortButtonWidth: CGFloat = 106
    static let sortButtonHeight: CGFloat = 32
    static let filterButtonWidth: CGFloat = 40
    static let detailCardWidth: CGFloat = 430
}

enum InboxColors {
    static let pageBackground = Color(hex: "#F6F7F9")
    static let sidebarBackground = Color(hex: "#F2F3F5")
    static let cardBackground = Color(hex: "#FFFFFF")
    static let primaryText = Color(hex: "#111111")
    static let secondaryText = Color(hex: "#666666")
    static let tertiaryText = Color(hex: "#999999")
    static let border = Color(hex: "#E5E7EB")
    static let softBorder = Color(hex: "#EEEEEE")
    static let softFill = Color(hex: "#F3F4F6")
    static let selectedFill = Color(hex: "#F0F4FF")
    static let accentBlue = Color(hex: "#0A84FF")
    static let accentPurple = Color(hex: "#A855F7")
    static let accentGreen = Color(hex: "#34C759")
    static let accentOrange = Color(hex: "#FF9500")
    static let accentRed = Color(hex: "#FF3B30")
    static let accentTeal = Color(hex: "#14B8A6")
    
    static let voiceBackground = Color(hex: "#FFF3E8")
    static let voiceIconColor = Color(hex: "#FF9500")
    static let taskBackground = Color(hex: "#F3E8FF")
    static let taskIconColor = Color(hex: "#A855F7")
    static let markdownBackground = Color(hex: "#E8F1FF")
    static let markdownIconColor = Color(hex: "#0A84FF")
    static let documentBackground = Color(hex: "#E8F1FF")
    static let documentIconColor = Color(hex: "#0A84FF")
    static let imageBackground = Color(hex: "#FFE8EE")
    static let imageIconColor = Color(hex: "#FF2D55")
    
    static let pendingBackground = Color(hex: "#FFF3E8")
    static let pendingText = Color(hex: "#FF9500")
    static let completedBackground = Color(hex: "#E8F8EF")
    static let completedText = Color(hex: "#34C759")
    static let archivedBackground = Color(hex: "#E8F1FF")
    static let archivedText = Color(hex: "#0A84FF")
}

enum InboxTypography {
    static let pageTitle = Font.system(size: 28, weight: .semibold)
    static let pageSubtitle = Font.system(size: 14, weight: .regular)
    static let sectionTitle = Font.system(size: 15, weight: .semibold)
    static let itemTitle = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 13, weight: .regular)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 12, weight: .regular)
    static let mini = Font.system(size: 11, weight: .regular)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}