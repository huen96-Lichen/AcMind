import Foundation
import AppKit
import ApplicationServices
import Carbon

public struct InjectionResult: Sendable {
    public let method: String
    public let success: Bool
    public let duration: TimeInterval
    public let characterCount: Int
}

public final class AXTextInjector: TextInjector, @unchecked Sendable {
    
    // MARK: - Constants
    
    private static let cgEventUnicodeLimit = 200
    private static let pasteRestoreDelay: TimeInterval = 0.5
    private static let inputSourceSwitchDelay: TimeInterval = 0.05
    private static let menuPasteDelay: TimeInterval = 0.3
    
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
    
    // MARK: - AX Cache
    
    private struct AXCache {
        var focusedElement: AXUIElement?
        var focusedPID: pid_t?
        var timestamp: Date = .distantPast
        let ttl: TimeInterval = 0.5
        
        var isValid: Bool { Date().timeIntervalSince(timestamp) < ttl }
        mutating func invalidate() { focusedElement = nil; focusedPID = nil; timestamp = .distantPast }
    }
    
    // MARK: - Properties
    
    private let pasteboard: NSPasteboard = .general
    private let injectionQueue = DispatchQueue(label: "com.acmind.textinjector", qos: .userInitiated)
    private var isCurrentlyInjecting = false
    private let injectionSemaphore = DispatchSemaphore(value: 1)
    private var axCache = AXCache()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - TextInjector Protocol
    
    public func getSelectionSnapshot() async -> TextSelectionSnapshot {
        var snapshot = TextSelectionSnapshot()
        
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return snapshot
        }
        
        snapshot.processID = app.processIdentifier
        snapshot.processName = app.localizedName
        snapshot.bundleIdentifier = app.bundleIdentifier
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElement: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement as! AXUIElement? else {
            return snapshot
        }
        
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           let roleString = role as? String {
            snapshot.role = roleString
            snapshot.isEditable = roleString == kAXTextFieldRole as String ||
                                  roleString == kAXTextAreaRole as String ||
                                  roleString == "AXWebArea"
        }
        
