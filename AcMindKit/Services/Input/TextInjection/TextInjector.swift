import Foundation

// MARK: - Text Selection Snapshot

/// 文本选区快照
public struct TextSelectionSnapshot: Sendable {
    public var processID: pid_t?
    public var processName: String?
    public var bundleIdentifier: String?
    public var selectedRange: CFRange?
    public var selectedText: String?
    public var source: String = "none"
    public var isEditable: Bool = false
    public var role: String?
    public var windowTitle: String?
    public var isFocusedTarget: Bool = false
    
    public init() {}
    
    public var hasSelection: Bool {
        let trimmed = selectedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !trimmed.isEmpty
    }
    
    public var hasAskSelectionContext: Bool {
        isFocusedTarget && hasSelection
    }
    
    public var canReplaceSelection: Bool {
        hasAskSelectionContext && (isEditable || source == "clipboard-copy")
    }
    
    public var canSafelyRestoreSelection: Bool {
        canReplaceSelection && source == "accessibility"
    }
}

// MARK: - Current Input Text Snapshot

/// 当前输入文本快照
public struct CurrentInputTextSnapshot: Sendable {
    public var processID: pid_t?
    public var processName: String?
    public var bundleIdentifier: String?
    public var role: String?
    public var text: String?
    public var selectedRange: CFRange?
    public var isEditable: Bool = false
    public var isFocusedTarget: Bool = false
    public var failureReason: String?
    public var documentURL: URL?
    public var textSource: String?
    
    public init() {}
}

// MARK: - Text Injector Protocol

/// 文本插入器协议
public protocol TextInjector: Sendable {
    /// 获取当前选区快照
    func getSelectionSnapshot() async -> TextSelectionSnapshot
    
    /// 获取当前输入文本快照
    func currentInputTextSnapshot() async -> CurrentInputTextSnapshot
    
    /// 获取当前输入文本
    func currentInputText() async -> String?
    
    /// 插入文本到光标位置
    /// - Parameter text: 要插入的文本
    func insert(text: String) async throws
    
    /// 替换当前选区
    /// - Parameter text: 替换文本
    func replaceSelection(text: String) async throws
}
