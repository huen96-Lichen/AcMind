import SwiftUI

struct CapsuleShapePreviewCard: View {
    var body: some View {
        ConfigCardContainer {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("入口形态预览")
                        .font(ContinentConfigTypography.cardTitle)
                        .foregroundColor(ContinentConfigTokens.primaryText)
                    Text("胶囊声态与大陆收缩态")
                        .font(ContinentConfigTypography.cardSubtitle)
                        .foregroundColor(ContinentConfigTokens.secondaryText)
                }
                .padding(.horizontal, ContinentConfigLayout.cardPadding)
                .padding(.top, 18)
                .frame(height: 42)
                
                HStack(spacing: 0) {
                    previewColumn(
                        title: "胶囊 收缩态",
                        subtitle: "桌面入口",
                        preview: CapsuleCollapsedPreview()
                    )
                    Divider()
                        .background(ContinentConfigTokens.border)
                        .frame(height: 182)
                    previewColumn(
                        title: "胶囊 展开态",
                        subtitle: "快捷工具条",
                        preview: CapsuleExpandedPreview()
                    )
                    Divider()
                        .background(ContinentConfigTokens.border)
                        .frame(height: 182)
                    previewColumn(
                        title: "大陆 收缩态",
                        subtitle: "顶部停靠",
                        preview: ContinentCollapsedPreview()
                    )
                }
                .frame(height: 182)
                .padding(.horizontal, ContinentConfigLayout.cardPadding)
                .padding(.top, 14)
            }
        }
    }
    
    private func previewColumn(title: String, subtitle: String, preview: some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ContinentConfigTokens.primaryText)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(ContinentConfigTokens.secondaryText)
            }
            .padding(.top, 18)
            .padding(.leading, 18)
            
            Spacer()
            
            preview
                .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer()
        }
        .frame(width: (560 - 40) / 3)
    }
}

struct CapsuleCollapsedPreview: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 9, height: 9)
            Text("AcMind")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Circle()
                .fill(ContinentConfigTokens.accentBlue)
                .frame(width: 7, height: 7)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .frame(width: 128, height: 38)
        .background(ContinentConfigTokens.blackCapsule, in: Capsule())
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 4)
    }
}

struct CapsuleExpandedPreview: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 16, weight: .semibold))
            Image(systemName: "camera")
                .font(.system(size: 16, weight: .semibold))
            Image(systemName: "waveform")
                .font(.system(size: 16, weight: .semibold))
            Image(systemName: "clipboard")
                .font(.system(size: 16, weight: .semibold))
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
        }
        .foregroundColor(ContinentConfigTokens.primaryText)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 168, height: 42)
        .background(ContinentConfigTokens.cardBackground, in: Capsule())
        .overlay(Capsule().stroke(ContinentConfigTokens.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
    }
}

struct ContinentCollapsedPreview: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text("AcMind")
                    .font(.system(size: 12, weight: .semibold))
                Text("正在运行")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            Spacer()
            Circle()
                .fill(ContinentConfigTokens.accentGreen)
                .frame(width: 7, height: 7)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(width: 142, height: 40)
        .background(ContinentConfigTokens.blackCapsule, in: Capsule())
    }
}