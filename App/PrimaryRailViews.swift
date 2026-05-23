import SwiftUI
import AppKit
import AcMindKit

// MARK: - Primary Nav Item

struct PrimaryNavItem: View {
    let item: SidebarItem
    let isSelected: Bool
    let showsLabels: Bool
    let isHovered: Bool
    let action: () -> Void
    
    private let rowHeight = AcMindSurfaceTokens.navItemSize
    private let capsuleHeight: CGFloat = 36
    private let iconBox: CGFloat = AcMindSurfaceTokens.navIconSize
    private let labelBaselineOffset: CGFloat = -0.5

    var body: some View {
        Button(action: action) {
            HStack(spacing: showsLabels ? 10 : 0) {
                Image(systemName: item.icon)
                    .font(.system(size: showsLabels ? AcMindSurfaceTokens.navIconSize : 16.5, weight: .medium))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: iconBox, height: iconBox)
                    .foregroundStyle(isSelected ? .white : (isHovered ? ACColors.primaryText : ACColors.secondaryText))

                if showsLabels {
                    Text(item.title)
                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : ACColors.primaryText)
                        .lineLimit(1)
                        .baselineOffset(labelBaselineOffset)

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight, alignment: showsLabels ? .leading : .center)
            .padding(.horizontal, showsLabels ? 10 : 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? ACColors.accentBlue.opacity(0.92) : (isHovered ? ACColors.selectedFill.opacity(0.72) : Color.clear))
                    .frame(height: capsuleHeight)
            )
            .shadow(
                color: isSelected ? ACColors.accentBlue.opacity(0.22) : Color.clear,
                radius: isSelected ? 2.5 : 0,
                x: 0,
                y: 1
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Main Content

struct MainContent: View {
    let selectedItem: SidebarItem
    let serviceContainer: ServiceContainer
    let appState: AppState
    let toastManager: ToastManager

    var body: some View {
        Group {
            switch selectedItem {
            case .agent:
                AgentWorkspaceView(container: serviceContainer)
            case .dynamicSurface:
                DynamicSurfaceSettingsView()
            case .inbox:
                InboxWorkspaceView(container: serviceContainer, toastManager: toastManager)
            case .clipboard:
                ClipboardWorkspaceView(container: serviceContainer, toastManager: toastManager)
            case .schedule:
                ScheduleDashboardView()
            case .workbench:
                WorkbenchView()
            case .systemMonitor:
                SystemStatusPage(systemMonitorService: serviceContainer.systemMonitorService)
            case .tools:
                ToolsView()
            case .companion:
                CompanionView(container: serviceContainer, appState: appState, toastManager: toastManager)
            case .config:
                ConfigurationView()
            case .settings:
                SettingsSuiteView(container: serviceContainer)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96)),
            removal: .opacity.combined(with: .scale(scale: 0.98))
        ))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedItem)
        .background(ACColors.pageBackground)
        .clipShape(RoundedRectangle(cornerRadius: ACLayout.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ACLayout.cardRadius, style: .continuous)
                .stroke(ACColors.border.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 6)
    }
}
