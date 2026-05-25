import SwiftUI

struct ShortcutKeycap: View {
    let key: String
    
    var body: some View {
        Text(key)
            .font(.system(.body, design: .monospaced))
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppSurfaceTokens.cardBackgroundSoft)
            .foregroundColor(Color(NSColor.controlTextColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
    }
}

struct ShortcutKeycapView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 4) {
            ShortcutKeycap(key: "⌥")
            ShortcutKeycap(key: "Space")
        }
        .padding()
        .background(AppSurfaceTokens.background)
    }
}