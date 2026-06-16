import SwiftUI
import Charts

struct SystemGaugeRing: View {
    let value: Double
    let icon: String
    let label: String
    let color: Color
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                Text("\(Int(value * 100))%")
                    .font(NotchV2DesignTokens.Typography.footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
            }
        }
        .frame(width: size, height: size)
    }
}

struct SystemSparkLine: View {
    let values: [Double]
    let color: Color
    var height: CGFloat = 24

    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: height)
    }
}

struct SystemMetricTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let progress: Double
    let trend: TrendDirection

    var body: some View {
        HStack(spacing: 10) {
            SystemGaugeRing(
                value: progress,
                icon: icon,
                label: title,
                color: color,
                size: 40
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                HStack(spacing: 4) {
                    Text(value)
                        .font(NotchV2DesignTokens.Typography.title)
                        .foregroundStyle(.white)
                    trendIcon
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.92))
        )
    }

    @ViewBuilder
    private var trendIcon: some View {
        switch trend {
        case .up:
            Image(systemName: "arrow.up.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.green)
        case .down:
            Image(systemName: "arrow.down.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.red)
        case .stable:
            Image(systemName: "arrow.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
        }
    }
}

enum TrendDirection {
    case up, down, stable
}

struct SystemProcessRow: View {
    let name: String
    let cpuPercent: Double
    let memoryPercent: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(NotchV2DesignTokens.Typography.caption)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(Int(cpuPercent))%")
                    .font(NotchV2DesignTokens.Typography.footnote)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
            }
            HStack(spacing: 6) {
                progressBar(value: cpuPercent / 100, color: NotchV2DesignTokens.secondaryText)
                progressBar(value: memoryPercent / 100, color: NotchV2DesignTokens.secondaryText)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.92))
        )
    }

    private func progressBar(value: Double, color: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(color.opacity(0.15))
                Capsule(style: .continuous)
                    .fill(color)
                    .frame(width: proxy.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: 3)
    }
}

struct SystemPermissionIndicator: View {
    let icon: String
    let label: String
    let isAuthorized: Bool
    let action: (() -> Void)?

    init(icon: String, label: String, isAuthorized: Bool, action: (() -> Void)? = nil) {
        self.icon = icon
        self.label = label
        self.isAuthorized = isAuthorized
        self.action = action
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .frame(width: 14)
            Text(label)
                .font(NotchV2DesignTokens.Typography.caption)
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Circle()
                .fill(NotchV2DesignTokens.secondaryText)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: NotchV2DesignTokens.cardRadius, style: .continuous)
                .fill(NotchV2DesignTokens.innerCardBackground.opacity(0.92))
        )
    }
}

struct SystemNetworkRate: View {
    let downloadRate: String
    let uploadRate: String

    var body: some View {
        HStack(spacing: 12) {
            rateItem(icon: "arrow.down", label: "下载", rate: downloadRate, color: .green)
            rateItem(icon: "arrow.up", label: "上传", rate: uploadRate, color: .orange)
        }
    }

    private func rateItem(icon: String, label: String, rate: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(NotchV2DesignTokens.secondaryText)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(NotchV2DesignTokens.Typography.footnote)
                    .foregroundStyle(NotchV2DesignTokens.secondaryText)
                Text(rate)
                    .font(NotchV2DesignTokens.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(NotchV2DesignTokens.primaryText)
            }
        }
    }
}
