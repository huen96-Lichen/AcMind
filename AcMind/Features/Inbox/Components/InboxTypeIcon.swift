import SwiftUI

struct InboxTypeIcon: View {
    let type: InboxItemType
    let size: CGFloat
    
    init(type: InboxItemType, size: CGFloat = InboxLayout.listRowIconSize) {
        self.type = type
        self.size = size
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
            iconView
        }
        .frame(width: size, height: size)
    }
    
    private var backgroundColor: Color {
        switch type {
        case .voice: return InboxColors.voiceBackground
        case .task: return InboxColors.taskBackground
        case .markdown: return InboxColors.markdownBackground
        case .document: return InboxColors.documentBackground
        case .image: return InboxColors.imageBackground
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .voice: return InboxColors.voiceIconColor
        case .task: return InboxColors.taskIconColor
        case .markdown: return InboxColors.markdownIconColor
        case .document: return InboxColors.documentIconColor
        case .image: return InboxColors.imageIconColor
        }
    }
    
    private var iconView: some View {
        Image(systemName: iconName)
            .resizable()
            .scaledToFit()
            .foregroundColor(iconColor)
            .frame(width: size * 0.55, height: size * 0.55)
    }
    
    private var iconName: String {
        switch type {
        case .voice: return "waveform"
        case .task: return "checklist"
        case .markdown: return "doc.richtext"
        case .document: return "doc.text"
        case .image: return "viewfinder"
        }
    }
}