import SwiftUI

private func ccColor(_ hex: String) -> Color {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let r, g, b: UInt64
    switch hex.count {
    case 6:
        (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
    default:
        (r, g, b) = (0, 0, 0)
    }
    return Color(
        .sRGB,
        red: Double(r) / 255,
        green: Double(g) / 255,
        blue: Double(b) / 255,
        opacity: 1
    )
}

enum ContinentConfigTokens {
    static let pageBackground = ccColor("#F6F7F9")
    static let cardBackground = ccColor("#FFFFFF")
    static let primaryText = ccColor("#111111")
    static let secondaryText = ccColor("#777777")
    static let tertiaryText = ccColor("#AAAAAA")
    static let border = ccColor("#E5E7EB")
    static let softFill = ccColor("#F3F4F6")
    static let blackCapsule = ccColor("#050505")
    static let blackCard = ccColor("#1D1D1F")
    static let accentBlue = ccColor("#0A84FF")
    static let accentGreen = ccColor("#30D158")
    static let accentOrange = ccColor("#FF9500")
    static let accentRed = ccColor("#FF3B30")
    static let accentPurple = ccColor("#BF5AF2")
    
    static let shadowColor = Color.black.opacity(0.035)
}

enum ContinentConfigLayout {
    static let sidebarWidth: CGFloat = 244
    static let mainPaddingX: CGFloat = 32
    static let mainPaddingTop: CGFloat = 22
    static let mainPaddingBottom: CGFloat = 28
    static let headerHeight: CGFloat = 72
    static let gridGap: CGFloat = 16
    static let cardRadius: CGFloat = 16
    static let cardPadding: CGFloat = 20
    static let firstRowHeight: CGFloat = 286
    static let secondRowHeight: CGFloat = 350
    static let functionModuleHeight: CGFloat = 156
    static let debugBarHeight: CGFloat = 56
    static let previewLeftWidth: CGFloat = 560
    static let linkRulesWidth: CGFloat = 288
    static let componentSelectionWidth: CGFloat = 720
    static let blockManagerWidth: CGFloat = 220
}

enum ContinentConfigTypography {
    static let pageTitle = Font.system(size: 28, weight: .semibold)
    static let pageSubtitle = Font.system(size: 14, weight: .regular)
    static let cardTitle = Font.system(size: 16, weight: .semibold)
    static let cardSubtitle = Font.system(size: 12, weight: .regular)
    static let itemTitle = Font.system(size: 13, weight: .semibold)
    static let itemSubtitle = Font.system(size: 11, weight: .regular)
    static let miniLabel = Font.system(size: 10, weight: .medium)
}