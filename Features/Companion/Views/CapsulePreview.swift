import SwiftUI

struct CapsulePreview: View {
    let position: CompanionCapsulePosition
    let isEnabled: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text("预览效果")
                .font(.headline)
            
            // macOS Menu Bar Mockup
            ZStack(alignment: position.alignment) {
                // Menu Bar Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color(NSColor.controlBackgroundColor), Color(NSColor.windowBackgroundColor)]),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                
                // Capsule
                HStack(spacing: 4) {
                    // Mock Capsule Buttons
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        )
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .frame(width: 24, height: 18)
                        .overlay(
                            Image(systemName: "mic")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        )
                }
                .padding(4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
            }
            .opacity(isEnabled ? 1.0 : 0.5)
            .grayscale(isEnabled ? 0 : 0.5)
        }
    }
}

extension CompanionCapsulePosition {
    var alignment: Alignment {
        switch self {
        case .topCenter:
            return .center
        case .topRight:
            return .trailing
        case .hidden:
            return .center
        }
    }
}