import Foundation
import AcMindKit

// MARK: - Window State

public enum WindowState: Sendable, Equatable {
    case closed
    case minimized
    case normal
    case fullscreen
}

// MARK: - Primary Rail Mode

public enum PrimaryRailMode: String, Codable, CaseIterable, Sendable {
    case compact
    case expanded
}

// MARK: - Workspace Mode

public enum WorkspaceMode: String, Codable, CaseIterable, Sendable {
    case visible
    case collapsed
    case hidden
}

// MARK: - App State

/// 全局应用状态管理
/// 职责：
/// 1. 导航状态（当前选中的侧边栏项）
/// 2. 窗口状态（主窗口、胶囊窗口）
/// 3. 启动状态（从 ServiceContainer 同步）
/// 4. 全局错误处理
/// 5. 快捷键注册
@MainActor
public final class AppState: ObservableObject, Sendable {
    // MARK: - Singleton

    public static let shared = AppState()

    // MARK: - Navigation State

    @Published public var sidebarSelection: SidebarItem = .agent
    @Published public var sidebarCollapsed = false

    // MARK: - Primary Rail & Workspace State

    @Published public var primaryRailMode: PrimaryRailMode = .compact {
        didSet {
            guard shouldPersistWorkspaceLayout else { return }
            UserDefaults.standard.set(primaryRailMode.rawValue, forKey: Self.primaryRailModeKey)
        }
    }

    @Published public var primaryRailWidth: CGFloat = ACLayout.primaryRailCompact

    @Published public var workspaceMode: WorkspaceMode = .visible {
        didSet {
            guard shouldPersistWorkspaceLayout else { return }
            if workspaceMode != .hidden {
                UserDefaults.standard.set(workspaceMode.rawValue, forKey: Self.workspaceModeKey)
            }
        }
    }

    private var lastNonHiddenWorkspaceMode: WorkspaceMode = .visible

    // MARK: - Window State

    @Published public var mainWindowState: WindowState = .closed
    @Published public var isMainWindowKey = false

    // MARK: - Launch State (from ServiceContainer)

    @Published public var initializationPhase: InitializationPhase = .idle
    @Published public var isInitializing = false
    @Published public var initializationError: Error?
    @Published public var isAppReady = false

    // MARK: - Global Error State

    @Published public var globalError: AppError?
    @Published public var showErrorAlert = false

    // MARK: - Feature Flags

    @Published public var showOnboarding = false
    @Published public var isFirstLaunch = false

    // MARK: - Private

    private var shortcutHandlers: [KeyboardShortcut: () -> Void] = [:]

    public init() {
        restorePersistedState()
        checkFirstLaunch()
    }

    // MARK: - Setup Sync

    public func sync(with container: ServiceContainer) {
        if initializationPhase != container.currentPhase {
            initializationPhase = container.currentPhase
        }

        let initializing = container.currentPhase != .idle && container.currentPhase != .completed && container.currentPhase != .failed
        if isInitializing != initializing {
            isInitializing = initializing
        }

        if let containerError = container.initializationError {
            if initializationError?.localizedDescription != containerError.localizedDescription {
                initializationError = containerError
                showError(AppError.initializationFailed(containerError))
            }
        } else if initializationError != nil {
            initializationError = nil
            if case .initializationFailed = globalError {
                clearError()
            }
        }

        if isAppReady != container.isInitialized {
            isAppReady = container.isInitialized
        }
    }

    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunchedBefore {
            isFirstLaunch = true
            showOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }

    // MARK: - State Persistence

    private func restorePersistedState() {
        if shouldPersistWorkspaceLayout {
            if let savedWidth = UserDefaults.standard.object(forKey: Self.primaryRailWidthKey) as? NSNumber {
                primaryRailWidth = clampPrimaryRailWidth(CGFloat(truncating: savedWidth))
                primaryRailMode = primaryRailWidth >= ACLayout.primaryRailLabelThreshold ? .expanded : .compact
            } else if let saved = UserDefaults.standard.string(forKey: Self.primaryRailModeKey),
                      let mode = PrimaryRailMode(rawValue: saved) {
                primaryRailMode = mode
                primaryRailWidth = mode == .compact ? ACLayout.primaryRailCompact : ACLayout.primaryRailExpanded
            }
            if let saved = UserDefaults.standard.string(forKey: Self.workspaceModeKey),
               let mode = WorkspaceMode(rawValue: saved),
               mode != .hidden {
                workspaceMode = mode
                lastNonHiddenWorkspaceMode = mode
            }
        } else {
            primaryRailMode = .compact
            primaryRailWidth = ACLayout.primaryRailCompact
            workspaceMode = .visible
        }
    }

    // MARK: - Workspace Mode Actions

    public func handleCloseForeground() {
        lastNonHiddenWorkspaceMode = workspaceMode == .hidden ? lastNonHiddenWorkspaceMode : workspaceMode
        workspaceMode = .hidden
    }

    public func handleCollapseWorkspace() {
        if workspaceMode != .hidden {
            lastNonHiddenWorkspaceMode = workspaceMode
        }
        workspaceMode = .collapsed
    }

