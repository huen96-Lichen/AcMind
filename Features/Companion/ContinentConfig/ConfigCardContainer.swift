import SwiftUI

struct ConfigCardContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(ContinentConfigTokens.cardBackground)
            .cornerRadius(ContinentConfigLayout.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: ContinentConfigLayout.cardRadius)
                    .stroke(ContinentConfigTokens.border, lineWidth: 1)
            )
            .shadow(color: ContinentConfigTokens.shadowColor, radius: 12, x: 0, y: 4)
    }
}