import SwiftUI

struct CapsulePreview: View {
    let position: CompanionCapsulePosition
    let isEnabled: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text("胶囊预览")
                .font(.system(size: AppSurfaceTokens.Typography.sectionTitle, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
            
            // macOS 菜单栏预览
            ZStack(alignment: position.alignment) {
                // 菜单栏背景
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
                    .frame(height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppSurfaceTokens.separator, lineWidth: 1)
                    )
                
                // 胶囊预览
                HStack(spacing: 4) {
                    // 胶囊按钮预览
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                        )
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                        .frame(width: 24, height: 18)
                        .overlay(
                        Image(systemName: "mic")
                                .font(.system(size: 10))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
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
