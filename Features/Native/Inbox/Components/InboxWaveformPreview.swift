import SwiftUI

struct InboxWaveformPreview: View {
    let duration: TimeInterval
    let color: Color

    init(duration: TimeInterval = 60, color: Color = .purple) {
        self.duration = duration
        self.color = color
    }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<48, id: \.self) { index in
                InboxWaveformBar(height: height(for: index), color: color)
            }
        }
        .frame(height: 16)
    }

    private func height(for index: Int) -> CGFloat {
        let random = Double(arc4random_uniform(100)) / 100.0
        let baseHeight: CGFloat = 4
        let maxVariation: CGFloat = 12

        let wave = sin(Double(index) * 0.3) * 0.5 + 0.5
        let variation = random * 0.5 + 0.5

        return baseHeight + (maxVariation * CGFloat(wave * variation))
    }
}

private struct InboxWaveformBar: View {
    let height: CGFloat
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(color.opacity(0.6))
            .frame(width: 2, height: height)
            .animation(.none)
    }
}

extension TimeInterval {
    var formattedDuration: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
