import SwiftUI
import AppKit
import struct AcMindKit.KeyboardShortcut
import enum AcMindKit.AcWorkBrand
import enum AcMindKit.SidebarItem

// MARK: - Sidebar View

/// 侧边栏导航视图
/// 使用固定宽度的自绘布局，避免 macOS sidebar 样式在窗口变窄时自动折叠成图标栏。
struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: ServiceContainer
    @State private var hoveredItem: SidebarItem?
    @State private var footerStatus: SidebarFooterStatus = .loading

    var body: some View {
        ScrollView {
            if appState.sidebarCollapsed {
                compactSidebar
            } else {
                expandedSidebar
            }
        }
        .scrollIndicators(.hidden)
        .frame(width: appState.sidebarCollapsed ? 84 : AppSurfaceTokens.Layout.sidebarWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(AppSurfaceTokens.sidebarBackground.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("主侧边栏")
        .accessibilitySortPriority(100)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppSurfaceTokens.separator.opacity(0.55))
                .frame(width: 1)
                .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
                .help("切换侧边栏")
                .accessibilityLabel("切换侧边栏")
            }
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
    }

    private var expandedSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            sidebarHeaderCard
            sidebarSection(title: "工作", subtitle: nil, items: SidebarItem.coreWorkflow)
            sidebarSection(title: "处理", subtitle: nil, items: SidebarItem.processingItems)
            sidebarSection(title: "随身能力", subtitle: nil, items: SidebarItem.companionCapabilities)
            sidebarSection(title: "系统", subtitle: nil, items: SidebarItem.systemItems)
            sidebarFooter
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
    }

    private var compactSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            compactHeader

            compactSection(title: "工作", items: SidebarItem.coreWorkflow)
            compactSection(title: "处理", items: SidebarItem.processingItems)
            compactSection(title: "随身能力", items: SidebarItem.companionCapabilities)
            compactSection(title: "系统", items: SidebarItem.systemItems)
            compactFooter
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
    }

    private func sidebarSection(title: String, subtitle: String?, items: [SidebarItem]) -> some View {
        AppSurfaceCard(title: title, subtitle: subtitle, padding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    Button {
                        appState.navigate(to: item)
                    } label: {
                        SidebarItemRow(
                            item: item,
                            isSelected: appState.sidebarSelection == item,
                            isHovered: hoveredItem == item
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        hoveredItem = isHovered ? item : nil
                    }
                }
            }
        }
    }

    private func compactSection(title: String, items: [SidebarItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    Button {
                        appState.navigate(to: item)
                    } label: {
                        SidebarCompactItemRow(
                            item: item,
                            isSelected: appState.sidebarSelection == item,
                            isHovered: hoveredItem == item
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        hoveredItem = isHovered ? item : nil
                    }
                }
            }
        }
    }

    private var sidebarHeaderCard: some View {
        AppSurfaceCard(title: AcWorkBrand.displayName, subtitle: "本地优先 AI 工作台", padding: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                        .fill(AppSurfaceTokens.secondaryText.opacity(0.10))
                    Image(systemName: "rectangle.grid.2x2")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .accessibilityHidden(true)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        StatusBadge(text: "主导航", tone: .neutral, compact: true)
                        StatusBadge(text: "Cmd 1-9", tone: .neutral, compact: true)
                    }

                    Text("工作 · 处理 · 随身能力 · 系统")
                        .font(.system(size: 10))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: 72)
    }

    private var compactHeader: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(AppSurfaceTokens.secondaryText.opacity(0.10))
                Image(systemName: "rectangle.grid.2x2")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .accessibilityHidden(true)
            }
            .frame(width: 28, height: 28)

            Spacer(minLength: 0)

            Button(action: toggleSidebar) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("展开侧边栏")
            .background(
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(AppSurfaceTokens.cardBackground)
            )
            .help("展开侧边栏")
        }
        .padding(.bottom, 4)
    }

    private var sidebarFooter: some View {
        SidebarFooter(status: footerStatus)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    private var compactFooter: some View {
        SidebarFooter(status: footerStatus, compact: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    private func toggleSidebar() {
        appState.toggleSidebar()
    }

    private func setupKeyboardShortcuts() {
        // 快捷键已在 AppState 中定义
        Task { await refreshFooterStatus() }
    }

    @MainActor
    private func refreshFooterStatus() async {
        let serviceState: String
        if container.isInitialized {
            serviceState = "本地服务正常"
        } else {
            serviceState = "本地服务初始化中"
        }

        let modelLabel: String
        do {
            let settings = await container.settingsService.getSettings()
            modelLabel = settings.defaultModelId?.isEmpty == false ? settings.defaultModelId! : "自动路由"
        } catch {
            modelLabel = "未知模型"
        }

        footerStatus = SidebarFooterStatus(
            serviceState: serviceState,
            modelLabel: modelLabel
        )
    }
}

// MARK: - Sidebar Item Row

struct SidebarItemRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let isHovered: Bool

    init(item: SidebarItem, isSelected: Bool, isHovered: Bool = false) {
        self.item = item
        self.isSelected = isSelected
        self.isHovered = isHovered
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSurfaceTokens.inlineBlockRadius, style: .continuous)
                    .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.14) : AppSurfaceTokens.cardBackground.opacity(0.92))
                    .frame(width: 26, height: 26)

                Image(systemName: item.icon)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.system(size: 12.75, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.72)
                    .layoutPriority(1)
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                if item.group == .companionCapabilities {
                    Text(item.group.displayName)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 6)

            if (isHovered || isSelected), let shortcut = item.shortcut {
                Text(shortcutDisplay(shortcut))
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.12) : AppSurfaceTokens.cardBackground.opacity(0.94))
                    )
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.10) : (isHovered ? AppSurfaceTokens.cardBackground.opacity(0.88) : Color.clear))
        )
        .foregroundStyle(AppSurfaceTokens.primaryText)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName)\(isSelected ? "，当前页面" : "")")
    }

    private func shortcutDisplay(_ shortcut: KeyboardShortcut) -> String {
        var parts: [String] = []
        if shortcut.modifiers.contains(.command) { parts.append("⌘") }
        if shortcut.modifiers.contains(.option) { parts.append("⌥") }
        if shortcut.modifiers.contains(.shift) { parts.append("⇧") }
        parts.append(shortcut.key.uppercased())
        return parts.joined()
    }
}

