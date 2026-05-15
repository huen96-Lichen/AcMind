import SwiftUI

struct AgentChatPanel: View {
    var body: some View {
        VStack(spacing: AgentLayout.mainContentGap) {
            AgentChatThreadCard()
                .frame(maxHeight: .infinity)
            
            AgentInputComposer()
                .frame(height: AgentLayout.chatInputHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}