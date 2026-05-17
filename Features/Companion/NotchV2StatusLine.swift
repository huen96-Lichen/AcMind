import SwiftUI

struct NotchV2StatusLine: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(NotchV2DesignTokens.accentPurple)
                .frame(width: 5, height: 5)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NotchV2DesignTokens.primaryText)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
