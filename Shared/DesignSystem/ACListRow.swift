import SwiftUI

struct ACListRow: View {
    let title: String
    let subtitle: String?
    let symbol: String?
    let selected: Bool
    let tint: Color
    let meta: String?
    let trailing: String?

    init(
        title: String,
        subtitle: String? = nil,
        symbol: String? = nil,
        selected: Bool = false,
        tint: Color = ACColors.accentBlue,
        meta: String? = nil,
        trailing: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.selected = selected
        self.tint = tint
        self.meta = meta
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let symbol {
                ACTypeIcon(symbol, tint: tint, background: selected ? ACColors.selectedFill : ACColors.softFill, size: 42)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(ACTypography.itemTitle)
                        .foregroundStyle(ACColors.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let meta {
                        Text(meta)
                            .font(ACTypography.miniMedium)
                            .foregroundStyle(ACColors.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 0)

            if let trailing {
                Text(trailing)
                    .font(ACTypography.captionMedium)
                    .foregroundStyle(ACColors.tertiaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: ACLayout.listRowHeight, alignment: .leading)
        .background(selected ? ACColors.selectedFill : ACColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? ACColors.accentBlue.opacity(0.35) : ACColors.border, lineWidth: 1)
        )
    }
}
