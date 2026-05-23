import Foundation
import AppKit
import AVFoundation
import CoreGraphics
import UserNotifications

// MARK: - App Permission Kind

/// 应用权限类型
public enum AppPermissionKind: String, CaseIterable, Sendable, Hashable {
    case microphone
    case screenRecording
    case accessibility
    case fullDiskAccess
    case notifications

    public var displayName: String {
        switch self {
        case .microphone: return "麦克风"
        case .screenRecording: return "屏幕录制"
        case .accessibility: return "辅助功能"
        case .fullDiskAccess: return "完全磁盘访问"
        case .notifications: return "通知"
        }
    }

    public var iconName: String {
        switch self {
        case .microphone: return "mic.fill"
        case .screenRecording: return "rectangle.on.rectangle.fill"
        case .accessibility: return "figure.stand"
        case .fullDiskAccess: return "internaldrive.fill"
        case .notifications: return "bell.fill"
        }
    }

    /// 该权限是否能通过系统弹窗直接申请
    public var supportsSystemPrompt: Bool {
        switch self {
        case .microphone, .notifications:
            return true
        case .screenRecording, .accessibility, .fullDiskAccess:
            return false
        }
    }
}

// MARK: - App Permission Status

/// 权限状态
public enum AppPermissionStatus: Sendable, Hashable {
    /// 尚未检查
    case unknown
    /// 从未请求
    case notDetermined
    /// 正在请求中
    case requesting
    /// 已授权
    case authorized
    /// 已拒绝
    case denied
    /// 受限（如家长控制）
    case restricted
    /// 需要去系统设置手动开启
    case needsSystemSettings
    /// 检测或请求失败
    case failed(String)

    public var displayName: String {
        switch self {
        case .unknown: return "未知"
        case .notDetermined: return "未确定"
        case .requesting: return "请求中..."
        case .authorized: return "已授权"
        case .denied: return "已拒绝"
        case .restricted: return "受限"
        case .needsSystemSettings: return "需系统设置"
        case .failed: return "失败"
        }
    }

    /// 是否可交互（非请求中）
    public var isInteractive: Bool {
        if case .requesting = self { return false }
        return true
    }
}

// MARK: - Permission Manager

/// macOS 系统权限管理器
/// - 所有状态更新在主线程
/// - 权限申请全程异步，绝不阻塞
/// - 带详细日志
@MainActor
public final class PermissionManager: ObservableObject {

    // MARK: - Published State

    /// 各权限当前状态
    @Published public private(set) var statuses: [AppPermissionKind: AppPermissionStatus] = [:]

    // MARK: - Track Prompt History

    /// 记录哪些权限已经被提示过（用于区分 denied / notDetermined）
    private var hasPrompted: Set<AppPermissionKind> = []

    // MARK: - Logger

    private func log(_ message: String) {
        print("[AcMind.Permission] \(message)")
    }

    // MARK: - Init

    public init() {
        // 初始化为 unknown，等待 refreshAll() 调用
        for kind in AppPermissionKind.allCases {
            statuses[kind] = .unknown
        }
        log("PermissionManager initialized")
    }

    // MARK: - Refresh All

    /// 刷新所有权限状态（异步，不阻塞）
    public func refreshAll() async {
        log("refreshAll started")
        for kind in AppPermissionKind.allCases {
            await refresh(kind)
        }
        log("refreshAll finished")
    }

    /// 刷新单个权限状态（不经由 requesting 状态）
    public func refresh(_ kind: AppPermissionKind) async {
        log("refresh \(kind.rawValue) started")
        let status = await checkStatus(kind)
        // 只在非 requesting 状态下更新
        if case .requesting = statuses[kind] {
            // 如果正在请求中，保留 requesting 避免 UI 闪烁
            return
        }
        statuses[kind] = status
        log("refresh \(kind.rawValue) result: \(status.displayName)")
    }

    // MARK: - Request Permission

    /// 请求某权限（异步，不阻塞，带 requesting 过渡态）
    public func request(_ kind: AppPermissionKind) async {
        log("request \(kind.rawValue) started")

        // 先检查一次当前状态
        let currentStatus = await checkStatus(kind)
        log("request \(kind.rawValue) current status: \(currentStatus.displayName)")

        // 如果已授权，直接更新
        if currentStatus == .authorized {
            statuses[kind] = .authorized
            log("request \(kind.rawValue) already authorized, skipping")
            return
        }

        // 如果已拒绝，标记需要去设置
        if currentStatus == .denied {
            statuses[kind] = .needsSystemSettings
            log("request \(kind.rawValue) already denied, needs system settings")
            return
        }

        // 进入请求态
        statuses[kind] = .requesting
        log("request \(kind.rawValue) entering requesting state")

        // 执行请求
        let result: AppPermissionStatus
        do {
            try await performRequest(kind)
            // 请求后再次检查
            result = await checkStatus(kind)
        } catch {
            log("request \(kind.rawValue) error: \(error.localizedDescription)")
            if let permError = error as? PermissionError, case .requiresManualGrant = permError {
                result = .needsSystemSettings
            } else {
                result = .failed(error.localizedDescription)
            }
        }

        // 标记已提示
        hasPrompted.insert(kind)

        // 更新状态
        statuses[kind] = result
        log("request \(kind.rawValue) result: \(result.displayName)")
        log("request \(kind.rawValue) finished")
    }

    // MARK: - Open Privacy Settings

