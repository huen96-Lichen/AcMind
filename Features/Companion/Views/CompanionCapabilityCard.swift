import SwiftUI

struct CompanionCapabilityCard<Content: View>: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let description: String
    let isEnabled: Bool
    let isGlobalEnabled: Bool
    @Binding var toggleEnabled: Bool
    let content: Content
    
    init(
        iconName: String,
        iconColor: Color,
        title: String,
        description: String,
        isEnabled: Bool,
        isGlobalEnabled: Bool,
        toggleEnabled: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.iconName = iconName
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.isEnabled = isEnabled
        self.isGlobalEnabled = isGlobalEnabled
        self._toggleEnabled = toggleEnabled
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: iconName)
                        .font(.title)
                        .foregroundColor(iconColor)
                }
                
                // Title & Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                
                Spacer()
                
                // Toggle
                Toggle("启用", isOn: $toggleEnabled)
                    .toggleStyle(.switch)
                    .disabled(!isGlobalEnabled)
            }
            .padding(.bottom, 16)
            
            // Content
            if isGlobalEnabled {
                content
                    .opacity(isEnabled ? 1.0 : 0.55)
            } else {
                content
                    .opacity(0.55)
                    .disabled(true)
            }
        }
        .padding(20)
        .background(AppSurfaceTokens.cardBackgroundSoft)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}