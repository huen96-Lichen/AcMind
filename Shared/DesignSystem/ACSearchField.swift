import SwiftUI

struct ACSearchField: View {
    let placeholder: String
    @Binding var text: String
    let width: CGFloat?
    let height: CGFloat

    @FocusState private var isFocused: Bool

    init(
        _ placeholder: String = "搜索",
        text: Binding<String>,
        width: CGFloat? = ACLayout.searchFieldWidth,
        height: CGFloat = ACLayout.searchFieldHeight
    ) {
        self.placeholder = placeholder
        self._text = text
        self.width = width
        self.height = height
    }

    var body: some View {
        HStack(spacing: ACLayout.gapS) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isFocused ? ACColors.accentBlue : ACColors.secondaryText)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(ACTypography.body)
                .foregroundStyle(ACColors.primaryText)
                .focused($isFocused)
        }
        .padding(.horizontal, 12)
        .frame(width: width, height: height)
        .background(ACColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .stroke(isFocused ? ACColors.accentBlue : ACColors.border, lineWidth: 1)
        )
    }
}
