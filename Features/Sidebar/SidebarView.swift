import SwiftUI
import AppKit
import struct AcMindKit.KeyboardShortcut

// MARK: - Sidebar View

/// 侧边栏导航视图
/// 使用原生 macOS 风格，支持快捷键导航
struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var container: ServiceContainer

    var body: some View {
        List(SidebarItem.allCases, selection: $appState.sidebarSelection) { item in
            SidebarItemRow(item: item, isSelected: appState.sidebarSelection == item)
                .tag(item)
        }
        .listStyle(.sidebar)
        .navigationTitle("AcMind")
        .toolbar {
            ToolbarItem {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
                .help("切换侧边栏")
            }
        }
        .onAppear {
            // 设置快捷键处理
            setupKeyboardShortcuts()
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)),
            with: nil
        )
    }

    private func setupKeyboardShortcuts() {
        // 快捷键已在 AppState 中定义
    }
}

// MARK: - Sidebar Item Row

struct SidebarItemRow: View {
    let item: SidebarItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: ACLayout.iconL, weight: .medium))
                .frame(width: ACLayout.iconL, height: ACLayout.iconL)
                .foregroundStyle(isSelected ? .white : ACColors.primaryText)

            Text(item.title)
                .font(isSelected ? ACTypography.bodyMedium : ACTypography.body)
                .foregroundStyle(isSelected ? .white : ACColors.primaryText)

            Spacer()

            // 快捷键提示
            if let shortcut = item.shortcut {
                Text(shortcutDisplay(shortcut))
                    .font(ACTypography.mini)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : ACColors.secondaryText)
                    .padding(.horizontal, ACLayout.gapS - 2)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : ACColors.softFill)
                    .clipShape(RoundedRectangle(cornerRadius: ACLayout.tinyRadius, style: .continuous))
            }
        }
        .padding(.vertical, ACLayout.gapXS)
        .padding(.horizontal, ACLayout.gapS)
        .background(isSelected ? ACColors.accentBlue : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous))
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
                .font(ACTypography.miniMedium)
                .foregroundStyle(Color.white)
                .padding(.horizontal, ACLayout.gapS - 2)
                .padding(.vertical, 2)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: ACLayout.capsuleRadius, style: .continuous))
        }
    }
}
