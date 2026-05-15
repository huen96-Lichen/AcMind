import SwiftUI

struct InboxDetailMainCard: View {
    let item: InboxItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                InboxTypeIcon(type: item.type, size: 42)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title)
                            .font(InboxTypography.pageTitle)
                            .foregroundColor(InboxColors.primaryText)
                            .lineLimit(1)
                        Spacer()
                        InboxStatusBadge(status: item.status)
                    }
                    
                    HStack(spacing: 4) {
                        Text(item.type.rawValue)
                            .font(InboxTypography.caption)
                            .foregroundColor(InboxColors.secondaryText)
                        Text("·")
                            .font(InboxTypography.caption)
                            .foregroundColor(InboxColors.secondaryText)
                        if let duration = item.duration {
                            Text(duration)
                                .font(InboxTypography.caption)
                                .foregroundColor(InboxColors.secondaryText)
                            Text("·")
                                .font(InboxTypography.caption)
                                .foregroundColor(InboxColors.secondaryText)
                        }
                        Text("5 days ago (\(item.time))")
                            .font(InboxTypography.caption)
                            .foregroundColor(InboxColors.secondaryText)
                    }
                }
                
                HStack(spacing: 8) {
                    Button(action: {}) {
                        Image(systemName: "star")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(InboxColors.primaryText)
                            .frame(width: 15, height: 15)
                    }
                    .frame(width: 28, height: 28)
                    
                    Button(action: {}) {
                        Image(systemName: "pin")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(InboxColors.primaryText)
                            .frame(width: 15, height: 15)
                    }
                    .frame(width: 28, height: 28)
                    
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(InboxColors.primaryText)
                            .frame(width: 15, height: 15)
                    }
                    .frame(width: 28, height: 28)
                }
            }
            
            if let waveformData = item.waveformData, let duration = item.duration {
                HStack(spacing: 14) {
                    Button(action: {}) {
                        Image(systemName: "play.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(InboxColors.accentOrange)
                            .frame(width: 12, height: 12)
                    }
                    .frame(width: 32, height: 32)
                    .background(InboxColors.voiceBackground)
                    .cornerRadius(16)
                    
                    InboxWaveformView(data: waveformData, width: 260, height: 22)
                    
                    Text(duration)
                        .font(InboxTypography.bodyMedium)
                        .foregroundColor(InboxColors.primaryText)
                }
            }
        }
        .padding(20)
        .frame(width: InboxLayout.detailCardWidth)
        .background(InboxColors.cardBackground)
        .border(InboxColors.border, width: 1)
        .cornerRadius(InboxLayout.cardRadius)
    }
}