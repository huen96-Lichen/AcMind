import SwiftUI

struct ShortcutKeycap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 12, design: .monospaced))
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
            )
            .foregroundStyle(AppSurfaceTokens.primaryText)
            .overlay(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .stroke(AppSurfaceTokens.separator.opacity(0.9), lineWidth: 1)
            )
    }
}

struct ShortcutKeycapView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 4) {
            ShortcutKeycap(key: "Fn")
            ShortcutKeycap(key: "Space")
            ShortcutKeycap(key: "Shift")
        }
        .padding()
        .background(AppSurfaceBackdrop())
    }
}