struct SidebarCompactItemRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.16) : AppSurfaceTokens.cardBackground.opacity(0.92))
                    .frame(width: 26, height: 26)

                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
                    .accessibilityHidden(true)
            }

            Text(item.compactName)
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(AppSurfaceTokens.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 0)

            if (isHovered || isSelected), let shortcut = item.shortcut {
                Text(shortcutDisplay(shortcut))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(isSelected ? AppSurfaceTokens.accentBlue : AppSurfaceTokens.secondaryText)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isSelected ? AppSurfaceTokens.accentBlue.opacity(0.10) : (isHovered ? AppSurfaceTokens.cardBackground.opacity(0.88) : Color.clear))
        )
        .contentShape(Rectangle())
        .help(item.displayName)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName)\(isSelected ? "，当前页面" : "")")
    }

    private func shortcutDisplay(_ shortcut: KeyboardShortcut) -> String {
        var parts: [String] = []
        if shortcut.modifiers.contains(.command) { parts.append("⌘") }
        if shortcut.modifiers.contains(.option) { parts.append("⌥") }
        if shortcut.modifiers.contains(.shift) { parts.append("⇧") }
        parts.append(shortcut.key.uppercased())
        return parts.joined()
    }
}

private struct SidebarFooterStatus: Sendable, Equatable {
    var serviceState: String
    var modelLabel: String

    static let loading = SidebarFooterStatus(serviceState: "本地服务加载中", modelLabel: "自动路由")
}

private struct SidebarFooter: View {
    let status: SidebarFooterStatus
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppSurfaceTokens.accentGreen.opacity(0.9))
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                    Text(status.serviceState)
                        .font(.system(size: compact ? 9.5 : 10.5, weight: .semibold))
                        .foregroundStyle(AppSurfaceTokens.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Text("模型 · \(status.modelLabel)")
                    .font(.system(size: compact ? 9 : 10))
                    .foregroundStyle(AppSurfaceTokens.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: compact ? 11 : AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .fill(AppSurfaceTokens.cardBackground.opacity(compact ? 0.9 : 0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 11 : AppSurfaceTokens.secondaryCardRadius, style: .continuous)
                .stroke(AppSurfaceTokens.separator.opacity(0.72), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.serviceState)，模型：\(status.modelLabel)")
    }
}

// MARK: - Sidebar Item Badge

struct SidebarItemBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red)
                .clipShape(Capsule(style: .continuous))
        }
    }
}
