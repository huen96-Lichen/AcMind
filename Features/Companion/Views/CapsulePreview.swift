import SwiftUI

struct CapsulePreview: View {
    let position: CompanionCapsulePosition
    let isEnabled: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text("预览效果")
                .font(.headline)
            
            // macOS 菜单栏示意
            ZStack(alignment: position.alignment) {
                // 菜单栏背景
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
                    .frame(height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                
                // 胶囊示意
                HStack(spacing: 4) {
                    // 胶囊按钮示意
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        )
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                        .frame(width: 24, height: 18)
                        .overlay(
                            Image(systemName: "mic")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        )
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppSurfaceTokens.separator.opacity(0.85), lineWidth: 1)
                )
            }
            .opacity(isEnabled ? 1.0 : 0.5)
            .grayscale(isEnabled ? 0 : 0.5)
        }
    }
}

extension CompanionCapsulePosition {
    var alignment: Alignment {
        switch self {
        case .topCenter:
            return .center
        case .topRight:
            return .trailing
        case .hidden:
            return .center
        }
    }
}
