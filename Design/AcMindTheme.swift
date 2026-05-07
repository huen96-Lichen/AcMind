import SwiftUI

enum AcMindTheme {
    static let primary = Color.accentColor

    static let background = Color(NSColor.windowBackgroundColor)
    static let secondaryBackground = Color(NSColor.controlBackgroundColor)
    static let tertiaryBackground = Color(NSColor.underPageBackgroundColor)

    static let text = Color(NSColor.labelColor)
    static let secondaryText = Color(NSColor.secondaryLabelColor)
    static let tertiaryText = Color(NSColor.tertiaryLabelColor)

    static let border = Color(NSColor.separatorColor)
    static let divider = Color(NSColor.gridColor)

    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue

    static let cornerRadius: CGFloat = 8
    static let smallCornerRadius: CGFloat = 4
    static let largeCornerRadius: CGFloat = 12

    static let spacing: CGFloat = 16
    static let smallSpacing: CGFloat = 8
    static let largeSpacing: CGFloat = 24

    static let padding: CGFloat = 16
    static let smallPadding: CGFloat = 8
    static let largePadding: CGFloat = 24
}

extension View {
    func acmindCardStyle() -> some View {
        self
            .background(AcMindTheme.secondaryBackground)
            .cornerRadius(AcMindTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AcMindTheme.cornerRadius)
                    .stroke(AcMindTheme.border, lineWidth: 1)
            )
    }
}
