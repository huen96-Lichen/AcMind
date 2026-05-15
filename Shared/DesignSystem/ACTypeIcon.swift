import SwiftUI

struct ACTypeIcon: View {
    let symbol: String
    let tint: Color
    let background: Color
    let size: CGFloat

    init(
        _ symbol: String,
        tint: Color = ACColors.accentBlue,
        background: Color = ACColors.selectedFill,
        size: CGFloat = 42
    ) {
        self.symbol = symbol
        self.tint = tint
        self.background = background
        self.size = size
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                .fill(background)

            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}
