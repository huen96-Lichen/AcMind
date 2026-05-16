import SwiftUI

enum ACColors {
    static let pageBackground = Color(acHex: "#F6F7F9")
    static let sidebarBackground = Color(acHex: "#F2F3F5")
    static let cardBackground = Color(acHex: "#FFFFFF")
    static let elevatedBackground = Color(acHex: "#FFFFFF")

    static let primaryText = Color(acHex: "#111111")
    static let secondaryText = Color(acHex: "#666666")
    static let tertiaryText = Color(acHex: "#999999")
    static let quaternaryText = Color(acHex: "#B8B8B8")

    static let border = Color(acHex: "#E5E7EB")
    static let softBorder = Color(acHex: "#EEEEEE")
    static let divider = Color(acHex: "#EEEEEE")
    static let softFill = Color(acHex: "#F3F4F6")
    static let selectedFill = Color(acHex: "#E8F1FF")

    static let accentBlue = Color(acHex: "#0A84FF")
    static let accentPurple = Color(acHex: "#A855F7")
    static let accentGreen = Color(acHex: "#34C759")
    static let accentOrange = Color(acHex: "#FF9500")
    static let accentRed = Color(acHex: "#FF3B30")
    static let accentYellow = Color(acHex: "#FFCC00")
    static let accentTeal = Color(acHex: "#14B8A6")
    static let accentYellowText = Color(acHex: "#8A6D00")

    static let blackCapsule = Color(acHex: "#050505")
    static let darkCard = Color(acHex: "#1D1D1F")

    static let bgWindow = Color(acHex: "#F5F6F8")
    static let bgShell = Color.white.opacity(0.72)
    static let bgPanelSoft = Color(acHex: "#F7F8FA")
    static let bgHover = Color(acHex: "#F2F3F5")
    static let borderStrong = Color(acHex: "#D1D5DB")
    static let shadowCard = Color.black.opacity(0.05)
}

typealias ACColor = ACColors

extension Color {
    init(acHex: String) {
        let hex = acHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
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
