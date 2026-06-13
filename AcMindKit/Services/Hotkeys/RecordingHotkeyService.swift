import Foundation
import AppKit
import Carbon

// MARK: - Recording Hotkey Service

/// 录音中快捷键服务
/// 职责：
/// 1. 在录音状态下拦截特定按键
/// 2. 支持 ESC 取消录音
/// 3. 支持 Space/Backspace 立即注入跳过润色
/// 4. 支持标点符号追加到转写文本
public actor RecordingHotkeyService {
    
    // MARK: - Singleton
    
    public static let shared = RecordingHotkeyService()
    
    // MARK: - Properties
    
    private var isRecording = false
    private var eventHandler: EventHandlerRef?
    private var handlers: [RecordingHotkeyAction: () -> Void] = [:]
    private var onPunctuationAppended: (@Sendable (Character) -> Void)?
    private var lastErrorMessage: String?
    private var statusUpdatedAt = Date()
    private let eventHandlerInstaller: (@Sendable () throws -> Void)?
    
    // MARK: - Initialization
    
    public init() {
        eventHandlerInstaller = nil
    }

    init(eventHandlerInstaller: @escaping @Sendable () throws -> Void) {
        self.eventHandlerInstaller = eventHandlerInstaller
    }
    
    // MARK: - Public Methods
    
    /// 开始监听录音中的快捷键
    public func startListening() async throws {
        guard !isRecording else { return }
        isRecording = true

        do {
            if let eventHandlerInstaller {
                try eventHandlerInstaller()
            } else {
                try installEventHandler()
            }
            lastErrorMessage = nil
            statusUpdatedAt = Date()
        } catch {
            isRecording = false
            eventHandler = nil
            lastErrorMessage = error.localizedDescription
            statusUpdatedAt = Date()
            throw error
        }
    }
    
    /// 停止监听录音中的快捷键
    public func stopListening() {
        guard isRecording else { return }
        isRecording = false
        
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        
        handlers.removeAll()
        onPunctuationAppended = nil
        lastErrorMessage = nil
        statusUpdatedAt = Date()
    }
    
    /// 注册快捷键动作
    public func registerHandler(for action: RecordingHotkeyAction, handler: @escaping () -> Void) {
        handlers[action] = handler
        statusUpdatedAt = Date()
    }
    
    /// 注销快捷键动作
    public func unregisterHandler(for action: RecordingHotkeyAction) {
        handlers.removeValue(forKey: action)
        statusUpdatedAt = Date()
    }

    public func setPunctuationHandler(_ handler: (@Sendable (Character) -> Void)?) {
        onPunctuationAppended = handler
        statusUpdatedAt = Date()
    }
    
    /// 检查是否正在录音
    public func isCurrentlyRecording() -> Bool {
        return isRecording
    }

    public func statusSnapshot() -> InputChainStatusSnapshot {
        let activeControlCount = handlers.count + (onPunctuationAppended == nil ? 0 : 1)

        if let lastErrorMessage {
            return InputChainStatusSnapshot(
                source: .recordingHotkey,
                phase: .failed,
                stepLabel: "快捷键监听",
                detail: "录音快捷键监听启动失败",
                activeControlCount: activeControlCount,
                nextActionTitle: "重试监听",
                lastErrorMessage: lastErrorMessage,
                updatedAt: statusUpdatedAt
            )
        }

        if isRecording {
            return InputChainStatusSnapshot(
                source: .recordingHotkey,
                phase: .listening,
                stepLabel: "录音中",
                detail: "录音快捷键已启用",
                activeControlCount: activeControlCount,
                nextActionTitle: "停止录音",
                updatedAt: statusUpdatedAt
            )
        }

        return InputChainStatusSnapshot(
            source: .recordingHotkey,
            phase: .idle,
            stepLabel: "等待录音",
            detail: "录音开始后启用快捷键",
            activeControlCount: activeControlCount,
            nextActionTitle: "开始录音",
            updatedAt: statusUpdatedAt
        )
    }
    
    // MARK: - Event Handling
    
    private func installEventHandler() throws {
        // 监听键盘事件
        let eventSpecs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventRawKeyDown)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventRawKeyRepeat))
        ]
        
        let callback: EventHandlerUPP = { _, eventRef, userData -> OSStatus in
            guard let eventRef = eventRef else { return OSStatus(eventNotHandledErr) }
            
            // 获取按键信息
            var keyCode: UInt16 = 0
            let keyCodeResult = GetEventParameter(
                eventRef,
                EventParamName(kEventParamKeyCode),
                EventParamType(typeUInt16),
                nil,
                MemoryLayout<UInt16>.size,
                nil,
                &keyCode
            )
            
            guard keyCodeResult == noErr else { return OSStatus(eventNotHandledErr) }
            
            // 获取修饰键状态
            var modifiers: UInt32 = 0
            let modifiersResult = GetEventParameter(
                eventRef,
                EventParamName(kEventParamKeyModifiers),
                EventParamType(typeUInt32),
                nil,
                MemoryLayout<UInt32>.size,
                nil,
                &modifiers
            )
            
            guard modifiersResult == noErr else { return OSStatus(eventNotHandledErr) }
            
            // 处理按键
            Task { @MainActor in
                if let service = userData?.assumingMemoryBound(to: RecordingHotkeyService.self).pointee {
                    await service.handleKeyPress(keyCode: keyCode, modifiers: modifiers)
                }
            }
            
            return noErr
        }
        
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        var handler: EventHandlerRef?
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            2,
            eventSpecs,
            userData,
            &handler
        )
        
        guard status == noErr else {
            throw RecordingHotkeyError.handlerInstallationFailed(status)
        }
        
        self.eventHandler = handler
    }
    
    private func handleKeyPress(keyCode: UInt16, modifiers: UInt32) {
        // 只在录音状态下处理
        guard isRecording else { return }
        
        // 检查是否是 ESC 键 (keyCode 53)
        if keyCode == 53 {
            handlers[.cancel]?()
            return
        }
        
        // 检查是否是空格键 (keyCode 49)
        if keyCode == 49 && modifiers == 0 {
            handlers[.immediateInject]?()
            return
        }
        
        // 检查是否是退格键 (keyCode 51)
        if keyCode == 51 && modifiers == 0 {
            handlers[.immediateInject]?()
            return
        }
        
        // 检查是否是标点符号
        if let character = characterFromKeyCode(keyCode, modifiers: modifiers),
           isPunctuation(character) {
            onPunctuationAppended?(character)
        }
    }
    
    private func characterFromKeyCode(_ keyCode: UInt16, modifiers: UInt32) -> Character? {
        // 简化的键码到字符映射
        let keyMap: [UInt16: Character] = [
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
            26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "o", 32: "u", 33: "[",
            34: "i", 35: "p", 37: "l", 38: "j", 39: "'", 40: "k", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "n", 46: "m", 47: ".", 49: " ", 50: "`"
        ]
        
        guard let baseChar = keyMap[keyCode] else { return nil }
        
        // 检查是否需要大写（Shift 键）
        let hasShift = modifiers & UInt32(shiftKey) != 0
        
        if hasShift {
            // 简化的大写映射
            let shiftMap: [Character: Character] = [
                "1": "!", "2": "@", "3": "#", "4": "$", "6": "^", "5": "%",
                "7": "&", "8": "*", "9": "(", "0": ")", "-": "_", "=": "+",
                "[": "{", "]": "}", "\\": "|", ";": ":", "'": "\"", ",": "<",
                ".": ">", "/": "?", "`": "~"
            ]
            
            return shiftMap[baseChar] ?? baseChar.uppercased().first
        }
        
        return baseChar
    }
    
    private func isPunctuation(_ character: Character) -> Bool {
        let punctuationSet: Set<Character> = [
            ".", ",", "!", "?", ";", ":", "'", "\"",
            "-", "(", ")", "[", "]", "{", "}", "/",
            "\\", "|", "@", "#", "$", "%", "^", "&",
            "*", "_", "+", "=", "<", ">", "~", "`"
        ]
        return punctuationSet.contains(character)
    }
}

// MARK: - Recording Hotkey Action

/// 录音中快捷键动作
public enum RecordingHotkeyAction: Hashable {
    case cancel                    // ESC 取消录音
    case immediateInject          // Space/Backspace 立即注入
    case appendPunctuation(Character) // 标点符号追加
}

// MARK: - Recording Hotkey Error

public enum RecordingHotkeyError: Error, LocalizedError {
    case handlerInstallationFailed(OSStatus)
    case alreadyListening
    case notListening
    
    public var errorDescription: String? {
        switch self {
        case .handlerInstallationFailed(let status):
            return "事件处理器安装失败 (状态码: \(status))"
        case .alreadyListening:
            return "已经在监听中"
        case .notListening:
            return "未在监听状态"
        }
    }
}
