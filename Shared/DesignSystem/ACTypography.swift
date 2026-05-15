import SwiftUI

enum ACTypography {
    static let pageTitle = Font.system(size: 28, weight: .semibold)
    static let pageTitleLineHeight: CGFloat = 34

    static let sectionTitle = Font.system(size: 20, weight: .semibold)
    static let cardTitle = Font.system(size: 16, weight: .semibold)
    static let panelTitle = Font.system(size: 15, weight: .semibold)

    static let itemTitle = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 13, weight: .regular)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 12, weight: .regular)
    static let captionMedium = Font.system(size: 12, weight: .medium)
    static let mini = Font.system(size: 11, weight: .regular)
    static let miniMedium = Font.system(size: 11, weight: .medium)
    static let badge = Font.system(size: 11, weight: .medium)
    static let button = Font.system(size: 13, weight: .semibold)
    static let monospacedMini = Font.system(size: 11, weight: .medium, design: .monospaced)
}
