import SwiftUI

struct ACBadge: View {
    enum Kind {
        case neutral
        case blue
        case purple
        case green
        case orange
        case red
        case yellow
        case disabled
    }

    let title: String
    let kind: Kind

    init(_ title: String, kind: Kind = .neutral) {
        self.title = title
        self.kind = kind
    }

    var body: some View {
        Text(title)
            .font(ACTypography.badge)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: ACLayout.radiusPill, style: .continuous))
    }

    private var backgroundColor: Color {
        switch kind {
        case .neutral:
            return ACColors.softFill
        case .blue:
            return ACColors.selectedFill
        case .purple:
            return ACColors.accentPurple.opacity(0.12)
        case .green:
            return ACColors.accentGreen.opacity(0.12)
        case .orange:
            return ACColors.accentOrange.opacity(0.14)
        case .red:
            return ACColors.accentRed.opacity(0.12)
        case .yellow:
            return ACColors.accentYellow.opacity(0.16)
        case .disabled:
            return ACColors.softFill
        }
    }

    private var foregroundColor: Color {
        switch kind {
        case .neutral:
            return ACColors.secondaryText
        case .blue:
            return ACColors.accentBlue
        case .purple:
            return ACColors.accentPurple
        case .green:
            return ACColors.accentGreen
        case .orange:
            return ACColors.accentOrange
        case .red:
            return ACColors.accentRed
        case .yellow:
            return ACColors.accentYellowText
        case .disabled:
            return ACColors.tertiaryText
        }
    }
}