        var selection: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selection) == .success,
           let selectedText = selection as? String {
            snapshot.selectedText = selectedText
            snapshot.source = "accessibility"
        }
        
        var range: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success,
           let rangeValue = range as! AXValue? {
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
        var focusedElement: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement as! AXUIElement? else {
            snapshot.failureReason = "无法获取焦点元素"
            return snapshot
        }
        
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role) == .success,
           let roleString = role as? String {
            snapshot.role = roleString
            snapshot.isEditable = roleString == kAXTextFieldRole as String ||
                                  roleString == kAXTextAreaRole as String
        }
        
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
        guard AXIsProcessTrusted() else {
            throw TextInjectionError.permissionDenied
        }

        guard !text.isEmpty else { return }

        injectionSemaphore.wait()
        defer { injectionSemaphore.signal() }

        let finalText = processTextWithPunctuationCheck(text)
        let charCount = finalText.utf16.count

        var startTime = CFAbsoluteTimeGetCurrent()
        if tryInsertViaCGEventUnicode(finalText) {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            Task { await InjectionMetrics.shared.record(method: "postToPid", success: true) }
            _ = InjectionResult(method: "postToPid", success: true, duration: duration, characterCount: charCount)
            return
        }
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        Task { await InjectionMetrics.shared.record(method: "postToPid", success: false) }
        _ = InjectionResult(method: "postToPid", success: false, duration: duration, characterCount: charCount)

        startTime = CFAbsoluteTimeGetCurrent()
        if tryInsertViaAccessibility(finalText) {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            Task { await InjectionMetrics.shared.record(method: "accessibility", success: true) }
            _ = InjectionResult(method: "accessibility", success: true, duration: duration, characterCount: charCount)
            return
        }
        let axDuration = CFAbsoluteTimeGetCurrent() - startTime
        Task { await InjectionMetrics.shared.record(method: "accessibility", success: false) }
        _ = InjectionResult(method: "accessibility", success: false, duration: axDuration, characterCount: charCount)

        startTime = CFAbsoluteTimeGetCurrent()
        if tryInsertViaCGEventHID(finalText) {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            Task { await InjectionMetrics.shared.record(method: "cgEventHID", success: true) }
            _ = InjectionResult(method: "cgEventHID", success: true, duration: duration, characterCount: charCount)
            return
        }
        let hidDuration = CFAbsoluteTimeGetCurrent() - startTime
        Task { await InjectionMetrics.shared.record(method: "cgEventHID", success: false) }
        _ = InjectionResult(method: "cgEventHID", success: false, duration: hidDuration, characterCount: charCount)

        startTime = CFAbsoluteTimeGetCurrent()
        do {
            try tryInsertViaClipboardWithVerification(finalText)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            Task { await InjectionMetrics.shared.record(method: "clipboard", success: true) }
            _ = InjectionResult(method: "clipboard", success: true, duration: duration, characterCount: charCount)
            return
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            Task { await InjectionMetrics.shared.record(method: "clipboard", success: false) }
            _ = InjectionResult(method: "clipboard", success: false, duration: duration, characterCount: charCount)
        }

        startTime = CFAbsoluteTimeGetCurrent()
        tryInsertViaCharacterByCharacter(finalText)
        let charDuration = CFAbsoluteTimeGetCurrent() - startTime
        Task { await InjectionMetrics.shared.record(method: "characterByCharacter", success: true) }
        _ = InjectionResult(method: "characterByCharacter", success: true, duration: charDuration, characterCount: charCount)
        
        axCache.invalidate()
    }
    
    public func replaceSelection(text: String) throws {
        guard AXIsProcessTrusted() else {
            throw TextInjectionError.permissionDenied
        }

        guard let app = NSWorkspace.shared.frontmostApplication else {
            throw TextInjectionError.noFocusedApplication
        }

        injectionSemaphore.wait()
        defer { injectionSemaphore.signal() }

        let finalText = processTextWithPunctuationCheck(text)
        let charCount = finalText.utf16.count

        var startTime = CFAbsoluteTimeGetCurrent()
        if tryInsertViaCGEventUnicode(finalText) {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            Task { await InjectionMetrics.shared.record(method: "postToPid", success: true) }
            _ = InjectionResult(method: "postToPid", success: true, duration: duration, characterCount: charCount)
            return
        }
        var duration = CFAbsoluteTimeGetCurrent() - startTime
        Task { await InjectionMetrics.shared.record(method: "postToPid", success: false) }
        _ = InjectionResult(method: "postToPid", success: false, duration: duration, characterCount: charCount)

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElement: CFTypeRef?

        if AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
           let element = focusedElement as! AXUIElement? {

            startTime = CFAbsoluteTimeGetCurrent()
            if tryInsertViaAccessibility(finalText, targetElement: element) {
                duration = CFAbsoluteTimeGetCurrent() - startTime
                Task { await InjectionMetrics.shared.record(method: "accessibility", success: true) }
                _ = InjectionResult(method: "accessibility", success: true, duration: duration, characterCount: charCount)
                return
            }
            duration = CFAbsoluteTimeGetCurrent() - startTime
            Task { await InjectionMetrics.shared.record(method: "accessibility", success: false) }
            _ = InjectionResult(method: "accessibility", success: false, duration: duration, characterCount: charCount)
        }

        startTime = CFAbsoluteTimeGetCurrent()
        if tryInsertViaCGEventHID(finalText) {
            duration = CFAbsoluteTimeGetCurrent() - startTime
            Task { await InjectionMetrics.shared.record(method: "cgEventHID", success: true) }
            _ = InjectionResult(method: "cgEventHID", success: true, duration: duration, characterCount: charCount)
            return
        }
        duration = CFAbsoluteTimeGetCurrent() - startTime
        Task { await InjectionMetrics.shared.record(method: "cgEventHID", success: false) }
        _ = InjectionResult(method: "cgEventHID", success: false, duration: duration, characterCount: charCount)

        startTime = CFAbsoluteTimeGetCurrent()
        do {
            try tryInsertViaClipboardWithVerification(finalText)
            duration = CFAbsoluteTimeGetCurrent() - startTime
            Task { await InjectionMetrics.shared.record(method: "clipboard", success: true) }
            _ = InjectionResult(method: "clipboard", success: true, duration: duration, characterCount: charCount)
            return
        } catch {
            duration = CFAbsoluteTimeGetCurrent() - startTime
            Task { await InjectionMetrics.shared.record(method: "clipboard", success: false) }
            _ = InjectionResult(method: "clipboard", success: false, duration: duration, characterCount: charCount)
        }

        startTime = CFAbsoluteTimeGetCurrent()
        tryInsertViaCharacterByCharacter(finalText)
        duration = CFAbsoluteTimeGetCurrent() - startTime
        Task { await InjectionMetrics.shared.record(method: "characterByCharacter", success: true) }
        _ = InjectionResult(method: "characterByCharacter", success: true, duration: duration, characterCount: charCount)
        
        axCache.invalidate()
    }
    
    // MARK: - Text Processing
    
    private func processTextWithPunctuationCheck(_ text: String) -> String {
        let nextChar = getCharacterAfterCursor()
        guard let next = nextChar, isSentenceEndingPunctuation(next) else {
            return text
        }
        return removeTrailingPunctuation(text)
    }
    
    private func isSentenceEndingPunctuation(_ char: Character) -> Bool {
        return "。！？.!?".contains(char)
    }
    
    private func removeTrailingPunctuation(_ text: String) -> String {
        var trimmed = text
        while let last = trimmed.last, isSentenceEndingPunctuation(last) {
            trimmed = String(trimmed.dropLast())
        }
        return trimmed
    }
    
    // MARK: - Accessibility Insertion
    
    private func tryInsertViaAccessibility(_ text: String, targetElement: AXUIElement? = nil) -> Bool {
        let element: AXUIElement?
        
        if let target = targetElement {
            element = target
        } else {
            element = getFocusedTextElement()
        }
        
        guard let el = element else { return false }
        
        if insertViaAXValue(el, text: text) {
            return true
        }
        
        if insertViaAXSelectedText(el, text: text) {
            return true
        }
        
        if insertViaAXSelectedRange(el, text: text) {
            return true
        }
        
        return false
    }
    
    private func getFocusedTextElement() -> AXUIElement? {
        if axCache.isValid, let cached = axCache.focusedElement {
            return cached
        }
        
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else {
            return nil
        }
        
        guard CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return nil
        }
        
        let axElement = element as! AXUIElement
        axCache.focusedElement = axElement
        axCache.timestamp = Date()
        return axElement
    }
    
    private func insertViaAXValue(_ element: AXUIElement, text: String) -> Bool {
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
        return result == .success
    }
    
    private func insertViaAXSelectedText(_ element: AXUIElement, text: String) -> Bool {
        let selectAllResult = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, "" as CFString)
        guard selectAllResult == .success else { return false }
        
        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        return result == .success
    }
    
    private func insertViaAXSelectedRange(_ element: AXUIElement, text: String) -> Bool {
        guard let currentValue = getElementValue(element),
              var range = getSelectedTextRange(element) else {
            return false
        }
        
        let currentNSString = currentValue as NSString
        let maxLen = currentNSString.length
        
        let safeLoc = max(0, min(range.location, maxLen))
        let safeLen = max(0, min(range.length, maxLen - safeLoc))
        range = CFRange(location: safeLoc, length: safeLen)
        
        let mutable = NSMutableString(string: currentValue)
        mutable.replaceCharacters(in: NSRange(location: range.location, length: range.length), with: text)
        let newValue = mutable as String
        
        let setResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValue as CFString)
        guard setResult == .success else { return false }
        
        let insertedLen = (text as NSString).length
        var newRange = CFRange(location: range.location + insertedLen, length: 0)
        if let axRange = AXValueCreate(.cfRange, &newRange) {
            _ = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, axRange)
        }
        
        return true
    }
    
    // MARK: - CGEvent Unicode Insertion
    
    private func tryInsertViaCGEventUnicode(_ text: String, retries: Int = 1) -> Bool {
        guard let focusedPID = getFocusedPID(), focusedPID > 0 else {
            return false
        }

        let utf16Array = Array(text.utf16)
        guard utf16Array.count <= Self.cgEventUnicodeLimit else {
            return false
        }

        for attempt in 0...retries {
            if attempt > 0 {
                usleep(50_000)
            }

            guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
                continue
            }

            keyDown.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: utf16Array)
            keyUp.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: utf16Array)

            keyDown.postToPid(focusedPID)
            usleep(2000)
            keyUp.postToPid(focusedPID)

            return true
        }

        return false
    }
    
    private func tryInsertViaCGEventHID(_ text: String) -> Bool {
        let utf16Array = Array(text.utf16)
        guard utf16Array.count <= Self.cgEventUnicodeLimit else {
            return false
        }
        
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            return false
        }
        
        keyDown.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: utf16Array)
        keyUp.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: utf16Array)
        
        keyDown.post(tap: .cghidEventTap)
        usleep(2000)
        keyUp.post(tap: .cghidEventTap)
        
        return true
    }
    
    private func getFocusedPID() -> pid_t? {
        if axCache.isValid, let cached = axCache.focusedPID {
            return cached
        }
        
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
        
        guard pid > 0 else { return nil }
        axCache.focusedPID = pid
        axCache.timestamp = Date()
        return pid
    }
    
    // MARK: - Clipboard Insertion with CJK Support
    
    private func tryInsertViaClipboardWithVerification(_ text: String) throws {
        let previousContents = savePasteboard()
        
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw TextInjectionError.insertionFailed("无法设置剪贴板内容")
        }
        
        let originalSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let needsInputSourceSwitch = isCJKInputSource(originalSource)
        
        if needsInputSourceSwitch {
            switchToASCIIInputSource()
        }
        
        let pasteDelay = needsInputSourceSwitch ? Self.inputSourceSwitchDelay : 0.02
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) { [weak self] in
            guard let self else { return }
            self.simulatePaste()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.pasteRestoreDelay) { [weak self] in
                guard let self else { return }
                
                if needsInputSourceSwitch {
                    TISSelectInputSource(originalSource)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.restorePasteboard(previousContents)
                }
            }
        }
    }
    
    private func tryInsertViaCharacterByCharacter(_ text: String) {
        for char in text {
            typeCharacter(char)
            usleep(1000)
        }
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
    
    // MARK: - Character After Cursor Detection
    
    private func getCharacterAfterCursor() -> Character? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else {
            return nil
        }
        
        guard CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return nil
        }
        
        let focusedUIElement = element as! AXUIElement
        
        var selectedRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedUIElement, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success,
              let range = selectedRange else {
            return nil
        }
        
        guard CFGetTypeID(range) == AXValueGetTypeID() else {
            return nil
        }
        
        var rangeValue = CFRange()
        guard AXValueGetValue(range as! AXValue, .cfRange, &rangeValue) else {
            return nil
        }
        
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedUIElement, kAXValueAttribute as CFString, &value) == .success,
              let text = value as? String else {
            return nil
        }
        
        let utf16 = text.utf16
        let nextIndex = rangeValue.location + rangeValue.length
        guard nextIndex >= 0, nextIndex < utf16.count else {
            return nil
        }
        
        let utf16Index = utf16.index(utf16.startIndex, offsetBy: nextIndex)
        guard let charIndex = utf16Index.samePosition(in: text) else {
            return nil
        }
        
        return text[charIndex]
    }
    
    // MARK: - Helper Methods
    
    private func getElementValue(_ element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
              let text = value as? String else {
            return nil
        }
        return text
    }
    
    private func getSelectedTextRange(_ element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let axValue = value else {
            return nil
        }
        
        guard CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }
        
        var range = CFRange()
        guard AXValueGetValue(axValue as! AXValue, .cfRange, &range) else {
            return nil
        }
        
        return range
    }
    
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
    
    private func typeCharacter(_ char: Character) {
        let charString = String(char)
        let utf16Array = Array(charString.utf16)
        
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            return
        }
        
        keyDownEvent.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: utf16Array)
        keyUpEvent.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: utf16Array)
        
        keyDownEvent.post(tap: .cghidEventTap)
        usleep(2000)
        keyUpEvent.post(tap: .cghidEventTap)
    }
    
    // MARK: - Pasteboard Save/Restore
    
    private struct PasteboardItem {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }
    
    private func savePasteboard() -> [[PasteboardItem]] {
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
    
    private func restorePasteboard(_ contents: [[PasteboardItem]]) {
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
