import SwiftUI

struct ACPageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: ACLayout.gapXL) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ACTypography.pageTitle)
                    .foregroundStyle(ACColors.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(ACTypography.caption)
                        .foregroundStyle(ACColors.secondaryText)
                }
            }

            Spacer(minLength: 0)

            trailing
        }
        .padding(.horizontal, ACLayout.pagePaddingX)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ACColors.pageBackground)
    }
}

struct ACPageHeaderEmptyTrailing: View {
    var body: some View {
        EmptyView()
    }
}
