import Foundation
import AppKit
import ApplicationServices

// MARK: - Context Capture Service

/// 屏幕内容读取服务
/// 职责：
/// 1. 获取当前前台应用信息
/// 2. 获取当前窗口标题
/// 3. 获取选中文本
/// 4. 获取光标周围文本
/// 5. 提供上下文信息给润色服务
public actor ContextCaptureService {
    
    // MARK: - Singleton
    
    public static let shared = ContextCaptureService()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// 获取完整的上下文快照
    public func captureContext() async -> ContextSnapshot {
        let appInfo = getFrontmostAppInfo()
        let windowTitle = getWindowTitle(for: appInfo.processID)
        let selectedText = getSelectedText(for: appInfo.processID)
        let surroundingText = getSurroundingText(for: appInfo.processID)
        let bundleIdentifier = appInfo.bundleIdentifier
        
        return ContextSnapshot(
            appName: appInfo.name,
            bundleIdentifier: bundleIdentifier,
            windowTitle: windowTitle,
            selectedText: selectedText,
            surroundingText: surroundingText,
            timestamp: Date()
        )
    }
    
    public nonisolated func captureContextNonBlocking() -> Task<ContextSnapshot, Never> {
        Task { await captureContext() }
    }
    
    /// 获取当前前台应用信息
    public func getFrontmostAppInfo() -> (name: String, bundleIdentifier: String, processID: pid_t) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return ("", "", 0)
        }
        
        return (
            name: app.localizedName ?? "",
            bundleIdentifier: app.bundleIdentifier ?? "",
            processID: app.processIdentifier
        )
    }
    
    /// 获取窗口标题
    public func getWindowTitle(for processID: pid_t) -> String? {
        let app = AXUIElementCreateApplication(processID)
        var window: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let windowElement = window else {
            return nil
        }
        
        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowElement as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success,
              let titleString = title as? String else {
            return nil
        }
        
        return titleString
    }
    
    /// 获取选中文本
    public func getSelectedText(for processID: pid_t) -> String? {
        let app = AXUIElementCreateApplication(processID)
        var focusedElement: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement else {
            return nil
        }
        
        guard CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return nil
        }
        
        var selectedText: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText) == .success,
              let text = selectedText as? String else {
            return nil
        }
        
        return text.isEmpty ? nil : text
    }
    
    /// 获取光标周围的文本（前50字 + 后50字）
    public func getSurroundingText(for processID: pid_t) -> String? {
        let app = AXUIElementCreateApplication(processID)
        var focusedElement: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement else {
            return nil
        }
        
        guard CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return nil
        }
        
        let focusedUIElement = element as! AXUIElement
        
        // 获取当前值
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedUIElement, kAXValueAttribute as CFString, &value) == .success,
              let text = value as? String else {
            return nil
        }
        
        // 获取选区范围
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedUIElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let range = rangeValue else {
            return nil
        }
        
        guard CFGetTypeID(range) == AXValueGetTypeID() else {
            return nil
        }
        
        var rangeValueStruct = CFRange()
        guard AXValueGetValue(range as! AXValue, .cfRange, &rangeValueStruct) else {
            return nil
        }

        return Self.surroundingText(from: text, selectedRange: rangeValueStruct)
    }

    nonisolated static func surroundingText(from text: String, selectedRange: CFRange) -> String? {
        guard text.isEmpty == false else { return nil }

        let nsString = text as NSString
        let maxLength = nsString.length
        guard maxLength > 0 else { return nil }

        let safeLocation = max(0, min(selectedRange.location, maxLength))
        let safeLength = max(0, selectedRange.length)
        let cursorStart = min(safeLocation, maxLength)
        let cursorEnd = min(maxLength, cursorStart + safeLength)

        let start = max(0, cursorStart - 50)
        let beforeLength = cursorStart - start
        let beforeText = beforeLength > 0
            ? nsString.substring(with: NSRange(location: start, length: beforeLength))
            : ""

        let afterStart = cursorEnd
        let afterEnd = min(maxLength, cursorEnd + 50)
        let afterLength = max(0, afterEnd - afterStart)
        let afterText = afterLength > 0
            ? nsString.substring(with: NSRange(location: afterStart, length: afterLength))
            : ""

        return beforeText + "[光标]" + afterText
    }
    
    /// 获取当前应用类型（用于润色模式选择）
    public func getCurrentAppType() -> AppType {
        let appInfo = getFrontmostAppInfo()
        
        // 邮件应用
        if appInfo.bundleIdentifier.contains("mail") || 
           appInfo.bundleIdentifier.contains("outlook") ||
           appInfo.bundleIdentifier.contains("thunderbird") {
            return .email
        }
        
        // 即时通讯
        if appInfo.bundleIdentifier.contains("messages") ||
           appInfo.bundleIdentifier.contains("wechat") ||
           appInfo.bundleIdentifier.contains("slack") ||
           appInfo.bundleIdentifier.contains("telegram") ||
           appInfo.bundleIdentifier.contains("whatsapp") {
            return .messaging
        }
        
        // 代码编辑器
        if appInfo.bundleIdentifier.contains("xcode") ||
           appInfo.bundleIdentifier.contains("code") ||
           appInfo.bundleIdentifier.contains("sublime") ||
           appInfo.bundleIdentifier.contains("atom") ||
           appInfo.bundleIdentifier.contains("vim") {
            return .codeEditor
        }
        
        // 文档编辑器
        if appInfo.bundleIdentifier.contains("pages") ||
           appInfo.bundleIdentifier.contains("word") ||
           appInfo.bundleIdentifier.contains("docs") ||
           appInfo.bundleIdentifier.contains("notion") ||
           appInfo.bundleIdentifier.contains("obsidian") {
            return .documentEditor
        }
        
        // 浏览器
        if appInfo.bundleIdentifier.contains("safari") ||
           appInfo.bundleIdentifier.contains("chrome") ||
           appInfo.bundleIdentifier.contains("firefox") ||
           appInfo.bundleIdentifier.contains("edge") {
            return .browser
        }
        
        return .other
    }
}

