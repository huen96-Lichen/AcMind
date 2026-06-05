import Foundation
import AppKit
import Carbon

// MARK: - Hotkey Manager

/// 全局快捷键管理
/// 支持：注册、注销、冲突检测、持久化
public actor HotkeyManager {
    
    // MARK: - Properties
    
    private var registeredHotkeys: [KeyboardShortcut: HotkeyRegistration] = [:]
    private var persistedHotkeys: [KeyboardShortcut] = []
    private var eventHandler: EventHandlerRef?
    
    public init() {}
    
    // MARK: - Setup
    
    public func setup() async throws {
        // 从存储加载已保存的快捷键
        await loadSavedHotkeys()
    }
    
    // MARK: - Register/Unregister
    
    public func registerShortcut(_ shortcut: KeyboardShortcut, action: @escaping @Sendable () -> Void) async throws {
        // 检查冲突
        if registeredHotkeys[shortcut] != nil {
            throw HotkeyError.alreadyRegistered(shortcut)
        }
        
        // 检查是否有其他快捷键使用了相同的组合
        for (existingShortcut, _) in registeredHotkeys {
            if existingShortcut.key == shortcut.key && 
               Set(existingShortcut.modifiers) == Set(shortcut.modifiers) {
                throw HotkeyError.conflict(existingShortcut)
            }
        }
        
        // 注册 Carbon 快捷键
        let hotKeyID = EventHotKeyID(signature: FourCharCode(bitPattern: 0x41634D64), // "AcMd"
                                      id: UInt32(registeredHotkeys.count + 1))
        
        var hotKeyRef: EventHotKeyRef?
        
        let modifierFlags = carbonModifiers(from: shortcut.modifiers)
        let keyCode = carbonKeyCode(from: shortcut.key)
        
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            modifierFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        
        guard status == noErr, let ref = hotKeyRef else {
            throw HotkeyError.registrationFailed(status)
        }
        
        // 保存注册信息
        let registration = HotkeyRegistration(
            shortcut: shortcut,
            hotKeyRef: ref,
            hotKeyID: hotKeyID,
            action: action
        )
        
        registeredHotkeys[shortcut] = registration
        
        // 安装事件处理器（如果还没有安装）
        if eventHandler == nil {
            try installEventHandler()
        }
        
        // 持久化到存储
        await saveHotkey(shortcut)
    }
    
    public func unregisterShortcut(_ shortcut: KeyboardShortcut) async throws {
        guard let registration = registeredHotkeys[shortcut] else {
            throw HotkeyError.notFound(shortcut)
        }
        
        // 注销 Carbon 快捷键
        UnregisterEventHotKey(registration.hotKeyRef)
        
        // 从注册表移除
        registeredHotkeys.removeValue(forKey: shortcut)
        
        // 从存储移除
        await removeHotkey(shortcut)
    }
    
    public func unregisterAll() async {
        for (_, registration) in registeredHotkeys {
            UnregisterEventHotKey(registration.hotKeyRef)
        }
        registeredHotkeys.removeAll()
        
        // 清理事件处理器
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
    
    public func getRegisteredShortcuts() async -> [KeyboardShortcut] {
        Array(registeredHotkeys.keys)
    }
    
    // MARK: - Event Handling
    
    private func installEventHandler() throws {
        let eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let callback: EventHandlerUPP = { _, eventRef, userData -> OSStatus in
            guard let eventRef = eventRef else { return OSStatus(eventNotHandledErr) }
            
            var hotKeyID = EventHotKeyID()
            let result = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            guard result == noErr else { return OSStatus(eventNotHandledErr) }
            
            // 查找并执行对应的动作
            Task { @MainActor in
                if let manager = userData?.assumingMemoryBound(to: HotkeyManager.self).pointee {
                    await manager.handleHotkeyPress(id: hotKeyID)
                }
            }
            
            return noErr
        }
        
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        var handler: EventHandlerRef?
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            [eventSpec],
            userData,
            &handler
        )
        
        guard status == noErr else {
            throw HotkeyError.handlerInstallationFailed(status)
        }
        
        self.eventHandler = handler
    }
    
    private func handleHotkeyPress(id: EventHotKeyID) async {
        for (_, registration) in registeredHotkeys {
            if registration.hotKeyID.id == id.id {
                await MainActor.run {
                    registration.action()
                }
                break
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadSavedHotkeys() async {
        persistedHotkeys = HotkeyRegistryStore.load()
    }
    
    private func saveHotkey(_ shortcut: KeyboardShortcut) async {
        if persistedHotkeys.contains(shortcut) == false {
            persistedHotkeys.append(shortcut)
        }
        HotkeyRegistryStore.save(persistedHotkeys)
    }
    
    private func removeHotkey(_ shortcut: KeyboardShortcut) async {
        persistedHotkeys.removeAll { $0 == shortcut }
        HotkeyRegistryStore.save(persistedHotkeys)
    }
    
    // MARK: - Carbon Helpers
    
    private func carbonModifiers(from modifiers: [ModifierKey]) -> UInt32 {
        var flags: UInt32 = 0
        for modifier in modifiers {
            switch modifier {
            case .command:
                flags |= UInt32(cmdKey)
            case .option:
                flags |= UInt32(optionKey)
            case .control:
                flags |= UInt32(controlKey)
            case .shift:
                flags |= UInt32(shiftKey)
            }
        }
        return flags
    }
    
    private func carbonKeyCode(from key: String) -> UInt16 {
        let keyMap: [String: UInt16] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "return": 36,
            "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43,
            "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, " ": 49, "`": 50,
            "delete": 51, "enter": 52, "escape": 53, "space": 49,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
            "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
            "up": 126, "down": 125, "left": 123, "right": 124,
            "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
            "forwarddelete": 117, "help": 114, "clear": 71, "capslock": 57
        ]

        return keyMap[key.lowercased()] ?? 0
    }

    // MARK: - Hotkey Groups

    private var hotkeyGroups: [String: HotkeyGroup] = [:]

    public func createGroup(name: String) async {
        guard hotkeyGroups[name] == nil else { return }
        hotkeyGroups[name] = HotkeyGroup(name: name, isEnabled: true, shortcuts: [])
    }

    public func deleteGroup(name: String) async {
        guard let group = hotkeyGroups.removeValue(forKey: name) else { return }
        if !group.isEnabled {
            for shortcut in group.shortcuts {
                try? await unregisterShortcut(shortcut)
            }
        }
    }

    public func enableGroup(name: String) async {
        guard var group = hotkeyGroups[name], !group.isEnabled else { return }
        group.isEnabled = true
        hotkeyGroups[name] = group
    }

    public func disableGroup(name: String) async {
        guard var group = hotkeyGroups[name], group.isEnabled else { return }
        group.isEnabled = false
        hotkeyGroups[name] = group
    }

    public func addToGroup(name: String, shortcut: KeyboardShortcut) async {
        guard var group = hotkeyGroups[name] else { return }
        if !group.shortcuts.contains(shortcut) {
            group.shortcuts.append(shortcut)
            hotkeyGroups[name] = group
        }
    }

    public func removeFromGroup(name: String, shortcut: KeyboardShortcut) async {
        guard var group = hotkeyGroups[name] else { return }
        group.shortcuts.removeAll { $0 == shortcut }
        hotkeyGroups[name] = group
    }

    public func getGroups() async -> [String: HotkeyGroup] {
        hotkeyGroups
    }

    // MARK: - Usage Statistics

    private var usageStats: [String: Int] = [:]

    public func recordHotkeyUsage(shortcut: KeyboardShortcut) async {
        let key = shortcut.displayString
        usageStats[key, default: 0] += 1
    }

    public func getHotkeyUsageStats() async -> [String: Int] {
        usageStats
    }

    public func getTopHotkeys(limit: Int = 10) async -> [(shortcut: String, count: Int)] {
        usageStats
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (shortcut: $0.key, count: $0.value) }
    }

    // MARK: - Enhanced Error Handling

    public func registerWithRetry(
        _ shortcut: KeyboardShortcut,
        action: @escaping @Sendable () -> Void,
        maxRetries: Int = 3
    ) async throws {
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                try await registerShortcut(shortcut, action: action)
                return
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 100_000_000)
                }
            }
        }
        throw lastError ?? HotkeyError.registrationFailed(-1)
    }

    public func checkConflict(_ shortcut: KeyboardShortcut) async -> KeyboardShortcut? {
        for (existingShortcut, _) in registeredHotkeys {
            if existingShortcut.key == shortcut.key &&
               Set(existingShortcut.modifiers) == Set(shortcut.modifiers) {
                return existingShortcut
            }
        }
        return nil
    }
}

// MARK: - Hotkey Group

public struct HotkeyGroup: Sendable, Equatable {
    public let name: String
    public var isEnabled: Bool
    public var shortcuts: [KeyboardShortcut]

    public init(name: String, isEnabled: Bool = true, shortcuts: [KeyboardShortcut] = []) {
        self.name = name
        self.isEnabled = isEnabled
        self.shortcuts = shortcuts
    }
}

// MARK: - Hotkey Registration

private struct HotkeyRegistration {
    let shortcut: KeyboardShortcut
    let hotKeyRef: EventHotKeyRef
    let hotKeyID: EventHotKeyID
    let action: @Sendable () -> Void
}

// MARK: - Errors

public enum HotkeyError: Error, LocalizedError {
    case alreadyRegistered(KeyboardShortcut)
    case notFound(KeyboardShortcut)
    case conflict(KeyboardShortcut)
    case registrationFailed(OSStatus)
    case handlerInstallationFailed(OSStatus)
    
    public var errorDescription: String? {
        switch self {
        case .alreadyRegistered(let shortcut):
            return "快捷键 \(shortcut.displayString) 已注册"
        case .notFound(let shortcut):
            return "快捷键 \(shortcut.displayString) 未找到"
        case .conflict(let shortcut):
            return "快捷键与 \(shortcut.displayString) 冲突"
        case .registrationFailed(let status):
            return "快捷键注册失败 (状态码: \(status))"
        case .handlerInstallationFailed(let status):
            return "事件处理器安装失败 (状态码: \(status))"
        }
    }
}

// MARK: - KeyboardShortcut Extension

extension KeyboardShortcut {
    public var carbonKeyCode: UInt32 {
        // 返回 Carbon 键码
        let keyMap: [String: UInt32] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "return": 36,
            "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43,
            "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, " ": 49, "`": 50,
            "delete": 51, "enter": 52, "escape": 53, "space": 49
        ]
        return keyMap[key.lowercased()] ?? 0
    }
    
    public var carbonModifiers: UInt32 {
        var flags: UInt32 = 0
        for modifier in modifiers {
            switch modifier {
            case .command:
                flags |= UInt32(cmdKey)
            case .option:
                flags |= UInt32(optionKey)
            case .control:
                flags |= UInt32(controlKey)
            case .shift:
                flags |= UInt32(shiftKey)
            }
        }
        return flags
    }
}
