import SwiftUI
import AcMindKit

private let showTopBarDebugOverlay = false

struct NotchV2TopBar: View {
    @ObservedObject var viewModel: NotchV2ViewModel

    var body: some View {
        let pageNavYOffset: CGFloat = -5

        ZStack(alignment: .topLeading) {
            Color.black

            pageNavView
                .frame(width: 232, height: 36)
                .clipped()
                .position(x: 172, y: 18)
                .offset(y: pageNavYOffset)

            if CompanionScreenPositioning.hasHardwareNotch() {
                notchMask
                    .position(x: 440, y: 18)
            }

            rightStatusView
                .frame(width: 232, height: 36)
                .clipped()
                .position(x: 708, y: 18)
                .offset(y: pageNavYOffset)

            if showTopBarDebugOverlay {
                TopBarSafeAreaDebugOverlay()
                    .frame(width: 880, height: 70, alignment: .topLeading)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 880, height: 36)
    }

    private var pageNavView: some View {
        ZStack(alignment: .topLeading) {
            topNavButton(pageTitle(at: 0, fallback: "今日"), selected: viewModel.selectedPage == .overview) {
                viewModel.select(.overview)
            }
            .frame(width: 32, height: 24, alignment: .center)
            .position(x: 28, y: 18)

            topNavButton(pageTitle(at: 1, fallback: "音乐"), selected: viewModel.selectedPage == .music) {
                viewModel.select(.music)
            }
            .frame(width: 32, height: 24, alignment: .center)
            .position(x: 88, y: 18)

            topNavButton(pageTitle(at: 2, fallback: "AI"), selected: viewModel.selectedPage == .agent) {
                viewModel.select(.agent)
            }
            .frame(width: 28, height: 24, alignment: .center)
            .position(x: 146, y: 18)

            topNavButton(pageTitle(at: 3, fallback: "日程"), selected: viewModel.selectedPage == .schedule) {
                viewModel.select(.schedule)
            }
            .frame(width: 32, height: 24, alignment: .center)
            .position(x: 204, y: 18)
        }
        .frame(width: 232, height: 36, alignment: .leading)
    }

    private var rightStatusView: some View {
        ZStack(alignment: .topLeading) {
            batteryStatusView
                .frame(width: 72, height: 36, alignment: .leading)
                .position(x: 48, y: 18)

            settingsStatusView
                .frame(width: 64, height: 36, alignment: .leading)
                .position(x: 140, y: 18)

            collapseStatusButton
                .position(x: 208, y: 18)
        }
        .frame(width: 232, height: 36, alignment: .leading)
    }

    private var batteryStatusView: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(NotchV2DesignTokens.accentGreen)
                .frame(width: 18, height: 9)

            Text("78%")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.primaryText)
        }
        .frame(width: 72, height: 22, alignment: .leading)
    }

    private var settingsStatusView: some View {
        HStack(spacing: 6) {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.70))

            Text("设置")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.70))
        }
        .frame(width: 64, height: 20, alignment: .leading)
    }

    private var collapseStatusButton: some View {
        Button(action: { viewModel.collapse() }) {
            Image(systemName: "chevron.up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
    }

    private var notchMask: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.black)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
            .frame(width: 160, height: 30)
    }

    private func topNavButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? NotchV2DesignTokens.primaryText : Color.white.opacity(0.55))
                .overlay(alignment: .bottom) {
                    if selected {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(NotchV2DesignTokens.accentPurple)
                            .frame(width: title == "AI" ? 24 : 34, height: 2)
                            .offset(y: 7)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func pageTitle(at index: Int, fallback: String) -> String {
        guard viewModel.topBarPageTitles.indices.contains(index) else { return fallback }
        return viewModel.topBarPageTitles[index]
    }
}

private struct TopBarSafeAreaDebugOverlay: View {
    private let containerWidth: CGFloat = 880
    private let topBarHeight: CGFloat = 36
    private let topBarY: CGFloat = 20
    private let leftSafeX: CGFloat = 56
    private let topBarHorizontalPadding: CGFloat = 56
    private let centerAvoidWidth: CGFloat = 264
    private let centerAvoidHeight: CGFloat = 36
    private let minGap: CGFloat = 20

    var body: some View {
        let centerAvoidX = containerWidth / 2 - centerAvoidWidth / 2
        let leftSafeWidth = centerAvoidX - leftSafeX - minGap
        let rightSafeX = centerAvoidX + centerAvoidWidth + minGap
        let rightSafeWidth = containerWidth - rightSafeX - topBarHorizontalPadding

        ZStack(alignment: .topLeading) {
            boundedLabelRect(
                x: topBarHorizontalPadding,
                y: topBarY,
                width: containerWidth - topBarHorizontalPadding * 2,
                height: topBarHeight,
                fill: Color.blue.opacity(0.15),
                stroke: Color.blue.opacity(0.9),
                label: "Top Bar Bounds",
                labelColor: .blue
            )

            boundedLabelRect(
                x: leftSafeX,
                y: topBarY,
                width: leftSafeWidth,
                height: topBarHeight,
                fill: Color.purple.opacity(0.18),
                stroke: Color.purple.opacity(0.9),
                label: "Left Entry Safe Area",
                labelColor: .purple
            )

            boundedLabelRect(
                x: centerAvoidX,
                y: topBarY,
                width: centerAvoidWidth,
                height: centerAvoidHeight,
                fill: Color.red.opacity(0.20),
                stroke: Color.red.opacity(0.9),
                label: "Center Notch Avoid Area",
                labelColor: .red
            )

            boundedLabelRect(
                x: rightSafeX,
                y: topBarY,
                width: rightSafeWidth,
                height: topBarHeight,
                fill: Color.green.opacity(0.18),
                stroke: Color.green.opacity(0.9),
                label: "Right Status Safe Area",
                labelColor: .green
            )

            buttonDebugRect(title: "今日 32×24", x: 68, y: 32, width: 32, height: 24)
            buttonDebugRect(title: "音乐 32×24", x: 128, y: 32, width: 32, height: 24)
            buttonDebugRect(title: "AI 28×24", x: 188, y: 32, width: 28, height: 24)
            buttonDebugRect(title: "日程 32×24", x: 244, y: 32, width: 32, height: 24)

            buttonDebugRect(title: "电量 72×36", x: 604, y: 32, width: 72, height: 36)
            buttonDebugRect(title: "设置 64×36", x: 700, y: 32, width: 64, height: 36)
            buttonDebugRect(title: "收起 24×24", x: 788, y: 38, width: 24, height: 24)
        }
        .frame(width: containerWidth, height: topBarHeight, alignment: .topLeading)
    }

    private func boundedLabelRect(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        fill: Color,
        stroke: Color,
        label: String,
        labelColor: Color
    ) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .frame(width: width, height: height)
            .position(x: x + width / 2, y: y + height / 2)
            .overlay(alignment: .topLeading) {
                Text(label)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(labelColor)
                    .padding(.leading, 4)
                    .padding(.top, 3)
            }
    }

    private func buttonDebugRect(title: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(Color.yellow.opacity(0.95), lineWidth: 1)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.yellow.opacity(0.12))
            )
            .frame(width: width, height: height)
            .position(x: x + width / 2, y: y + height / 2)
            .overlay(alignment: .topLeading) {
                Text(title)
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.yellow)
                    .padding(.leading, 3)
                    .padding(.top, 2)
            }
    }
}
