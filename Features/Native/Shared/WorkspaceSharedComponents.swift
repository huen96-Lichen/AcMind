import SwiftUI
import AcMindKit

// MARK: - AcWork Preview Scenario

enum AcWorkPreviewScenario: String, CaseIterable, Identifiable {
    case populated
    case loading
    case empty
    case error

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .populated: return "Populated"
        case .loading: return "Loading"
        case .empty: return "Empty"
        case .error: return "Error"
        }
    }

}

struct AcWorkHomePreviewSnapshot: Equatable {
    let nowLabel: String
    let currentFocus: String
    let nextStep: String
    let pendingItems: [String]
    let scheduleItems: [String]
    let systemMetrics: [String]
}

struct ScreenshotOptionsView: View {
    let onSelect: (ScreenshotMode) -> Void
    let onSelectScroll: () -> Void
    private let snapshot: ScreenshotPreferencesSnapshot

    init(
        snapshot: ScreenshotPreferencesSnapshot = SettingsLocalPreferences.screenshotSnapshot(),
        onSelect: @escaping (ScreenshotMode) -> Void,
        onSelectScroll: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.onSelect = onSelect
        self.onSelectScroll = onSelectScroll
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择截图模式")
                .font(.headline)

            HStack(spacing: 8) {
                statusChip(
                    title: "预设",
                    value: snapshot.activePreset.name,
                    tint: .blue
                )
                statusChip(
                    title: "输出",
                    value: snapshot.activePreset.defaultOutputAction.displayName,
                    tint: .green
                )
                statusChip(
                    title: "热键",
                    value: snapshot.hotkeyLabel,
                    tint: .orange
                )
            }

            Text("快捷入口会沿用当前截图预设；如果要调整参数，可以去设置页切换预设。")
                .font(.caption2)
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                ScreenshotModeButton(
                    icon: "desktopcomputer",
                    title: "全屏"
                ) {
                    onSelect(.fullscreen)
                }

                ScreenshotModeButton(
                    icon: "crop",
                    title: "区域"
                ) {
                    onSelect(.area)
                }

                ScreenshotModeButton(
                    icon: "uiwindow.split.2x1",
                    title: "窗口"
                ) {
                    onSelect(.window)
                }

                ScreenshotModeButton(
                    icon: "scroll",
                    title: "滚动"
                ) {
                    onSelectScroll()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("这些入口都会打开同一截图入口，选择模式后会直接开始截图。")
                    .font(.caption2)
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text("存储路径")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                    Text(assetsDirectoryPath)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppSurfaceTokens.cardBackgroundSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppSurfaceTokens.separator.opacity(0.72), lineWidth: 1)
                )
            }
        }
        .padding()
        .frame(width: 320)
    }

    private func statusChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
            Text(value)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.72), lineWidth: 1)
        )
    }

    private var assetsDirectoryPath: String {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("AcMind", isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)
            .path
        ?? "~/Library/Application Support/AcMind/assets"
    }
}

struct ScreenshotModeButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption)
            }
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackground.opacity(0.94))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Shared Section Actions

