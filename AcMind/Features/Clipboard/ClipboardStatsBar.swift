import SwiftUI

struct ClipboardStatsBar: View {
    let stats = clipboardStats
    
    var body: some View {
        HStack(spacing: 12) {
            LargeStatCard(
                title: "全部内容",
                number: stats.totalItems,
                subtitle: "条内容"
            )
            
            LargeStatCard(
                title: "最近 24 小时",
                number: stats.last24Hours,
                subtitle: "条内容"
            )
            
            SmallStatCard(
                type: .text,
                count: stats.textCount
            )
            
            SmallStatCard(
                type: .image,
                count: stats.imageCount
            )
            
            SmallStatCard(
                type: .link,
                count: stats.linkCount
            )
            
            SmallStatCard(
                type: .file,
                count: stats.fileCount
            )
            
            SmallStatCard(
                type: .code,
                count: stats.codeCount
            )
        }
        .padding(.horizontal, ClipboardLayout.workspacePaddingX)
        .padding(.vertical, (ClipboardLayout.statsBarHeight - ClipboardLayout.statCardHeight) / 2)
    }
}

struct LargeStatCard: View {
    let title: String
    let number: Int
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ClipboardTypography.statTitle)
                .foregroundColor(ClipboardColors.secondaryText)
            
            Text("\(number)")
                .font(ClipboardTypography.statNumber)
                .foregroundColor(ClipboardColors.primaryText)
            
            Text(subtitle)
                .font(ClipboardTypography.statSubtitle)
                .foregroundColor(ClipboardColors.tertiaryText)
        }
        .frame(width: 180, height: ClipboardLayout.statCardHeight)
        .padding(16)
        .background(ClipboardColors.cardBackground)
        .cornerRadius(ClipboardLayout.smallRadius)
        .overlay(
            RoundedRectangle(cornerRadius: ClipboardLayout.smallRadius)
                .stroke(ClipboardColors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.025), radius: 8, y: 2)
    }
}

struct SmallStatCard: View {
    let type: ClipboardItemType
    let count: Int
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(type.backgroundColor)
                    .frame(width: 32, height: 32)
                
                Image(systemName: type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(type.iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(ClipboardTypography.statTitle)
                    .foregroundColor(ClipboardColors.primaryText)
                
                Text("\(count)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ClipboardColors.primaryText)
            }
        }
        .frame(width: 144, height: ClipboardLayout.statCardHeight)
        .padding(16)
        .background(ClipboardColors.cardBackground)
        .cornerRadius(ClipboardLayout.smallRadius)
        .overlay(
            RoundedRectangle(cornerRadius: ClipboardLayout.smallRadius)
                .stroke(ClipboardColors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.025), radius: 8, y: 2)
    }
}