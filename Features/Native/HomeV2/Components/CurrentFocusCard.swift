import SwiftUI
import AppKit

struct CurrentFocusCard: View {
    let model: WorkbenchV2DashboardData.CurrentFocus
    let layout: WorkbenchV2ResolvedLayout
    let backgroundImage: NSImage
    let actions: WorkbenchV2CurrentFocusActions

    var body: some View {
        GeometryReader { proxy in
            let cardSize = proxy.size

            ZStack(alignment: .topLeading) {
                backgroundLayer(size: cardSize)
                    .allowsHitTesting(false)
                    .layoutDebugRegion("CurrentFocusBackground")

                cardContent
                    .padding(WorkbenchV2Tokens.Layout.containerGap)
                    .frame(width: cardSize.width, height: cardSize.height, alignment: .topLeading)
                    .clipped()
                    .layoutDebugRegion("CurrentFocusContent")
            }
            .frame(width: cardSize.width, height: cardSize.height, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.card, style: .continuous))
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.card, style: .continuous)
                .stroke(WorkbenchV2Tokens.Color.heroSurfaceBorder, lineWidth: WorkbenchV2Tokens.Border.width)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 3)
        .compositingGroup()
    }

    @ViewBuilder
    private var cardContent: some View {
        if layout.mode == .compact && layout.heroHeight < 260 {
            compactContent
        } else {
            regularContent
        }
    }

    private var regularContent: some View {
        VStack(alignment: .leading, spacing: WorkbenchV2Tokens.Spacing.md) {
            topBar

            VStack(alignment: .leading, spacing: WorkbenchV2Tokens.Spacing.sm) {
                Text(model.title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(WorkbenchV2Tokens.Color.heroTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                Text(model.summary)
                    .font(.system(size: 14))
                    .foregroundStyle(WorkbenchV2Tokens.Color.heroTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.92)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: WorkbenchV2Tokens.Spacing.sm) {
                WorkbenchV2HeroStatBlock(
                    title: model.primaryMetricLabel,
                    value: model.primaryMetricValue,
                    icon: "sparkles"
                )

                WorkbenchV2HeroProgressBlock(
                    title: model.secondaryMetricLabel,
                    value: model.secondaryMetricValue,
                    progress: progressFraction,
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
            .layoutDebugRegion("CurrentFocusMetrics")

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: WorkbenchV2Tokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.nextStepLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WorkbenchV2Tokens.Color.heroTextSecondary)

                    Text(model.nextStepValue)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(WorkbenchV2Tokens.Color.heroTextPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                actionRow
                    .layoutDebugRegion("CurrentFocusActions")
            }
            .frame(maxWidth: .infinity, alignment: .bottomLeading)
        }
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            topBar

            VStack(alignment: .leading, spacing: 2) {
                Text(model.title)
                    .font(.system(size: 18.5, weight: .semibold))
                    .foregroundStyle(WorkbenchV2Tokens.Color.heroTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)

                Text(model.summary)
                    .font(.system(size: 10))
                    .foregroundStyle(WorkbenchV2Tokens.Color.heroTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.92)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: 4) {
                WorkbenchV2CompactMetricBlock(
                    title: model.primaryMetricLabel,
                    value: model.primaryMetricValue,
                    icon: "sparkles",
                    showsProgress: false
                )

                WorkbenchV2CompactMetricBlock(
                    title: model.secondaryMetricLabel,
                    value: model.secondaryMetricValue,
                    icon: "chart.line.uptrend.xyaxis",
                    showsProgress: true,
                    progress: progressFraction
                )
            }
            .layoutDebugRegion("CurrentFocusMetrics")

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: WorkbenchV2Tokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.nextStepLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WorkbenchV2Tokens.Color.heroTextSecondary)

                    Text(model.nextStepValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(WorkbenchV2Tokens.Color.heroTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 0)

                actionRow
                    .layoutDebugRegion("CurrentFocusActions")
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: WorkbenchV2Tokens.Spacing.sm) {
            Label("当前聚焦", systemImage: "dot.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WorkbenchV2Tokens.Color.heroTextSecondary)

            Spacer(minLength: 0)

            Button(action: actions.selectBackground) {
                    Label("自定义背景", systemImage: "photo.on.rectangle.angled")
                        .labelStyle(.titleAndIcon)
                .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(
                WorkbenchV2HeroActionButtonStyle(
                    height: layout.mode == .compact ? 18 : WorkbenchV2Tokens.Layout.heroButtonHeight,
                    fill: WorkbenchV2Tokens.Color.heroButtonSecondaryFill,
                    foreground: WorkbenchV2Tokens.Color.heroButtonSecondaryText,
                    border: WorkbenchV2Tokens.Color.heroButtonSecondaryBorder
                )
            )
        }
    }

    private var actionRow: some View {
        HStack(spacing: WorkbenchV2Tokens.Spacing.sm) {
            Spacer(minLength: 0)

            Button(action: actions.continueWork) {
                Label("继续工作", systemImage: "play.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: layout.mode == .compact ? 10 : 12.5, weight: .semibold))
            }
            .buttonStyle(
                WorkbenchV2HeroActionButtonStyle(
                    height: layout.mode == .compact ? 22 : WorkbenchV2Tokens.Layout.heroPrimaryActionHeight,
                    fill: WorkbenchV2Tokens.Color.heroButtonPrimaryFill,
                    foreground: WorkbenchV2Tokens.Color.heroButtonPrimaryText,
                    border: nil
                )
            )

            Button(action: actions.viewDetails) {
                Label("查看详情", systemImage: "arrow.right.circle")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: layout.mode == .compact ? 10 : 12.5, weight: .semibold))
            }
            .buttonStyle(
                WorkbenchV2HeroActionButtonStyle(
                    height: layout.mode == .compact ? 22 : WorkbenchV2Tokens.Layout.heroSecondaryActionHeight,
                    fill: WorkbenchV2Tokens.Color.heroButtonSecondaryFill,
                    foreground: WorkbenchV2Tokens.Color.heroButtonSecondaryText,
                    border: WorkbenchV2Tokens.Color.heroButtonSecondaryBorder
                )
            )
        }
    }

    private var progressFraction: Double {
        let digits = model.secondaryMetricValue.filter { $0.isNumber || $0 == "." }
        guard let value = Double(digits) else { return 0.6 }
        return min(max(value / 100.0, 0), 1)
    }

    private func backgroundLayer(size: CGSize) -> some View {
        ZStack(alignment: .leading) {
            Image(nsImage: backgroundImage)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.82), location: 0),
                    .init(color: Color.black.opacity(0.44), location: 0.52),
                    .init(color: Color.black.opacity(0.10), location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.36)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

private struct WorkbenchV2HeroStatBlock: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WorkbenchV2Tokens.Color.heroTextMuted)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WorkbenchV2Tokens.Color.heroTextSecondary)
            }

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WorkbenchV2Tokens.Color.heroTextPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .padding(WorkbenchV2Tokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                .fill(WorkbenchV2Tokens.Color.heroSurface)
        )
    }
}

