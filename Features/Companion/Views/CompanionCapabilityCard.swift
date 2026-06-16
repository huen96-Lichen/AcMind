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
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackgroundSoft)
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
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: AppSurfaceTokens.separator.opacity(0.08), radius: 3, x: 0, y: 1)
    }
}
