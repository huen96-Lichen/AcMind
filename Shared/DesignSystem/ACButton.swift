import SwiftUI

struct ACButton<Label: View>: View {
    enum Kind {
        case primary
        case secondary
        case ai
        case ghost
        case icon
        case danger
    }

    let kind: Kind
    let minWidth: CGFloat?
    let action: () -> Void
    @ViewBuilder let label: Label

    init(
        kind: Kind = .primary,
        minWidth: CGFloat? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.kind = kind
        self.minWidth = minWidth
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
                .font(ACTypography.button)
                .frame(minWidth: minWidth)
                .frame(height: height)
                .padding(.horizontal, horizontalPadding)
                .foregroundStyle(foregroundColor)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(borderColor, lineWidth: ACLayout.borderWidth)
                )
        }
        .buttonStyle(.plain)
    }

    private var height: CGFloat {
        switch kind {
        case .icon:
            return ACLayout.buttonHeightL
        case .ghost:
            return ACLayout.buttonHeightM
        default:
            return ACLayout.buttonHeightL
        }
    }

    private var horizontalPadding: CGFloat {
        switch kind {
        case .icon:
            return 0
        case .ghost:
            return 10
        default:
            return 16
        }
    }

    private var cornerRadius: CGFloat {
        switch kind {
        case .icon:
            return 12
        default:
            return 12
        }
    }

    private var backgroundColor: Color {
        switch kind {
        case .primary:
            return ACColors.accentBlue
        case .secondary:
            return ACColors.cardBackground
        case .ai:
            return ACColors.accentPurple
        case .ghost, .icon:
            return ACColors.cardBackground
        case .danger:
            return ACColors.accentRed
        }
    }

    private var foregroundColor: Color {
        switch kind {
        case .secondary:
            return ACColors.primaryText
        case .ghost:
            return ACColors.primaryText
        default:
            return .white
        }
    }

    private var borderColor: Color {
        switch kind {
        case .secondary, .ghost, .icon:
            return ACColors.border
        default:
            return .clear
        }
    }
}

extension ACButton where Label == Text {
    init(
        _ title: String,
        kind: Kind = .primary,
        minWidth: CGFloat? = nil,
        action: @escaping () -> Void
    ) {
        self.init(kind: kind, minWidth: minWidth, action: action) {
            Text(title)
        }
    }
}
