import Foundation
import AppKit
import AVFoundation
import CoreGraphics

// MARK: - Permission Manager

/// macOS 系统权限管理
/// 支持：麦克风、屏幕录制、辅助功能、完全磁盘访问、通知
public actor PermissionManager {
    
    // MARK: - Check Permission
    
    public func checkPermission(_ permission: SystemPermission) async -> PermissionStatus {
        switch permission {
        case .microphone:
            return checkMicrophonePermission()
        case .screenRecording:
            return await checkScreenRecordingPermission()
        case .accessibility:
            return checkAccessibilityPermission()
        case .fullDiskAccess:
            return checkFullDiskAccessPermission()
        case .notifications:
            return await checkNotificationPermission()
        }
    }
    
    // MARK: - Request Permission
    
    public func requestPermission(_ permission: SystemPermission) async throws {
        switch permission {
        case .microphone:
            try await requestMicrophonePermission()
        case .screenRecording:
            try await requestScreenRecordingPermission()
        case .accessibility:
            try await requestAccessibilityPermission()
        case .fullDiskAccess:
            try await requestFullDiskAccessPermission()
        case .notifications:
            try await requestNotificationPermission()
        }
    }
    
    // MARK: - Open System Preferences
    
    public func openSystemPreferences(for permission: SystemPermission) async {
        let url: URL?
        
        switch permission {
        case .microphone:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        case .screenRecording:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        case .accessibility:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .fullDiskAccess:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        case .notifications:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
        }
        
        if let url = url {
            await MainActor.run {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    // MARK: - Microphone
    
    private func checkMicrophonePermission() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }
    
    private func requestMicrophonePermission() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                throw PermissionError.denied(.microphone)
            }
        } else if status != .authorized {
            throw PermissionError.denied(.microphone)
        }
    }
    
    // MARK: - Screen Recording
    
    private func checkScreenRecordingPermission() async -> PermissionStatus {
        // 屏幕录制权限无法直接查询，尝试捕获屏幕来检测
        let hasPermission = await MainActor.run {
            CGPreflightScreenCaptureAccess()
        }
        
        if hasPermission {
            return .authorized
        }
        
        // 无法区分 notDetermined 和 denied，需要尝试请求
        return .notDetermined
    }
    
    private func requestScreenRecordingPermission() async throws {
        let granted = await MainActor.run {
            CGRequestScreenCaptureAccess()
        }
        
        if !granted {
            throw PermissionError.denied(.screenRecording)
        }
    }
    
    // MARK: - Accessibility
    
    private func checkAccessibilityPermission() -> PermissionStatus {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        return trusted ? .authorized : .denied
    }
    
    private func requestAccessibilityPermission() async throws {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !trusted {
            // 用户需要手动在系统设置中授权
            throw PermissionError.requiresManualGrant(.accessibility)
        }
    }
    
    // MARK: - Full Disk Access
    
    private func checkFullDiskAccessPermission() -> PermissionStatus {
        // 尝试读取一个受保护的目录来检测权限
        let testPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        let accessible = FileManager.default.isReadableFile(atPath: testPath)
        
        return accessible ? .authorized : .denied
    }
    
    private func requestFullDiskAccessPermission() async throws {
        // 完全磁盘访问权限需要用户手动在系统设置中授权
        throw PermissionError.requiresManualGrant(.fullDiskAccess)
    }
    
    // MARK: - Notifications
    
    private func checkNotificationPermission() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .notDetermined:
                    continuation.resume(returning: .notDetermined)
                case .denied:
                    continuation.resume(returning: .denied)
                case .authorized, .provisional, .ephemeral:
                    continuation.resume(returning: .authorized)
                @unknown default:
                    continuation.resume(returning: .notDetermined)
                }
            }
        }
    }
    
    private func requestNotificationPermission() async throws {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        
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
    
    public var errorDescription: String? {
        switch self {
        case .denied(let permission):
            return "\(permission.displayName) 权限被拒绝"
        case .restricted(let permission):
            return "\(permission.displayName) 权限受限"
        case .requiresManualGrant(let permission):
            return "请在系统设置中手动授予 \(permission.displayName) 权限"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .denied:
            return "请前往系统设置 > 隐私与安全性 > \(self.permissionName) 中开启权限"
        case .restricted:
            return "请联系系统管理员"
        case .requiresManualGrant:
            return "请点击下方按钮打开系统设置"
        }
    }
    
    private var permissionName: String {
        switch self {
        case .denied(let p), .restricted(let p), .requiresManualGrant(let p):
            return p.displayName
        }
    }
}
