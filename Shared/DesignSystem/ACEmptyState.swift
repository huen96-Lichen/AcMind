import SwiftUI

struct ACEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ACColors.softFill)
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(ACColors.accentBlue)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
            }

            if let actionTitle, let action {
                ACButton(actionTitle, kind: .primary, action: action)
            }
        }
        .frame(maxWidth: 320, alignment: .center)
        .padding(24)
    }
}