struct SectionHeaderAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String?
    let role: ButtonRole?
    let action: () -> Void

    init(title: String, icon: String? = nil, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.role = role
        self.action = action
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let description: String?
    let status: String?
    let actions: [SectionHeaderAction]

    init(
        title: String,
        description: String? = nil,
        status: String? = nil,
        actions: [SectionHeaderAction] = []
    ) {
        self.title = title
        self.description = description
        self.status = status
        self.actions = Array(actions.prefix(2))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: AppSurfaceTokens.Typography.sectionTitle, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                if let description {
                    Text(description)
                        .font(.system(size: AppSurfaceTokens.Typography.sectionDesc))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if let status {
                    Text(status)
                        .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppSurfaceTokens.cardBackgroundSoft)
                        )
                }

                ForEach(actions) { action in
                    Button(role: action.role) {
                        action.action()
                    } label: {
                        HStack(spacing: 5) {
                            if let icon = action.icon {
                                Image(systemName: icon)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            Text(action.title)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .buttonBorderShape(.capsule)
                    .tint(AppSurfaceTokens.accentBlue)
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Status Badge

enum StatusBadgeTone {
    case neutral
    case info
    case success
    case warning
    case danger
    case unavailable
}

struct StatusBadge: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let tone: StatusBadgeTone
    let text: String
    let icon: String?
    let compact: Bool

    init(
        text: String,
        tone: StatusBadgeTone = .neutral,
        icon: String? = nil,
        compact: Bool = false
    ) {
        self.tone = tone
        self.text = text
        self.icon = icon
        self.compact = compact
    }

    init(status: AppPermissionStatus) {
        let tone: StatusBadgeTone
        let icon: String?

        switch status {
        case .unknown:
            tone = .neutral
            icon = "questionmark"
        case .notDetermined:
            tone = .warning
            icon = "clock"
        case .requesting:
            tone = .info
            icon = "arrow.triangle.2.circlepath"
        case .authorized:
            tone = .success
            icon = "checkmark.circle.fill"
        case .denied, .restricted, .needsSystemSettings:
            tone = .danger
            icon = "exclamationmark.triangle.fill"
        case .failed:
            tone = .unavailable
            icon = "xmark.octagon.fill"
        }

        self.tone = tone
        self.text = status.displayName
        self.icon = icon
        self.compact = false
    }

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: compact ? 9 : 10, weight: .semibold))
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(.system(size: compact ? 10 : AppSurfaceTokens.Typography.badge, weight: .semibold))
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 5)
        .background(
            Capsule(style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .accessibilityLabel(text)
    }

    private var isIncreasedContrast: Bool {
        colorSchemeContrast == .increased
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral: return AppSurfaceTokens.secondaryText
        case .info: return AppSurfaceTokens.accentBlue
        case .success: return AppSurfaceTokens.accentGreen
        case .warning: return AppSurfaceTokens.accentOrange
        case .danger: return .red
        case .unavailable: return AppSurfaceTokens.tertiaryText
        }
    }

    private var backgroundColor: Color {
        let multiplier = isIncreasedContrast ? 1.55 : 1
        switch tone {
        case .neutral: return AppSurfaceTokens.secondaryText.opacity(0.12 * multiplier)
        case .info: return AppSurfaceTokens.accentBlue.opacity(0.14 * multiplier)
        case .success: return AppSurfaceTokens.accentGreen.opacity(0.14 * multiplier)
        case .warning: return AppSurfaceTokens.accentOrange.opacity(0.16 * multiplier)
        case .danger: return Color.red.opacity(0.16 * multiplier)
        case .unavailable: return AppSurfaceTokens.cardBackgroundSoft
        }
    }

    private var borderColor: Color {
        let multiplier = isIncreasedContrast ? 1.75 : 1
        switch tone {
        case .neutral: return AppSurfaceTokens.separator.opacity(0.6 * multiplier)
        case .info: return AppSurfaceTokens.accentBlue.opacity(0.28 * multiplier)
        case .success: return AppSurfaceTokens.accentGreen.opacity(0.28 * multiplier)
        case .warning: return AppSurfaceTokens.accentOrange.opacity(0.30 * multiplier)
        case .danger: return Color.red.opacity(0.30 * multiplier)
        case .unavailable: return AppSurfaceTokens.separator.opacity(0.82)
        }
    }
}

struct PermissionStatusCard: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let permission: SystemPermissionSnapshot
    let compact: Bool
    let openSettings: (() -> Void)?

    init(
        permission: SystemPermissionSnapshot,
        compact: Bool = false,
        openSettings: (() -> Void)? = nil
    ) {
        self.permission = permission
        self.compact = compact
        self.openSettings = openSettings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            HStack(spacing: 7) {
                Image(systemName: permission.isAvailable ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(permission.isAvailable ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentOrange)
                    .accessibilityHidden(true)

                Text(permission.name)
                    .font(.system(size: compact ? 10 : 12, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                Spacer(minLength: 0)

                StatusBadge(
                    text: permission.value ?? (permission.isAvailable ? "已授权" : "不可用"),
                    tone: permission.isAvailable ? .success : .warning,
                    icon: permission.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    compact: true
                )
            }

            if permission.isAvailable == false {
                Text(permission.unavailableReason ?? "此能力需要系统授权。")
                    .font(.system(size: compact ? 9 : 11))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let openSettings {
                    Button("打开系统设置", action: openSettings)
                        .buttonStyle(.borderless)
                        .font(.system(size: compact ? 9 : 11, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.accentBlue)
                        .accessibilityHint("打开与\(permission.name)对应的 macOS 权限设置")
                }
            }
        }
        .padding(compact ? 7 : 10)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                .stroke(
                    (permission.isAvailable ? AppSurfaceTokens.accentGreen : AppSurfaceTokens.accentOrange)
                        .opacity(colorSchemeContrast == .increased ? 0.42 : 0.16),
                    lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(permission.name)，\(permission.value ?? "状态未知")")
    }
}

// MARK: - Metric Card

struct MetricCard<Accessory: View>: View {
    let label: String
    let primaryValue: String
    let unit: String?
    let trend: String?
    let state: String?
    let lastUpdated: String?
    let tint: Color
    @ViewBuilder let accessory: Accessory

    init(
        label: String,
        primaryValue: String,
        unit: String? = nil,
        trend: String? = nil,
        state: String? = nil,
        lastUpdated: String? = nil,
        tint: Color = AppSurfaceTokens.accentBlue,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.label = label
        self.primaryValue = primaryValue
        self.unit = unit
        self.trend = trend
        self.state = state
        self.lastUpdated = lastUpdated
        self.tint = tint
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: AppSurfaceTokens.Typography.metricLabel, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(primaryValue)
                            .font(.system(size: AppSurfaceTokens.Typography.metricValue, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        if let unit {
                            Text(unit)
                                .font(.system(size: AppSurfaceTokens.Typography.metricUnit, weight: .semibold))
                                .foregroundStyle(AppSurfaceTokens.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)

                accessory
            }

            if let trend {
                Text(trend)
                    .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                if let state {
                    StatusBadge(text: state, tone: .info, icon: "dot.circle")
                }

                if let lastUpdated {
                    Text(lastUpdated)
                        .font(.system(size: AppSurfaceTokens.Typography.badge, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - State Container

enum StateContainerPhase {
    case ready
    case loading(message: String? = nil)
    case empty(title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil)
    case unavailable(title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil)
    case failed(title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil)
    case stale(title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil)
}

struct StateContainer<Content: View>: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let phase: StateContainerPhase
    let content: Content
    let contentPadding: CGFloat

    init(
        phase: StateContainerPhase,
        contentPadding: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.phase = phase
        self.content = content()
        self.contentPadding = contentPadding
    }

    var body: some View {
        switch phase {
        case .ready:
            content.padding(contentPadding)

        case .stale(let title, let message, let actionTitle, let action):
            VStack(alignment: .leading, spacing: 12) {
                statusBanner(
                    icon: "clock.arrow.circlepath",
                    title: title,
                    message: message,
                    tone: .warning,
                    actionTitle: actionTitle,
                    action: action
                )
                content.padding(contentPadding)
            }

        case .loading(let message):
            statusPlaceholder(
                icon: "circle.dotted",
                title: "正在加载",
                message: message ?? "正在读取最新状态。"
            )

        case .empty(let title, let message, let actionTitle, let action):
            statusPlaceholder(
                icon: "tray",
                title: title,
                message: message,
                tone: .neutral,
                actionTitle: actionTitle,
                action: action
            )

        case .unavailable(let title, let message, let actionTitle, let action):
            statusPlaceholder(
                icon: "exclamationmark.triangle.fill",
                title: title,
                message: message,
                tone: .warning,
                actionTitle: actionTitle,
                action: action
            )

        case .failed(let title, let message, let actionTitle, let action):
            statusPlaceholder(
                icon: "xmark.octagon.fill",
                title: title,
                message: message,
                tone: .danger,
                actionTitle: actionTitle,
                action: action
            )
        }
    }

    private func statusBanner(
        icon: String,
        title: String,
        message: String,
        tone: StatusBadgeTone,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(bannerTint(tone).opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(bannerTint(tone))
                    .accessibilityHidden(true)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(bannerTint(tone))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .stroke(bannerTint(tone).opacity(colorSchemeContrast == .increased ? 0.35 : 0.10), lineWidth: colorSchemeContrast == .increased ? 1.5 : 1)
        )
    }

    private func statusPlaceholder(
        icon: String,
        title: String,
        message: String,
        tone: StatusBadgeTone = .neutral,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(bannerTint(tone).opacity(0.12))
                    .frame(width: 54, height: 54)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(bannerTint(tone))
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .tint(bannerTint(tone))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackgroundSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.cardRadius, style: .continuous)
                .stroke(bannerTint(tone).opacity(colorSchemeContrast == .increased ? 0.32 : 0.08), lineWidth: colorSchemeContrast == .increased ? 1.5 : 1)
        )
    }

    private func bannerTint(_ tone: StatusBadgeTone) -> Color {
        switch tone {
        case .neutral: return AppSurfaceTokens.secondaryText
        case .info: return AppSurfaceTokens.accentBlue
        case .success: return AppSurfaceTokens.accentGreen
        case .warning: return AppSurfaceTokens.accentOrange
        case .danger: return .red
        case .unavailable: return AppSurfaceTokens.tertiaryText
        }
    }
}

// MARK: - Preview Sample

struct WorkspaceSharedComponentsPreviewSample: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    title: "共享组件示意",
                    description: "展示状态容器、徽章、指标和区块标题的复用效果。",
                    status: "DS-02"
                )

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    MetricCard(
                        label: "插件总数",
                        primaryValue: "12",
                        trend: "4 个处于运行中",
                        state: "稳定",
                        lastUpdated: "刚刚",
                        tint: AppSurfaceTokens.accentBlue
                    ) {
                        Circle()
                            .fill(AppSurfaceTokens.accentBlue.opacity(0.16))
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "puzzlepiece.extension")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppSurfaceTokens.accentBlue)
                            )
                    }

                    MetricCard(
                        label: "异常数",
                        primaryValue: "2",
                        trend: "较上次下降 1 个",
                        state: "待处理",
                        lastUpdated: "3 分钟前",
                        tint: AppSurfaceTokens.accentOrange
                    ) {
                        Circle()
                            .fill(AppSurfaceTokens.accentOrange.opacity(0.16))
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppSurfaceTokens.accentOrange)
                            )
                    }
                }

                HStack(spacing: 8) {
                    StatusBadge(status: .authorized)
                    StatusBadge(status: .needsSystemSettings)
                    StatusBadge(text: "模型在线", tone: .success, icon: "checkmark.circle.fill")
                    StatusBadge(text: "同步中", tone: .info, icon: "arrow.triangle.2.circlepath")
                }

                StateContainer(
                    phase: .stale(title: "数据已过 60 秒", message: "继续展示最近一次可用状态，同时建议刷新。", actionTitle: "刷新") {}
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("内容区")
                            .font(.system(size: 14, weight: .semibold))
                        Text("这里显示状态容器的正常内容状态。")
                            .font(.system(size: 12))
                            .foregroundStyle(AppSurfaceTokens.secondaryText)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackgroundSoft)
                )
            }

                StateContainer(
                    phase: .failed(title: "插件摘要读取失败", message: "无法连接到插件目录。", actionTitle: "重试") {}
                ) {
                    EmptyView()
                }
            }
            .padding(20)
            .frame(maxWidth: 960, alignment: .leading)
        }
        .background(AppVisualBackdrop())
    }
}

#Preview("Shared Components / Wide") {
    WorkspaceSharedComponentsPreviewSample()
        .preferredColorScheme(.dark)
}

#Preview("Shared Components / Narrow") {
    WorkspaceSharedComponentsPreviewSample()
        .frame(width: 760)
        .preferredColorScheme(.dark)
}
