import Foundation
import AppKit
import ApplicationServices
import Carbon

public actor StreamingKeyboardWriter {

    // MARK: - Constants

    private static let cgEventUnicodeLimit = 200
    private static let flushInterval: TimeInterval = 0.012
    private static let inputSourceSwitchDelay: UInt32 = 50_000
    private static let charPostDelay: UInt32 = 2_000

    // MARK: - CJK Input Source Patterns

    private static let cjkInputSourcePatterns: [String] = [
        "com.apple.inputmethod.SCIM",
        "com.apple.inputmethod.TCIM",
        "com.apple.inputmethod.Japanese",
        "com.apple.inputmethod.Korean",
        "com.apple.inputmethod.ChineseHandwriting",
        "com.apple.inputmethod.Chinese",
        "com.google.inputmethod.Japanese",
        "com.sogou.inputmethod",
        "com.baidu.inputmethod",
        "com.tencent.inputmethod",
        "com.alibaba.inputmethod",
        "com.microsoft.inputmethod",
    ]

    // MARK: - State

    private var pendingText: String = ""
    private var flushTask: Task<Void, Never>?
    private var isCancelled = false
    private var injectedSuccessfully = true

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    public func write(chunk: String) {
        guard !isCancelled, !chunk.isEmpty else { return }
        pendingText += chunk
        scheduleFlush()
    }

    public func finish() async -> Bool {
        guard !isCancelled else { return injectedSuccessfully }
        flushTask?.cancel()
        flushTask = nil
        await flushPending()
        return injectedSuccessfully
    }

    public func cancel() {
        isCancelled = true
        flushTask?.cancel()
        flushTask = nil
        pendingText = ""
    }

    // MARK: - Flush Scheduling

    private func scheduleFlush() {
        flushTask?.cancel()
        flushTask = Task { [flushInterval = Self.flushInterval] in
            try? await Task.sleep(nanoseconds: UInt64(flushInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await flushPending()
        }
    }

    // MARK: - Flush Execution

    private func flushPending() async {
        guard !isCancelled, !pendingText.isEmpty else { return }
        let text = pendingText
        pendingText = ""

        if isEditableFocused() {
            await typeCharactersViaCGEvent(text)
        } else {
            fallbackClipboard(text)
        }
    }

    // MARK: - CGEvent Unicode Typing

    private func typeCharactersViaCGEvent(_ text: String) async {
        guard AXIsProcessTrusted() else {
            injectedSuccessfully = false
            return
        }
        guard let pid = focusedPID(), pid > 0 else {
            injectedSuccessfully = false
            fallbackClipboard(text)
            return
        }

        let originalSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let needsSwitch = isCJKInputSource(originalSource)

        if needsSwitch {
            switchToASCIIInputSource()
            usleep(Self.inputSourceSwitchDelay)
        }

        defer {
            if needsSwitch {
                TISSelectInputSource(originalSource)
            }
        }

        for char in text {
            guard !isCancelled else { return }
            if Task.isCancelled { return }
            typeSingleCharacter(char, toPID: pid)
            usleep(Self.charPostDelay)
        }
    }

    private func typeSingleCharacter(_ char: Character, toPID pid: pid_t) {
        let charString = String(char)
        let utf16Array = Array(charString.utf16)

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            return
        }

        keyDown.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: utf16Array)
        keyUp.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: utf16Array)

        keyDown.postToPid(pid)
        usleep(Self.charPostDelay)
        keyUp.postToPid(pid)
    }

    // MARK: - Clipboard Fallback

    private func fallbackClipboard(_ text: String) {
        Task {
            await performClipboardPaste(text)
        }
    }

    private func performClipboardPaste(_ text: String) async {
        let pasteboard = NSPasteboard.general
        let previousContents = savePasteboard(pasteboard)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { return }

        let originalSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let needsSwitch = isCJKInputSource(originalSource)

        if needsSwitch {
            switchToASCIIInputSource()
        }

        let pasteDelay: UInt64 = needsSwitch ? 50_000_000 : 20_000_000
        try? await Task.sleep(nanoseconds: pasteDelay)
        guard !isCancelled else {
            restorePasteboard(pasteboard, contents: previousContents)
            return
        }

        simulatePaste()

        try? await Task.sleep(nanoseconds: 500_000_000)
        if needsSwitch {
            TISSelectInputSource(originalSource)
        }

        try? await Task.sleep(nanoseconds: 50_000_000)
        restorePasteboard(pasteboard, contents: previousContents)
    }

    // MARK: - Focus Detection

    private func isEditableFocused() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElement: CFTypeRef?

        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement as! AXUIElement? else {
            return false
        }

        var role: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
              let roleString = role as? String else {
            return false
        }

        return roleString == kAXTextFieldRole as String ||
               roleString == kAXTextAreaRole as String ||
               roleString == "AXWebArea"
    }

    private func focusedPID() -> pid_t? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?

        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else {
            return nil
        }

        guard CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return nil
        }

        var pid: pid_t = 0
        AXUIElementGetPid(element as! AXUIElement, &pid)

        return pid > 0 ? pid : nil
    }

    // MARK: - CJK Input Source Handling

    private func isCJKInputSource(_ source: TISInputSource) -> Bool {
        guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return false
        }

        let sourceID = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String

        return Self.cjkInputSourcePatterns.contains { sourceID.contains($0) }
    }

    private func switchToASCIIInputSource() {
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceType: kTISTypeKeyboardLayout as Any,
        ]

        guard let sources = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] else {
            return
        }

        let preferredLayouts = ["com.apple.keylayout.ABC", "com.apple.keylayout.US", "com.apple.keylayout.USExtended"]

        for prefID in preferredLayouts {
            if let source = sources.first(where: { source in
                guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return false }
                let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
                return id == prefID
            }) {
                TISSelectInputSource(source)
                return
            }
        }

        if let asciiCapableSource = sources.first(where: { source in
            guard let capablePtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsASCIICapable) else { return false }
            return Unmanaged<CFBoolean>.fromOpaque(capablePtr).takeUnretainedValue() == kCFBooleanTrue
        }) {
            TISSelectInputSource(asciiCapableSource)
            return
        }

        if let first = sources.first {
            TISSelectInputSource(first)
        }
    }

    // MARK: - Pasteboard Helpers

    private struct PasteboardItem {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    private func savePasteboard(_ pasteboard: NSPasteboard) -> [[PasteboardItem]] {
        var allItems: [[PasteboardItem]] = []

        for item in pasteboard.pasteboardItems ?? [] {
            var itemData: [PasteboardItem] = []
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemData.append(PasteboardItem(type: type, data: data))
                }
            }
            allItems.append(itemData)
        }

        return allItems
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, contents: [[PasteboardItem]]) {
        pasteboard.clearContents()

        guard !contents.isEmpty else { return }

        var items: [NSPasteboardItem] = []
        for itemData in contents {
            let item = NSPasteboardItem()
            for entry in itemData {
                item.setData(entry.data, forType: entry.type)
            }
            items.append(item)
        }

        _ = pasteboard.writeObjects(items)
    }

    // MARK: - Paste Simulation

    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)

        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(55), keyDown: true),
              let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(9), keyDown: true),
              let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(9), keyDown: false),
              let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(55), keyDown: false) else {
            return
        }

        cmdDown.flags = .maskCommand
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        cmdUp.flags = .maskCommand

        cmdDown.post(tap: .cghidEventTap)
        usleep(10_000)
        vDown.post(tap: .cghidEventTap)
        usleep(10_000)
        vUp.post(tap: .cghidEventTap)
        usleep(10_000)
        cmdUp.post(tap: .cghidEventTap)
    }
}
