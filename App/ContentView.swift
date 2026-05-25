import SwiftUI
import AcMindKit

// MARK: - Content View
// AcMind 主应用框架

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showVoicePanel = false
    @State private var showCapturePanel = false
    @State private var showQuickNote = false

    private var selectedItemBinding: Binding<SidebarItem> {
        Binding(
            get: { appState.sidebarSelection },
            set: { appState.selectSidebarItem($0) }
        )
    }

    var body: some View {
        NavigationSplitView {
            MainSidebar(selectedItem: selectedItemBinding)
        } detail: {
            MainContent(selectedItem: appState.sidebarSelection)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationSplitViewColumnWidth(min: 224, ideal: 248, max: 280)
        .background(AppSurfaceTokens.background.ignoresSafeArea())
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

// MARK: - Main Sidebar

struct MainSidebar: View {
    @Binding var selectedItem: SidebarItem
    @State private var hoveredItem: SidebarItem?

    var body: some View {
        List(selection: $selectedItem) {
            sidebarHeader

            Section("核心工作流") {
                ForEach(SidebarItem.coreWorkflow) { item in
                    SidebarItemView(
                        item: item,
                        isSelected: selectedItem == item,
                        isHovered: hoveredItem == item
                    )
                    .tag(item)
                    .onHover { isHovered in
                        hoveredItem = isHovered ? item : nil
                    }
                }
            }

            Section("伴随能力") {
                ForEach(SidebarItem.companionCapabilities) { item in
                    SidebarItemView(
                        item: item,
                        isSelected: selectedItem == item,
                        isHovered: hoveredItem == item
                    )
                    .tag(item)
                    .onHover { isHovered in
                        hoveredItem = isHovered ? item : nil
                    }
                }
            }

            Section("系统") {
                ForEach(SidebarItem.systemItems) { item in
                    SidebarItemView(
                        item: item,
                        isSelected: selectedItem == item,
                        isHovered: hoveredItem == item
                    )
                    .tag(item)
                    .onHover { isHovered in
                        hoveredItem = isHovered ? item : nil
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(AppSurfaceTokens.sidebarBackground.ignoresSafeArea())
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AcMind")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppSurfaceTokens.primaryText)

            Text("一级菜单")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppSurfaceTokens.secondaryText)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }
}

// MARK: - Sidebar Item View

struct SidebarItemView: View {
    let item: SidebarItem
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : AppSurfaceTokens.cardBackgroundSoft)
                    .frame(width: 28, height: 28)

                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : AppSurfaceTokens.secondaryText)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(AppSurfaceTokens.primaryText)

                if item.group == .companionCapabilities {
                    Text("伴随能力")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppSurfaceTokens.secondaryText)
                }
            }

            Spacer(minLength: 8)

            if let shortcut = item.shortcut {
                Text(shortcut.displayString)
                    .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.accentColor : AppSurfaceTokens.secondaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.accentColor.opacity(0.10) : AppSurfaceTokens.cardBackgroundSoft)
                    )
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.10) : (isHovered ? AppSurfaceTokens.cardBackgroundSoft : Color.clear))
        )
        .foregroundStyle(AppSurfaceTokens.primaryText)
        .contentShape(Rectangle())
    }
}

// MARK: - Main Content

struct MainContent: View {
    let selectedItem: SidebarItem

    var body: some View {
        Group {
            switch selectedItem {
            case .agent:
                AgentDashboardView()
                    .navigationTitle("Agent")
            case .inbox:
                InboxView()
                    .navigationTitle("收集箱")
            case .clipboard:
                ClipboardView()
                    .navigationTitle("剪贴板 & 手机响")
            case .schedule:
                ScheduleDashboardView()
                    .navigationTitle("日程")
            case .workbench:
                ToolsView()
                    .navigationTitle("工具台")
            case .dynamicContinent:
                DynamicContinentConfigView()
                    .navigationTitle("灵动大陆 & 配置")
            case .systemStatus:
                SystemStatusView()
                    .navigationTitle("系统状态")
            case .voiceEntry:
                VoiceEntryView()
                    .navigationTitle("语音入口")
            case .settings:
                SettingsSuiteView()
                    .navigationTitle("设置")
            }
        }
    }
}
