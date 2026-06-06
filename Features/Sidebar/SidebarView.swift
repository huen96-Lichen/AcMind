import SwiftUI
import AppKit
import struct AcMindKit.KeyboardShortcut
import enum AcMindKit.SidebarItem

// MARK: - Sidebar View

/// 侧边栏导航视图
/// 使用固定宽度的自绘布局，避免 macOS sidebar 样式在窗口变窄时自动折叠成图标栏。
struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: ServiceContainer
    @State private var hoveredItem: SidebarItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sidebarHeader
                sidebarSection(title: "核心工作流", items: SidebarItem.coreWorkflow)
                sidebarSection(title: "伴随能力", items: SidebarItem.companionCapabilities)
                sidebarSection(title: "系统", items: SidebarItem.systemItems)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
        .frame(width: AppSurfaceTokens.Layout.sidebarWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(AppSurfaceTokens.sidebarBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
                .help("切换侧边栏")
            }
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
    }

    private func sidebarSection(title: String, items: [SidebarItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sidebarSectionHeader(title)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(items) { item in
                    Button {
                        appState.selectSidebarItem(item)
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

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AcMind")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            Text("主导航")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private func sidebarSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(AppSurfaceTokens.secondaryText)
            .textCase(nil)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }

    private func toggleSidebar() {
        appState.toggleSidebar()
    }

    private func setupKeyboardShortcuts() {
        // 快捷键已在 AppState 中定义
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : AppSurfaceTokens.cardBackgroundSoft.opacity(0.9))
                    .frame(width: 24, height: 24)

                Image(systemName: item.icon)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : AppSurfaceTokens.secondaryText)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.system(size: 12.75, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.72)
                    .layoutPriority(1)
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                if item.group == .companionCapabilities {
                    Text("伴随能力")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 6)

            if let shortcut = item.shortcut {
                Text(shortcutDisplay(shortcut))
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.accentColor : AppSurfaceTokens.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.accentColor.opacity(0.08) : AppSurfaceTokens.cardBackgroundSoft.opacity(0.85))
                    )
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : (isHovered ? AppSurfaceTokens.cardBackgroundSoft.opacity(0.72) : Color.clear))
        )
        .foregroundStyle(AppSurfaceTokens.primaryText)
        .contentShape(Rectangle())
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
                .cornerRadius(10)
        }
    }
}
