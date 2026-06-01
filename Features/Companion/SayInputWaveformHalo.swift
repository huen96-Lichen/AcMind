import SwiftUI
import AcMindKit

struct SayInputWaveformHalo: View {
    let isActive: Bool
    let mode: NotchV2VoiceWaveformMode
    let accent: Color

    private let barCountPerSide = 10

    var body: some View {
        if isActive {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let time = context.date.timeIntervalSinceReferenceDate

                HStack(alignment: .center, spacing: 4) {
                    waveformSide(time: time, mirrored: false)

                    Spacer(minLength: 0)

                    waveformSide(time: time, mirrored: true)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func waveformSide(time: TimeInterval, mirrored: Bool) -> some View {
        HStack(alignment: .center, spacing: 1.5) {
            ForEach(0..<barCountPerSide, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(accent.opacity(barOpacity(for: index, time: time)))
                    .frame(width: 2.5, height: barHeight(for: index, time: time))
                    .shadow(color: accent.opacity(0.18), radius: 1.5, x: 0, y: 0)
                    .scaleEffect(x: mirrored ? 1.0 : 1.0, y: 1.0, anchor: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: mirrored ? .trailing : .leading)
    }

    private func barHeight(for index: Int, time: TimeInterval) -> CGFloat {
        let speed: Double = mode == .processing ? 2.9 : 5.1
        let amplitude: CGFloat = mode == .processing ? 8.0 : 15.0
        let base: CGFloat = mode == .processing ? 4.0 : 5.0

        let offset = Double(index) * 0.48
        let phase = time * speed + offset
        let value = CGFloat((sin(phase) + 1.0) / 2.0)
        return base + amplitude * value
    }

    private func barOpacity(for index: Int, time: TimeInterval) -> Double {
        let speed: Double = mode == .processing ? 2.2 : 4.0
        let offset = Double(index) * 0.27
        let phase = time * speed + offset
        let value = (sin(phase) + 1.0) / 2.0
        return mode == .processing ? 0.55 + value * 0.25 : 0.72 + value * 0.23
    }
}