    public func handleExpandWorkspace() {
        workspaceMode = lastNonHiddenWorkspaceMode == .collapsed ? .visible : lastNonHiddenWorkspaceMode
        lastNonHiddenWorkspaceMode = workspaceMode
    }

    public func toggleSecondaryInterface() {
        switch workspaceMode {
        case .visible:
            handleCollapseWorkspace()
        case .collapsed:
            handleExpandWorkspace()
        case .hidden:
            restoreWorkspaceFromHidden()
        }
    }

    public func restoreWorkspaceFromHidden() {
        workspaceMode = lastNonHiddenWorkspaceMode
    }

    public func ensureWorkspaceModeNotHidden() {
        if workspaceMode == .hidden {
            workspaceMode = lastNonHiddenWorkspaceMode
        }
    }

    // MARK: - Navigation

    public func selectSidebarItem(_ item: SidebarItem) {
        sidebarSelection = item
    }

    public func toggleSidebar() {
        sidebarCollapsed.toggle()
    }

    public func setPrimaryRailWidth(_ width: CGFloat) {
        let clampedWidth = clampPrimaryRailWidth(width)
        guard primaryRailWidth != clampedWidth else { return }

        primaryRailWidth = clampedWidth

        if shouldPersistWorkspaceLayout {
            UserDefaults.standard.set(Double(clampedWidth), forKey: Self.primaryRailWidthKey)
        }

        let derivedMode: PrimaryRailMode = clampedWidth >= ACLayout.primaryRailLabelThreshold ? .expanded : .compact
        if primaryRailMode != derivedMode {
            primaryRailMode = derivedMode
        }

        guard workspaceMode == .collapsed else { return }
        NotificationCenter.default.post(
            name: Notification.Name("AcMind.workspaceRailWidthChanged"),
            object: nil,
            userInfo: ["railWidth": clampedWidth]
        )
    }

    // MARK: - Window Management

    public func mainWindowDidOpen() {
        mainWindowState = .normal
    }

    public func mainWindowDidClose() {
        mainWindowState = .closed
    }

    public func mainWindowDidBecomeKey() {
        isMainWindowKey = true
    }

    public func mainWindowDidResignKey() {
        isMainWindowKey = false
    }

    // MARK: - Error Handling

    public func showError(_ error: AppError) {
        globalError = error
        showErrorAlert = true
    }

    public func clearError() {
        globalError = nil
        showErrorAlert = false
    }

    // MARK: - Shortcuts

    public func registerShortcut(_ shortcut: KeyboardShortcut, action: @escaping () -> Void) {
        shortcutHandlers[shortcut] = action
    }

    public func unregisterShortcut(_ shortcut: KeyboardShortcut) {
        shortcutHandlers.removeValue(forKey: shortcut)
    }

    public func handleShortcut(_ shortcut: KeyboardShortcut) -> Bool {
        if let action = shortcutHandlers[shortcut] {
            action()
            return true
        }
        return false
    }

    // MARK: - Launch Flow

    public func markOnboardingComplete() {
        showOnboarding = false
        isFirstLaunch = false
    }

    public func retryInitialization() async {
        initializationError = nil
        do {
            try await ServiceContainer.setup(appState: self)
        } catch {
            showError(AppError.initializationFailed(error))
        }
    }

    private var shouldPersistWorkspaceLayout: Bool {
        UserDefaults.standard.object(forKey: Self.rememberWorkspaceLayoutKey) as? Bool ?? true
    }

    private func clampPrimaryRailWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, ACLayout.primaryRailCompact), ACLayout.primaryRailMaxWidth)
    }

    private static let primaryRailModeKey = "AppSettings.primaryRailMode"
    private static let primaryRailWidthKey = "AppSettings.primaryRailWidth"
    private static let workspaceModeKey = "AppSettings.workspaceMode"
    private static let rememberWorkspaceLayoutKey = "AppSettings.rememberWorkspaceLayout"
}

// MARK: - App Error

public enum AppError: LocalizedError, Identifiable {
    case initializationFailed(Error)
    case serviceUnavailable(String)
    case networkError(String)
    case permissionDenied(SystemPermission)
    case unknown(Error)

    public var id: String {
        switch self {
        case .initializationFailed: return "initializationFailed"
        case .serviceUnavailable(let name): return "serviceUnavailable.\(name)"
        case .networkError: return "networkError"
        case .permissionDenied(let permission): return "permissionDenied.\(permission.rawValue)"
        case .unknown: return "unknown"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "初始化失败: \(error.localizedDescription)"
        case .serviceUnavailable(let name):
            return "服务不可用: \(name)"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .permissionDenied(let permission):
            return "权限被拒绝: \(permission.displayName)"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .initializationFailed:
            return "请尝试重新启动应用。如果问题持续，请检查日志。"
        case .serviceUnavailable:
            return "请检查服务配置或稍后重试。"
        case .networkError:
            return "请检查网络连接。"
        case .permissionDenied:
            return "请在系统设置中授予所需权限。"
        case .unknown:
            return "请尝试重新启动应用。"
        }
    }
}
