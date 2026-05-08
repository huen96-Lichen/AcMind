import SwiftUI
import AcMindKit

// MARK: - Content View
// AcMind 主应用框架

struct ContentView: View {
    @State private var selectedItem: SidebarItem = .agent
    @State private var showVoicePanel = false
    @State private var showCapturePanel = false
    @State private var showQuickNote = false

    var body: some View {
        NavigationSplitView {
            MainSidebar(selectedItem: $selectedItem)
        } detail: {
            MainContent(selectedItem: selectedItem)
        }
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
            selectedItem = .agent
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShowInbox)) { _ in
            selectedItem = .inbox
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionShowSchedule)) { _ in
            selectedItem = .schedule
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
            Section {
                ForEach(SidebarItem.mainItems) { item in
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
        .frame(minWidth: 200)
    }
}

// MARK: - Sidebar Item View

struct SidebarItemView: View {
    let item: SidebarItem
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20)
                .foregroundStyle(isSelected ? Color.white : Color.primary)

            Text(item.title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))

            Spacer()

            if let shortcut = item.shortcut {
                Text(shortcut.displayString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color.secondary)
                    .opacity(0.7)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : (isHovered ? Color.secondary.opacity(0.1) : Color.clear))
        )
        .foregroundStyle(isSelected ? Color.white : Color.primary)
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
                AgentView()
                    .navigationTitle("Agent")
            case .inbox:
                InboxView()
                    .navigationTitle("收集箱")
            case .clipboard:
                ClipboardView()
                    .navigationTitle("剪贴板")
            case .schedule:
                ScheduleNativeView()
                    .navigationTitle("日程")
            case .workbench:
                WorkbenchView()
                    .navigationTitle("工作台")
            case .tools:
                ToolsView()
                    .navigationTitle("工具")
            case .companion:
                CompanionView()
                    .navigationTitle("随身")
            case .settings:
                SettingsView()
                    .navigationTitle("设置")
            }
        }
    }
}