private struct WorkbenchV2HeroProgressBlock: View {
    let title: String
    let value: String
    let progress: Double
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WorkbenchV2Tokens.Color.heroTextMuted)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WorkbenchV2Tokens.Color.heroTextSecondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WorkbenchV2Tokens.Color.heroTextPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(WorkbenchV2Tokens.Color.heroTextSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(WorkbenchV2Tokens.Color.heroSurfaceStrong)

                    Capsule(style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.62)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .padding(WorkbenchV2Tokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                .fill(WorkbenchV2Tokens.Color.heroSurface)
        )
    }
}

private struct WorkbenchV2CompactMetricBlock: View {
    let title: String
    let value: String
    let icon: String
    let showsProgress: Bool
    let progress: Double?

    init(title: String, value: String, icon: String, showsProgress: Bool, progress: Double? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.showsProgress = showsProgress
        self.progress = progress
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(WorkbenchV2Tokens.Color.heroTextMuted)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WorkbenchV2Tokens.Color.heroTextSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(WorkbenchV2Tokens.Color.heroTextPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let progress {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(WorkbenchV2Tokens.Color.heroTextSecondary)
                }
            }

            if showsProgress, let progress {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(WorkbenchV2Tokens.Color.heroSurfaceStrong)
                        Capsule(style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.72)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                .fill(WorkbenchV2Tokens.Color.heroSurface.opacity(0.88))
        )
    }
}

private struct WorkbenchV2CompactStepBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WorkbenchV2Tokens.Color.heroTextSecondary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(WorkbenchV2Tokens.Color.heroTextPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.88)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.small, style: .continuous)
                .fill(WorkbenchV2Tokens.Color.heroSurface.opacity(0.88))
        )
    }
}

private struct WorkbenchV2HeroActionButtonStyle: ButtonStyle {
    let height: CGFloat
    let fill: Color
    let foreground: Color
    let border: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, WorkbenchV2Tokens.Spacing.sm)
            .frame(height: height)
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.control, style: .continuous)
                    .fill(fill.opacity(configuration.isPressed ? 0.88 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkbenchV2Tokens.Radius.control, style: .continuous)
                    .stroke(border ?? .clear, lineWidth: border == nil ? 0 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#if DEBUG
struct CurrentFocusCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CurrentFocusCard(
                model: WorkbenchV2DashboardData.preview().currentFocus,
                layout: WorkbenchV2Layout.resolve(for: CGSize(width: 927, height: 240)),
                backgroundImage: WorkbenchV2HeroBackgroundStore.makeDefaultBackgroundImage(),
                actions: .previewOnly
            )
            CurrentFocusCard(
                model: .init(
                    state: .warning,
                    title: "还未聚焦",
                    summary: "当前还未聚焦内容，稍后回来查看。",
                    primaryMetricLabel: "主线",
                    primaryMetricValue: "-",
                    secondaryMetricLabel: "阶段",
                    secondaryMetricValue: "-",
                    nextStepLabel: "下一步行动",
                    nextStepValue: "等待任务进入"
                ),
                layout: WorkbenchV2Layout.resolve(for: CGSize(width: 927, height: 240)),
                backgroundImage: WorkbenchV2HeroBackgroundStore.makeDefaultBackgroundImage(),
                actions: .previewOnly
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