// MARK: - Context Snapshot

/// 上下文快照
public struct ContextSnapshot: Sendable {
    public let appName: String
    public let bundleIdentifier: String
    public let windowTitle: String?
    public let selectedText: String?
    public let surroundingText: String?
    public let timestamp: Date
    
    public init(
        appName: String,
        bundleIdentifier: String,
        windowTitle: String?,
        selectedText: String?,
        surroundingText: String?,
        timestamp: Date
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
        self.selectedText = selectedText
        self.surroundingText = surroundingText
        self.timestamp = timestamp
    }
    
    /// 是否有足够的上下文信息
    public var hasContext: Bool {
        return selectedText != nil || surroundingText != nil || windowTitle != nil
    }
    
    /// 格式化上下文信息，用于注入到 Prompt
    public func formattedContext() -> String {
        var parts: [String] = []
        
        if let windowTitle = windowTitle, !windowTitle.isEmpty {
            parts.append("当前窗口: \(windowTitle)")
        }
        
        if let selectedText = selectedText, !selectedText.isEmpty {
            parts.append("选中文本: \(selectedText)")
        }
        
        if let surroundingText = surroundingText, !surroundingText.isEmpty {
            parts.append("上下文: \(surroundingText)")
        }
        
        return parts.joined(separator: "\n")
    }
}

// MARK: - App Type

/// 应用类型
public enum AppType: String, Sendable, CaseIterable {
    case email = "email"
    case messaging = "messaging"
    case codeEditor = "codeEditor"
    case documentEditor = "documentEditor"
    case browser = "browser"
    case other = "other"
    
    public var displayName: String {
        switch self {
        case .email: return "邮件"
        case .messaging: return "即时通讯"
        case .codeEditor: return "代码编辑器"
        case .documentEditor: return "文档编辑器"
        case .browser: return "浏览器"
        case .other: return "其他"
        }
    }
    
    /// 推荐的润色模式
    public var recommendedPolishMode: VoicePolishMode {
        switch self {
        case .email: return .formal
        case .messaging: return .light
        case .codeEditor: return .raw
        case .documentEditor: return .structured
        case .browser: return .light
        case .other: return .light
        }
    }
}

// MARK: - Polish Service Extension

public extension PolishService {
    /// 使用上下文信息进行润色
    func polishWithContext(text: String, mode: VoicePolishMode, context: ContextSnapshot) async throws -> String {
        // 构建带上下文的 Prompt
        let contextPrompt = context.formattedContext()
        
        // 根据应用类型选择润色策略
        let appType = await ContextCaptureService.shared.getCurrentAppType()
        let effectiveMode = mode == .light ? appType.recommendedPolishMode : mode
        
        // 构建完整的 Prompt
        let fullPrompt: String
        if contextPrompt.isEmpty {
            fullPrompt = text
        } else {
            fullPrompt = """
            上下文信息：
            \(contextPrompt)
            
            需要润色的文本：
            \(text)
            """
        }
        
        return try await polish(text: fullPrompt, mode: effectiveMode)
    }
}
