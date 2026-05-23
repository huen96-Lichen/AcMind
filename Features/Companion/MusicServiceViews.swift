//
//  MusicServiceViews.swift
//  AcMind
//
//  Companion music visualizer and mini player views.
//

import AppKit
import SwiftUI
import QuartzCore

/// 音频可视化视图
public class AudioSpectrumView: NSView {
    private var barLayers: [CAShapeLayer] = []
    private var barScales: [CGFloat] = []
    private var isPlaying: Bool = true
    private var animationTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBars()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupBars()
    }

    private func setupBars() {
        let barWidth: CGFloat = 2
        let barCount = 4
        let spacing: CGFloat = barWidth
        let totalWidth = CGFloat(barCount) * (barWidth + spacing)
        let totalHeight: CGFloat = 14
        frame.size = CGSize(width: totalWidth, height: totalHeight)

        for i in 0..<barCount {
            let xPosition = CGFloat(i) * (barWidth + spacing)
            let barLayer = CAShapeLayer()
            barLayer.frame = CGRect(x: xPosition, y: 0, width: barWidth, height: totalHeight)
            barLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            barLayer.position = CGPoint(x: xPosition + barWidth / 2, y: totalHeight / 2)
            barLayer.fillColor = NSColor.white.cgColor
            barLayer.backgroundColor = NSColor.white.cgColor
            barLayer.allowsGroupOpacity = false
            barLayer.masksToBounds = true
            let path = NSBezierPath(
                roundedRect: CGRect(x: 0, y: 0, width: barWidth, height: totalHeight),
                xRadius: barWidth / 2,
                yRadius: barWidth / 2
            )
            barLayer.path = path.cgPath
            barLayers.append(barLayer)
            barScales.append(0.35)
            layer?.addSublayer(barLayer)
        }
    }

    private func startAnimating() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateBars()
            }
        }
    }

    private func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
        resetBars()
    }

    private func updateBars() {
        for (i, barLayer) in barLayers.enumerated() {
            let targetScale = CGFloat.random(in: 0.35...1.0)
            barScales[i] = targetScale
            let animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = barScales[i]
            animation.toValue = targetScale
            animation.duration = 0.3
            animation.autoreverses = true
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            barLayer.add(animation, forKey: "scaleY")
        }
    }

    private func resetBars() {
        for (i, barLayer) in barLayers.enumerated() {
            barLayer.removeAllAnimations()
            barLayer.transform = CATransform3DMakeScale(1, 0.35, 1)
            barScales[i] = 0.35
        }
    }

    public func setPlaying(_ playing: Bool) {
        isPlaying = playing
        if isPlaying {
            startAnimating()
        } else {
            stopAnimating()
        }
    }
}

/// SwiftUI 包装器
public struct MusicVisualizer: NSViewRepresentable {
    @Binding var isPlaying: Bool

    public init(isPlaying: Binding<Bool>) {
        self._isPlaying = isPlaying
    }

    public func makeNSView(context: Context) -> AudioSpectrumView {
        let view = AudioSpectrumView()
        view.setPlaying(isPlaying)
        return view
    }

    public func updateNSView(_ nsView: AudioSpectrumView, context: Context) {
        nsView.setPlaying(isPlaying)
    }
}

/// 迷你音乐播放器视图
public struct MiniMusicPlayerView: View {
    @EnvironmentObject private var musicService: MusicService
    @State private var isHovered = false

    public init() {}

    public var body: some View {
        HStack(spacing: 10) {
            MusicVisualizer(isPlaying: $musicService.isPlaying)
                .frame(width: 16, height: 16)

            if musicService.isPlaying || !musicService.songTitle.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(musicService.songTitle)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(Color.white)

                    Text(musicService.artistName)
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .frame(maxWidth: 100)

                HStack(spacing: 8) {
                    Button(action: { musicService.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { musicService.togglePlay() }) {
                        Image(systemName: musicService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { musicService.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                Text("未播放")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
