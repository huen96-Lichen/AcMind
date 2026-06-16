import SwiftUI

struct WaveformPreview: View {
    let isEnabled: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text("预览效果")
                .font(.headline)
            
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(Color(NSColor.textBackgroundColor))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                
                VStack(spacing: 0) {
                    // Waveform Bars
                    HStack(alignment: .center, spacing: 2) {
                        ForEach(0..<40) { index in
                            WaveformBar(height: heightForIndex(index), delay: Double(index) * 0.05)
                        }
                    }
                    
                    // Status Text
                    Text("倾听中...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
            .opacity(isEnabled ? 1.0 : 0.5)
            .grayscale(isEnabled ? 0 : 0.5)
        }
    }
    
    private func heightForIndex(_ index: Int) -> CGFloat {
        let heights: [CGFloat] = [
            8, 12, 6, 16, 10, 20, 14, 8, 18, 12,
            10, 24, 16, 8, 20, 14, 6, 18, 12, 10,
            14, 22, 16, 10, 20, 8, 16, 12, 6, 14,
            18, 10, 24, 16, 8, 12, 20, 14, 6, 18
        ]
        return heights[index]
    }
}

struct WaveformBar: View {
    let height: CGFloat
    let delay: Double
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor)
            .frame(width: 3, height: height)
            .animation(
                .easeInOut(duration: 0.5)
                    .repeatForever()
                    .delay(delay),
                value: height
            )
    }
}
