import Foundation
import Combine
import AcMindKit

// MARK: - Window State

public enum WindowState: Sendable, Equatable {
    case closed
    case minimized
    case normal
    case fullscreen
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

    @Published public var sidebarSelection: SidebarItem = .home
    @Published public var sidebarCollapsed = false
    @Published public var inboxWorkspaceSelection: String? = "all"
    @Published public var pendingInboxDetailSourceItemID: String?
    @Published var pendingWorkbenchToolRoute: ToolRoute?
    @Published var pendingSettingsCategory: SettingsCategory?

    // MARK: - Window State

    @Published public var mainWindowState: WindowState = .closed
    @Published public var capsuleWindowState: WindowState = .closed
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

    private var cancellables = Set<AnyCancellable>()
    private var shortcutHandlers: [KeyboardShortcut: () -> Void] = [:]

    public init() {
        checkFirstLaunch()
    }

    public func bindServiceContainerState(_ container: ServiceContainer) {
        container.$currentPhase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                guard let self else { return }
                self.initializationPhase = phase
                self.isInitializing = phase != .idle && phase != .completed && phase != .failed
            }
            .store(in: &cancellables)

        container.$initializationError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self else { return }
                if let error {
                    self.initializationError = error
                    self.showError(AppError.initializationFailed(error))
                } else {
                    self.initializationError = nil
                }
            }
            .store(in: &cancellables)

        container.$isInitialized
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAppReady)
    }

    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunchedBefore {
            isFirstLaunch = true
            showOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }

    // MARK: - Navigation

    public func navigate(to item: SidebarItem) {
        navigate(to: item, workbenchToolRoute: nil, settingsCategory: nil)
    }

    func navigate(to item: SidebarItem, workbenchToolRoute: ToolRoute) {
        navigate(to: item, workbenchToolRoute: workbenchToolRoute, settingsCategory: nil)
    }

    func navigate(to item: SidebarItem, settingsCategory: SettingsCategory) {
        navigate(to: item, workbenchToolRoute: nil, settingsCategory: settingsCategory)
    }

    func navigate(
        to item: SidebarItem,
        workbenchToolRoute: ToolRoute?,
        settingsCategory: SettingsCategory?
    ) {
        if item == .screenshotHistory {
            pendingWorkbenchToolRoute = nil
            pendingSettingsCategory = nil
            selectInboxWorkspace("screenshotHistory")
            return
        }
        if item == .workbench {
            pendingWorkbenchToolRoute = workbenchToolRoute
            pendingSettingsCategory = nil
        } else if item == .settings {
            pendingSettingsCategory = settingsCategory
        } else {
            pendingWorkbenchToolRoute = nil
            pendingSettingsCategory = nil
        }
        sidebarSelection = canonicalSidebarItem(for: item)
    }

    public func navigateToInbox(workspace selection: String? = "all") {
        selectInboxWorkspace(selection)
    }

    public func selectInboxWorkspace(_ selection: String?) {
        let resolvedSelection = selection ?? "all"
        inboxWorkspaceSelection = resolvedSelection
        pendingWorkbenchToolRoute = nil
        pendingSettingsCategory = nil
        sidebarSelection = .inbox
    }

    private func canonicalSidebarItem(for item: SidebarItem) -> SidebarItem {
        if item == .screenshotHistory {
            return .inbox
        }
        return item
    }

    public func toggleSidebar() {
        sidebarCollapsed.toggle()
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

    public func capsuleWindowDidClose() {
        capsuleWindowState = .closed
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

    // MARK: - Launch Flow

    public func retryInitialization() async {
        initializationError = nil
        do {
            let container = try await ServiceContainer.setup()
            bindServiceContainerState(container)
        } catch {
            showError(AppError.initializationFailed(error))
        }
    }
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