    /// 统一打开系统设置 → 隐私与安全性
    public func openPrivacySettings() {
        log("openPrivacySettings called")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        } else {
            // 降级：打开安全性与隐私
            guard let fallbackURL = URL(string: "x-apple.systempreferences:com.apple.preference.security") else {
                return
            }
            NSWorkspace.shared.open(fallbackURL)
        }
    }

    /// 打开指定权限的系统设置面板
    public func openSettingsFor(_ kind: AppPermissionKind) {
        log("openSettingsFor \(kind.rawValue) called")
        let anchor: String
        switch kind {
        case .microphone:
            anchor = "Privacy_Microphone"
        case .screenRecording:
            anchor = "Privacy_ScreenCapture"
        case .accessibility:
            anchor = "Privacy_Accessibility"
        case .fullDiskAccess:
            anchor = "Privacy_AllFiles"
        case .notifications:
            // 通知面板不是 Privacy 子面板
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                NSWorkspace.shared.open(url)
                return
            }
            anchor = "Privacy"
        }

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        } else {
            openPrivacySettings()
        }
    }

    // MARK: - Check Status (internal)

    private func checkStatus(_ kind: AppPermissionKind) async -> AppPermissionStatus {
        switch kind {
        case .microphone:
            return checkMicrophone()
        case .screenRecording:
            return checkScreenRecording()
        case .accessibility:
            return checkAccessibility()
        case .fullDiskAccess:
            return checkFullDiskAccess()
        case .notifications:
            return await checkNotifications()
        }
    }

    // MARK: - Perform Request (internal)

    private func performRequest(_ kind: AppPermissionKind) async throws {
        switch kind {
        case .microphone:
            try await requestMicrophone()
        case .screenRecording:
            try requestScreenRecording()
        case .accessibility:
            try requestAccessibility()
        case .fullDiskAccess:
            throw PermissionError.requiresManualGrant(.fullDiskAccess)
        case .notifications:
            try await requestNotifications()
        }
    }

    // MARK: - Microphone

    private func checkMicrophone() -> AppPermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        @unknown default: return .unknown
        }
    }

    private func requestMicrophone() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            log("requestMicrophone: showing system prompt")
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            log("requestMicrophone: system prompt result = \(granted)")
            if !granted {
                throw PermissionError.denied(.microphone)
            }
        } else if status != .authorized {
            throw PermissionError.denied(.microphone)
        }
    }

    // MARK: - Screen Recording

    private func checkScreenRecording() -> AppPermissionStatus {
        // CGPreflightScreenCaptureAccess 无法区分 notDetermined 和 denied
        let hasAccess = CGPreflightScreenCaptureAccess()
        if hasAccess {
            return .authorized
        }
        // 如果之前已经提示过，认为是 denied
        // 如果从未提示过，认为是 notDetermined
        return hasPrompted.contains(.screenRecording) ? .denied : .notDetermined
    }

    private func requestScreenRecording() throws {
        log("requestScreenRecording: triggering prompt")
        // CGRequestScreenCaptureAccess() 显示系统弹窗（同步但立即返回）
        // 注意：此调用在沙盒中可能不弹出标准 TCC 对话框
        let granted = CGRequestScreenCaptureAccess()
        log("requestScreenRecording: result = \(granted)")
        if !granted {
            throw PermissionError.requiresManualGrant(.screenRecording)
        }
    }

    // MARK: - Accessibility

    private func checkAccessibility() -> AppPermissionStatus {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if trusted {
            return .authorized
        }
        return hasPrompted.contains(.accessibility) ? .denied : .notDetermined
    }

    private func requestAccessibility() throws {
        log("requestAccessibility: triggering system prompt (will open System Settings)")
        // 显示系统提示 — 这会打开系统设置的辅助功能面板
        // 该调用是同步的但会立即返回，不会阻塞等待用户操作
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        log("requestAccessibility: trusted after prompt = \(trusted)")
        if !trusted {
            throw PermissionError.requiresManualGrant(.accessibility)
        }
    }

    // MARK: - Full Disk Access

    private func checkFullDiskAccess() -> AppPermissionStatus {
        // 尝试读取 TCC.db 作为代理检测
        let testPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        let accessible = FileManager.default.isReadableFile(atPath: testPath)
        return accessible ? .authorized : .denied
    }

    // MARK: - Notifications

    private func checkNotifications() async -> AppPermissionStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let result: AppPermissionStatus
                switch settings.authorizationStatus {
                case .notDetermined:
                    result = .notDetermined
                case .denied:
                    result = .denied
                case .authorized, .provisional, .ephemeral:
                    result = .authorized
                @unknown default:
                    result = .unknown
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func requestNotifications() async throws {
        log("requestNotifications: showing system prompt")
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        log("requestNotifications: result = \(granted)")
        if !granted {
            throw PermissionError.denied(.notifications)
        }
    }
}

// MARK: - Errors

public enum PermissionError: Error, LocalizedError {
    case denied(SystemPermission)
    case restricted(SystemPermission)
    case requiresManualGrant(SystemPermission)
    case deniedKind(AppPermissionKind)
    case restrictedKind(AppPermissionKind)
    case requiresManualGrantKind(AppPermissionKind)

    public var errorDescription: String? {
        switch self {
        case .denied(let permission):
            return "\(permission.displayName) 权限被拒绝"
        case .restricted(let permission):
            return "\(permission.displayName) 权限受限"
        case .requiresManualGrant(let permission):
            return "请在系统设置中手动授予 \(permission.displayName) 权限"
        case .deniedKind(let kind):
            return "\(kind.displayName) 权限被拒绝"
        case .restrictedKind(let kind):
            return "\(kind.displayName) 权限受限"
        case .requiresManualGrantKind(let kind):
            return "请在系统设置中手动授予 \(kind.displayName) 权限"
        }
    }

    public var recoverySuggestion: String? {
        "请前往系统设置 > 隐私与安全性 中开启权限"
    }
}
