import SwiftUI

struct CompanionSettingsHeader: View {
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left: Title & Description
            VStack(alignment: .leading, spacing: 4) {
                Text("随身")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("AcWork 跨页面、跨应用、可随时调用的系统能力域。")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
            }
            
            Spacer()
            
            // Right: Global Toggle
            HStack(spacing: 8) {
                Text("启用随身能力")
                    .font(.body)
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                
                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
            }
        }
        .padding(.bottom, 8)
        .frame(height: 72)
    }
}
