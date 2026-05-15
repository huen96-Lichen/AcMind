import SwiftUI

struct InboxRow: View {
    let item: InboxItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            InboxTypeIcon(type: item.type)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.title)
                        .font(InboxTypography.itemTitle)
                        .foregroundColor(InboxColors.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Text(item.time)
                        .font(InboxTypography.caption)
                        .foregroundColor(InboxColors.secondaryText)
                }
                
                HStack(spacing: 4) {
                    Text(item.type.rawValue)
                        .font(InboxTypography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(typeTextColor)
                    if !item.source.isEmpty {
                        Text("·")
                            .font(InboxTypography.caption)
                            .foregroundColor(InboxColors.secondaryText)
                        Text(item.source)
                            .font(InboxTypography.caption)
                            .foregroundColor(InboxColors.secondaryText)
                    }
                }
                
                if let waveformData = item.waveformData {
                    HStack(spacing: 8) {
                        InboxWaveformView(data: waveformData, width: 180)
                        Text(item.duration ?? "")
                            .font(InboxTypography.caption)
                            .foregroundColor(InboxColors.secondaryText)
                    }
                } else {
                    Text(item.summary)
                        .font(InboxTypography.caption)
                        .foregroundColor(InboxColors.secondaryText)
                        .lineLimit(1)
                }
            }
            
            VStack(alignment: .trailing, spacing: 8) {
                InboxStatusBadge(status: item.status)
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(InboxColors.primaryText)
                        .frame(width: 15, height: 15)
                }
                .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, InboxLayout.listRowHorizontalPadding)
        .padding(.vertical, 14)
        .background(isSelected ? InboxColors.cardBackground : Color.clear)
        .cornerRadius(14)
        .overlay(
            isSelected ? RoundedRectangle(cornerRadius: 14).stroke(InboxColors.border, lineWidth: 1) : nil
        )
        .onTapGesture(perform: onTap)
    }
    
    private var typeTextColor: Color {
        switch item.type {
        case .voice: return InboxColors.accentOrange
        case .task: return InboxColors.accentPurple
        case .markdown: return InboxColors.accentBlue
        case .document: return InboxColors.accentBlue
        case .image: return InboxColors.accentRed
        }
    }
}