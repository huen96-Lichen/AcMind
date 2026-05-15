import SwiftUI
import AcMindKit
import struct AcMindKit.KeyboardShortcut

struct ContentView: View {
    @ObservedObject private var appState = AppState.shared
    @State private var showVoicePanel = false
    @State private var showCapturePanel = false
    @State private var showQuickNote = false

    var body: some View {
        AppShell(selectedItem: $appState.sidebarSelection)
            .background(ACColors.pageBackground.ignoresSafeArea())
            .sheet(isPresented: $showVoicePanel) {
                CompanionVoicePanel()
            }
            .sheet(isPresented: $showCapturePanel) {
                CompanionCapturePanel()
            }
            .sheet(isPresented: $showQuickNote) {
                QuickNotePanel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowAgent)) { _ in
                appState.selectSidebarItem(.agent)
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowInbox)) { _ in
                appState.selectSidebarItem(.inbox)
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowSchedule)) { _ in
                appState.selectSidebarItem(.schedule)
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowVoicePanel)) { _ in
                showVoicePanel = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowCapturePanel)) { _ in
                showCapturePanel = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .companionShowQuickNote)) { _ in
                showQuickNote = true
            }
    }
}

struct AppShell: View {
    @Binding var selectedItem: SidebarItem
    @State private var hoveredItem: SidebarItem?

    var body: some View {
        HStack(spacing: 0) {
            AppSidebar(selectedItem: $selectedItem, hoveredItem: $hoveredItem)
                .frame(width: ACLayout.sidebarWidth)

            Divider()
                .overlay(ACColors.border)

            AppWorkspace(selectedItem: selectedItem)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ACColors.pageBackground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AppSidebar: View {
    @Binding var selectedItem: SidebarItem
    @Binding var hoveredItem: SidebarItem?

    var body: some View {
        VStack(spacing: 0) {
            sidebarChrome
                .padding(.top, 16)
                .padding(.leading, 18)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(SidebarItem.mainItems) { item in
                        AppSidebarRow(
                            item: item,
                            isSelected: selectedItem == item,
                            isHovered: hoveredItem == item
                        ) {
                            selectedItem = item
                        }
                        .onHover { isHovered in
                            hoveredItem = isHovered ? item : nil
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }

            Spacer(minLength: 0)

            userProfileSection
        }
        .background(ACColors.sidebarBackground)
    }

    private var sidebarChrome: some View {
        HStack(spacing: 8) {
            Circle().fill(ACColors.accentRed).frame(width: 10, height: 10)
            Circle().fill(ACColors.accentYellow).frame(width: 10, height: 10)
            Circle().fill(ACColors.accentGreen).frame(width: 10, height: 10)
            Spacer(minLength: 0)
        }
        .frame(width: ACLayout.sidebarNavWidth)
    }

    private var userProfileSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(ACColors.accentPurple)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("AcMind")
                    .font(ACTypography.itemTitle)
                    .foregroundStyle(ACColors.primaryText)

                Text("Pro")
                    .font(ACTypography.miniMedium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, ACLayout.gapS - 2)
                    .padding(.vertical, 2)
                    .background(ACColors.accentPurple)
                    .clipShape(RoundedRectangle(cornerRadius: ACLayout.tinyRadius, style: .continuous))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.down")
                .font(.system(size: ACLayout.iconM))
                .foregroundStyle(ACColors.secondaryText)
        }
        .frame(width: ACLayout.sidebarUserWidth, height: ACLayout.sidebarUserHeight)
        .padding(.horizontal, 12)
        .background(ACColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ACLayout.cardRadius - 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.cardRadius - 2, style: .continuous)
                .stroke(ACColors.border, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

struct AppSidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: ACLayout.iconL, weight: .medium))
                    .frame(width: 18, height: 18)
                    .foregroundStyle(isSelected ? .white : ACColors.primaryText)

                Text(item.title)
                    .font(isSelected ? ACTypography.itemTitle : ACTypography.bodyMedium)
                    .foregroundStyle(isSelected ? .white : ACColors.primaryText)

                Spacer(minLength: 0)

                if let shortcut = item.shortcut {
                    Text(shortcutDisplay(shortcut))
                        .font(ACTypography.monospacedMini)
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : ACColors.tertiaryText)
                }
            }
            .frame(width: ACLayout.sidebarNavWidth, height: ACLayout.sidebarNavHeight, alignment: .leading)
            .padding(.horizontal, ACLayout.gapM - 2)
            .background(
                RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                    .fill(isSelected ? ACColors.accentBlue : (isHovered ? ACColors.softFill : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ACLayout.smallRadius, style: .continuous)
                    .stroke(isSelected ? ACColors.accentBlue.opacity(0.15) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

struct AppWorkspace: View {
    let selectedItem: SidebarItem

    var body: some View {
        MainContent(selectedItem: selectedItem)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MainContent: View {
    let selectedItem: SidebarItem

    var body: some View {
        Group {
            switch selectedItem {
            case .agent:
                AgentWorkspaceView()
            case .dynamicSurface:
                DynamicSurfaceSettingsView()
            case .inbox:
                InboxWorkspaceView()
            case .clipboard:
                ClipboardWorkspaceView()
            case .schedule:
                ScheduleDashboardView()
            case .workbench:
                WorkbenchView()
            case .tools:
                ToolsView()
            case .companion:
                CompanionView()
            case .settings:
                SettingsSuiteView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
