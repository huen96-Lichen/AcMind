import Foundation
import AppKit

// MARK: - App Aware Settings Service

/// 应用感知设置服务
/// 职责：
/// 1. 根据当前应用自动切换润色模式
/// 2. 管理应用特定的设置规则
/// 3. 支持自定义应用规则
public actor AppAwareSettingsService {
    
    // MARK: - Singleton
    
    public static let shared = AppAwareSettingsService()
    
    // MARK: - Properties
    
    private let contextCaptureService: ContextCaptureService
    private var appRules: [String: AppRule] = [:]
    private var isLoaded = false
    
    // MARK: - Initialization
    
    public init(contextCaptureService: ContextCaptureService? = nil) {
        self.contextCaptureService = contextCaptureService ?? ContextCaptureService.shared
    }
    
    // MARK: - Public Methods
    
    /// 加载应用规则
    public func loadAppRules() async throws {
        guard !isLoaded else { return }
        
        // 添加默认规则
        appRules = [
            // 邮件应用
            "com.apple.mail": AppRule(
                bundleIdentifier: "com.apple.mail",
                appName: "邮件",
                polishMode: .formal,
                autoPolish: true,
                triggerMode: .tap,
                silenceDetection: true,
                silenceTimeout: 5.0
            ),
            "com.microsoft.Outlook": AppRule(
                bundleIdentifier: "com.microsoft.Outlook",
                appName: "Outlook",
                polishMode: .formal,
                autoPolish: true,
                triggerMode: .tap,
                silenceDetection: true,
                silenceTimeout: 5.0
            ),
            
            // 即时通讯
            "com.apple.MobileSMS": AppRule(
                bundleIdentifier: "com.apple.MobileSMS",
                appName: "信息",
                polishMode: .light,
                autoPolish: true,
                triggerMode: .tap,
                silenceDetection: true,
                silenceTimeout: 3.0
            ),
            "com.tencent.xinWeChat": AppRule(
                bundleIdentifier: "com.tencent.xinWeChat",
                appName: "微信",
                polishMode: .light,
                autoPolish: true,
                triggerMode: .tap,
                silenceDetection: true,
                silenceTimeout: 3.0
            ),
            "com.tdesktop.Telegram": AppRule(
                bundleIdentifier: "com.tdesktop.Telegram",
                appName: "Telegram",
                polishMode: .light,
                autoPolish: true,
                triggerMode: .tap,
                silenceDetection: true,
                silenceTimeout: 3.0
            ),
            
            // 代码编辑器
            "com.apple.dt.Xcode": AppRule(
                bundleIdentifier: "com.apple.dt.Xcode",
                appName: "Xcode",
                polishMode: .raw,
                autoPolish: false,
                triggerMode: .tap,
                silenceDetection: true,
                silenceTimeout: 2.0
            ),
            "com.microsoft.VSCode": AppRule(
                bundleIdentifier: "com.microsoft.VSCode",
                appName: "VS Code",
                polishMode: .raw,
                autoPolish: false,
                triggerMode: .tap,
                silenceDetection: true,
                silenceTimeout: 2.0
            ),
            "com.jetbrains.intellij": AppRule(
                bundleIdentifier: "com.jetbrains.intellij",
                appName: "IntelliJ IDEA",
                polishMode: .raw,
                autoPolish: false,
                triggerMode: .tap,
                silenceDetection: true,
                silenceTimeout: 2.0
            ),
            
            // 文档编辑器
            "com.apple.iWork.Pages": AppRule(
                bundleIdentifier: "com.apple.iWork.Pages",
                appName: "Pages",
                polishMode: .structured,
                autoPolish: true,
                triggerMode: .tap,
                silenceDetection: true,
                silenceTimeout: 4.0
            ),
            "com.microsoft.Word": AppRule(
                bundleIdentifier: "com.microsoft.Word",
                appName: "Word",
                polishMode: .structured,
                autoPolish: true,
                triggerMode: .tap,
                silenceDetection: true,
                silenceTimeout: 4.0
            ),
            "notion.id": AppRule(
                bundleIdentifier: "notion.id",
                appName: "Notion",
                polishMode: .structured,
                autoPolish: true,
                triggerMode: .tap,
                silenceDetection: true,
                silenceTimeout: 4.0
            ),
            
            // 浏览器
            "com.apple.Safari": AppRule(
                bundleIdentifier: "com.apple.Safari",
                appName: "Safari",
                polishMode: .light,
                autoPolish: true,
                triggerMode: .tap,
                silenceDetection: true,
                silenceTimeout: 3.0
            ),
            "com.google.Chrome": AppRule(
                bundleIdentifier: "com.google.Chrome",
                appName: "Chrome",
                polishMode: .light,
                autoPolish: true,
                triggerMode: .tap,
                silenceDetection: true,
                silenceTimeout: 3.0
            ),
        ]
        
        isLoaded = true
    }
    
    /// 获取当前应用的设置
    public func getCurrentAppSettings() async -> AppRule? {
        let appInfo = await contextCaptureService.getFrontmostAppInfo()
        return appRules[appInfo.bundleIdentifier]
    }
    
    /// 获取当前应用的润色模式
    public func getCurrentPolishMode() async -> VoicePolishMode {
        if let rule = await getCurrentAppSettings() {
            return rule.polishMode
        }
        
        // 根据应用类型返回默认模式
        let appType = await contextCaptureService.getCurrentAppType()
        return appType.recommendedPolishMode
    }
    
    /// 获取当前应用的触发模式
    public func getCurrentTriggerMode() async -> SayInputTriggerMode {
        if let rule = await getCurrentAppSettings() {
            return rule.triggerMode
        }
        
        return .tap
    }
    
    /// 获取当前应用的静音检测设置
    public func getCurrentSilenceSettings() async -> (enabled: Bool, timeout: TimeInterval) {
        if let rule = await getCurrentAppSettings() {
            return (rule.silenceDetection, rule.silenceTimeout)
        }
        
        return (true, 3.0)
    }
    
    /// 添加应用规则
    public func addAppRule(_ rule: AppRule) {
        appRules[rule.bundleIdentifier] = rule
    }
    
    /// 删除应用规则
    public func removeAppRule(bundleIdentifier: String) {
        appRules.removeValue(forKey: bundleIdentifier)
    }
    
    /// 获取所有应用规则
    public func getAllAppRules() -> [AppRule] {
        return Array(appRules.values)
    }
    
    /// 获取指定应用规则
    public func getAppRule(bundleIdentifier: String) -> AppRule? {
        return appRules[bundleIdentifier]
    }
    
    /// 检查是否有应用规则
    public func hasAppRule(bundleIdentifier: String) -> Bool {
        return appRules[bundleIdentifier] != nil
    }
    
    /// 重置为默认规则
    public func resetToDefault() async throws {
        appRules.removeAll()
        try await loadAppRules()
    }
}

// MARK: - App Rule

/// 应用规则
public struct AppRule: Codable, Sendable, Identifiable {
    public let id: UUID
    public let bundleIdentifier: String
    public let appName: String
    public var polishMode: VoicePolishMode
    public var autoPolish: Bool
    public var triggerMode: SayInputTriggerMode
    public var silenceDetection: Bool
    public var silenceTimeout: TimeInterval
    
    public init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        appName: String,
        polishMode: VoicePolishMode = .light,
        autoPolish: Bool = true,
        triggerMode: SayInputTriggerMode = .tap,
        silenceDetection: Bool = true,
        silenceTimeout: TimeInterval = 3.0
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.polishMode = polishMode
        self.autoPolish = autoPolish
        self.triggerMode = triggerMode
        self.silenceDetection = silenceDetection
        self.silenceTimeout = silenceTimeout
    }
}