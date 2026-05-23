import SwiftUI

struct WorkbenchToolCardView: View {
    let card: WorkbenchToolCardModel

    var body: some View {
        ACCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ACTypeIcon(card.symbol, tint: card.tint, background: card.tint.opacity(0.12), size: 30)
                    Spacer(minLength: 0)
                    ACBadge(card.state, kind: card.badgeKind)
                }

                Text(card.title)
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)

                Text(card.subtitle)
                    .font(ACTypography.caption)
                    .foregroundStyle(ACColors.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .frame(height: 112)
    }
}
