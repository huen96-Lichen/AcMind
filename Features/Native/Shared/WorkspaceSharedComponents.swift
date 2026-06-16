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

    static func fromProcessArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> AcWorkPreviewScenario? {
        for argument in arguments {
            if argument.hasPrefix("--acwork-preview=") {
                let value = String(argument.dropFirst("--acwork-preview=".count))
                return AcWorkPreviewScenario(rawValue: value)
            }

            if argument.hasPrefix("--acwork-preview-") {
                let value = String(argument.dropFirst("--acwork-preview-".count))
                return AcWorkPreviewScenario(rawValue: value)
            }
        }

        return nil
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

enum AcWorkPreviewData {
    static let fixedNow = Date(timeIntervalSince1970: 1_781_491_200)

    static var homeSnapshot: AcWorkHomePreviewSnapshot {
        AcWorkHomePreviewSnapshot(
            nowLabel: "2026-06-15 09:20",
            currentFocus: "AcWork Phase 1 UI 重制",
            nextStep: "确认收集箱统一模型与 Shell 响应式规则",
            pendingItems: [
                "3 条剪贴板内容待整理",
                "1 条会议语音待提炼",
                "2 张截图等待 OCR"
            ],
            scheduleItems: [
                "10:00 设计规范复盘",
                "14:30 收集箱 Repository 联调",
                "17:00 构建与截图验收"
            ],
            systemMetrics: [
                "CPU 28%",
                "内存 11.2 GB",
                "模型服务在线"
            ]
        )
    }

    static func inboxItems(for scenario: AcWorkPreviewScenario) -> [SourceItem] {
        switch scenario {
        case .populated:
            return populatedInboxItems
        case .loading, .empty, .error:
            return []
        }
    }

    static var populatedInboxItems: [SourceItem] {
        [
            SourceItem(
                id: "acwork-preview-voice-standup",
                type: .audio,
                source: .voice,
                status: .captured,
                title: "站会语音记录",
                previewText: "今天先完成导航迁移，再推进收集箱统一模型。",
                transcript: "今天先完成导航迁移，再推进收集箱统一模型。风险点是旧剪贴板数据必须保持可读。",
                sourceApp: "AcWork",
                tags: ["voice", "standup"],
                metadata: ["scenario": "populated", "duration": "00:42"],
                createdAt: fixedNow.addingTimeInterval(-600),
                updatedAt: fixedNow.addingTimeInterval(-540)
            ),
            SourceItem(
                id: "acwork-preview-clipboard-link",
                type: .webpage,
                source: .clipboard,
                status: .pending,
                title: "设计规范链接",
                previewText: "AcWork Focus Workspace 规范：Shell、Toolbar、Filter Rail、Inspector。",
                sourceApp: "Safari",
                originalUrl: "https://example.local/acwork/spec",
                tags: ["link", "design-system"],
                metadata: ["scenario": "populated", "contentKind": "link"],
                createdAt: fixedNow.addingTimeInterval(-1_800)
            ),
            SourceItem(
                id: "acwork-preview-phone-richtext",
                type: .text,
                source: .clipboard,
                status: .inbox,
                title: "手机同步富文本",
                previewText: "从 iPhone 同步的竞品笔记，包含标题、列表和行动项。",
                sourceApp: "iPhone",
                tags: ["phone-sync", "rich-text"],
                metadata: ["scenario": "populated", "sourceDevice": "iPhone", "contentKind": "richText"],
                createdAt: fixedNow.addingTimeInterval(-2_400)
            ),
            SourceItem(
                id: "acwork-preview-screenshot-ocr",
                type: .screenshot,
                source: .screenshot,
                status: .parsed,
                title: "设置页截图 OCR",
                previewText: "截图中识别到模型配置、权限状态、快捷键说明。",
                ocrText: "模型配置 / 权限状态 / 快捷键说明 / 本地优先",
                tags: ["screenshot", "ocr"],
                metadata: ["scenario": "populated", "contentKind": "image"],
                createdAt: fixedNow.addingTimeInterval(-3_600)
            ),
            SourceItem(
                id: "acwork-preview-agent-code",
                type: .text,
                source: .agent,
                status: .distilled,
                title: "Agent 生成代码片段",
                previewText: "func canonicalSidebarItem(for item: SidebarItem) -> SidebarItem { item == .clipboard ? .inbox : item }",
                tags: ["agent", "code"],
                metadata: ["scenario": "populated", "contentKind": "code", "language": "swift"],
                createdAt: fixedNow.addingTimeInterval(-5_400),
                updatedAt: fixedNow.addingTimeInterval(-5_100)
            ),
            SourceItem(
                id: "acwork-preview-manual-file",
                type: .pdf,
                source: .manual,
                status: .exported,
                title: "手动添加的需求 PDF",
                previewText: "Phase 1 范围、验收截图和风险清单。",
                tags: ["file", "requirements"],
                metadata: ["scenario": "populated", "contentKind": "file", "extension": "pdf"],
                createdAt: fixedNow.addingTimeInterval(-7_200),
                updatedAt: fixedNow.addingTimeInterval(-6_900)
            ),
            SourceItem(
                id: "acwork-preview-video-reference",
                type: .video,
                source: .file,
                status: .inbox,
                title: "交互动效参考视频",
                previewText: "用于比对工作台卡片进入动画和 Inspector 展开方式。",
                tags: ["video", "motion"],
                metadata: ["scenario": "populated", "contentKind": "video"],
                createdAt: fixedNow.addingTimeInterval(-9_000)
            )
        ]
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                if let description {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if let status {
                    Text(status)
                        .font(.system(size: 10.5, weight: .semibold))
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
                .font(.system(size: compact ? 10 : 10.5, weight: .semibold))
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(primaryValue)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppSurfaceTokens.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        if let unit {
                            Text(unit)
                                .font(.system(size: 11, weight: .semibold))
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
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                if let state {
                    StatusBadge(text: state, tone: .info, icon: "dot.circle")
                }

                if let lastUpdated {
                    Text(lastUpdated)
                        .font(.system(size: 10, weight: .medium))
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
                    title: "共享组件样板",
                    description: "用于验证状态容器、徽章、指标和区块标题是否能跨页面复用。",
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
                        Text("内容区示例")
                            .font(.system(size: 14, weight: .semibold))
                        Text("这里是状态容器的正常内容状态。")
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
        .background(AppSurfaceBackdrop())
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
