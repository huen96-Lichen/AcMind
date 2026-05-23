import Foundation
import AppKit
import ApplicationServices
import Carbon

// MARK: - AX Text Injector

/// 基于 Accessibility API 的文本插入器
public final class AXTextInjector: TextInjector, @unchecked Sendable {
    
    // MARK: - Properties
    
    private let pasteboard: NSPasteboard = .general
    
    // MARK: - Initialization
    
    public init() {}

    private func focusedElement(from axApp: AXUIElement) -> AXUIElement? {
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }
        guard let focusedElement,
              CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeDowncast(focusedElement as AnyObject, to: AXUIElement.self)
    }
    
    // MARK: - TextInjector Protocol
    
    public func getSelectionSnapshot() async -> TextSelectionSnapshot {
        var snapshot = TextSelectionSnapshot()
        
        // 获取系统前台应用
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return snapshot
        }
        
        snapshot.processID = app.processIdentifier
        snapshot.processName = app.localizedName
        snapshot.bundleIdentifier = app.bundleIdentifier
        
        // 获取焦点元素
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let element = focusedElement(from: axApp) else {
            return snapshot
        }
        
        // 获取角色
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           let roleString = role as? String {
            snapshot.role = roleString
            snapshot.isEditable = roleString == kAXTextFieldRole as String ||
                                  roleString == kAXTextAreaRole as String ||
                                  roleString == "AXWebArea"
        }
        
        // 获取选区
        var selection: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selection) == .success,
           let selectedText = selection as? String {
            snapshot.selectedText = selectedText
            snapshot.source = "accessibility"
        }
        
        // 获取选区范围
        var range: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success,
           let range,
           CFGetTypeID(range) == AXValueGetTypeID() {
            let rangeValue = unsafeDowncast(range as AnyObject, to: AXValue.self)
            var cfRange = CFRange()
            if AXValueGetValue(rangeValue, .cfRange, &cfRange) {
                snapshot.selectedRange = cfRange
            }
        }
        
        snapshot.isFocusedTarget = snapshot.isEditable
        
        return snapshot
    }
    
    public func currentInputTextSnapshot() async -> CurrentInputTextSnapshot {
        var snapshot = CurrentInputTextSnapshot()
        
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return snapshot
        }
        
        snapshot.processID = app.processIdentifier
        snapshot.processName = app.localizedName
        snapshot.bundleIdentifier = app.bundleIdentifier
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let element = focusedElement(from: axApp) else {
            snapshot.failureReason = "无法获取焦点元素"
            return snapshot
        }
        
        // 获取角色
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           let roleString = role as? String {
            snapshot.role = roleString
            snapshot.isEditable = roleString == kAXTextFieldRole as String ||
                                  roleString == kAXTextAreaRole as String
        }
        
        // 获取文本
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
           let text = value as? String {
            snapshot.text = text
            snapshot.textSource = "accessibility"
        }
        
        snapshot.isFocusedTarget = snapshot.isEditable
        
        return snapshot
    }
    
    public func currentInputText() async -> String? {
        let snapshot = await currentInputTextSnapshot()
        return snapshot.text
    }
    
    public func insert(text: String) throws {
        // 检查 Accessibility 权限
        guard AXIsProcessTrusted() else {
            throw TextInjectionError.permissionDenied
        }
        
        // 方法1: 尝试通过 Accessibility API 直接插入
        if let app = NSWorkspace.shared.frontmostApplication {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            if let element = focusedElement(from: axApp) {
                
                // 尝试设置值
                let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
                if result == .success {
                    return
                }
            }
        }
        
        // 方法2: 使用剪贴板粘贴
        try insertViaPasteboard(text: text)
    }
    
    public func replaceSelection(text: String) throws {
        guard AXIsProcessTrusted() else {
            throw TextInjectionError.permissionDenied
        }
        
        guard let app = NSWorkspace.shared.frontmostApplication else {
            throw TextInjectionError.noFocusedApplication
        }
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let element = focusedElement(from: axApp) else {
            // Fallback to pasteboard
            try insertViaPasteboard(text: text)
            return
        }
        
        // 获取选区范围
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue,
              CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
            try insertViaPasteboard(text: text)
            return
        }
        let range = unsafeDowncast(rangeValue as AnyObject, to: AXValue.self)
        
        var cfRange = CFRange()
        guard AXValueGetValue(range, .cfRange, &cfRange) else {
            try insertViaPasteboard(text: text)
            return
        }
        
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
        if result != .success {
            try insertViaPasteboard(text: text)
        }
    }
    
    // MARK: - Private Methods
    
    private func insertViaPasteboard(text: String) throws {
        // 保存当前剪贴板内容
        let oldContents = pasteboard.string(forType: .string)
        
        // 设置新内容
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 模拟 Cmd+V
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Cmd down
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(55), keyDown: true)
        cmdDown?.flags = .maskCommand
        cmdDown?.post(tap: .cghidEventTap)
        
        // V down
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(9), keyDown: true)
        vDown?.flags = .maskCommand
        vDown?.post(tap: .cghidEventTap)
        
        // V up
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(9), keyDown: false)
        vUp?.flags = .maskCommand
        vUp?.post(tap: .cghidEventTap)
        
        // Cmd up
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(55), keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdUp?.post(tap: .cghidEventTap)
        
        // 延迟后恢复剪贴板（可选）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [oldContents] in
            if let old = oldContents {
                self.pasteboard.clearContents()
                self.pasteboard.setString(old, forType: .string)
            }
        }
    }
}

// MARK: - Text Injection Error

public enum TextInjectionError: Error, LocalizedError {
    case permissionDenied
    case noFocusedApplication
    case insertionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "需要辅助功能权限"
        case .noFocusedApplication:
            return "没有焦点应用"
        case .insertionFailed(let message):
            return "插入失败: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "请前往系统设置 > 隐私与安全性 > 辅助功能，授予 AcMind 权限"
        default:
            return nil
        }
    }
}
