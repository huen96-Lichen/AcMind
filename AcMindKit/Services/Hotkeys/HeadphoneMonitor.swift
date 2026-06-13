import Foundation
import AppKit

// MARK: - Headphone Monitor

/// 耳机按键监控服务
/// 职责：
/// 1. 监听耳机线控按钮（EarPods/AirPods 上的 play/pause 键）
/// 2. 转化为单击 / 双击 / 长按手势
/// 3. 支持蓝牙耳机和有线耳机
@MainActor
public final class HeadphoneMonitor {
    private static let logger = AcMindLogger(category: .shortcuts)
    
    // MARK: - Singleton
    
    public static let shared = HeadphoneMonitor()
    
    // MARK: - Properties
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isEnabled = false
    
    // MARK: - Gesture State
    
    private enum State {
        case idle
        case pressed
        case longPressActive
        case awaitingSecondTap
    }
    
    private var state: State = .idle
    private var longPressTimer: Timer?
    private var doubleTapTimer: Timer?
    private var pendingPlayPauseEvent: CGEvent?
    private var isSecondPress = false
    private var optimisticSingleHandled = false
    private var trustedPlayPausePressActive = false
    
    // MARK: - Callbacks
    
    private var onSingleTap: (() -> Bool)?
    private var onOptimisticSingleTap: (() -> Bool)?
    private var onCancelOptimisticSingleTap: (() -> Void)?
    private var onOptimisticSingleTapSettled: (() -> Void)?
    private var onDoubleTap: (() -> Void)?
    private var onLongPressStart: (() -> Void)?
    private var onLongPressEnd: (() -> Void)?
    private var onTapDisabled: (() -> Void)?
    
    // MARK: - Configuration
    
    private var isFeatureEnabled: () -> Bool = { true }
    private var isAuxMouseInterceptEnabled: () -> Bool = { false }
    private var hasTrustedPlayPauseSource: () -> Bool = { true }
    
    // MARK: - Constants
    
    private static let longPressThreshold: TimeInterval = 0.25
    private static let doubleTapWindow: TimeInterval = 0.28
    private static let nxSysDefinedType: UInt32 = 14
    private static let nxSubtypeAuxControlButtons: Int16 = 8
    private static let nxSubtypeAuxMouseButtons: Int16 = 7
    private static let nxKeyTypePlay: Int32 = 16
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// 启用耳机按键监控
    public func enable(
        onSingleTap: @escaping () -> Bool,
        onOptimisticSingleTap: @escaping () -> Bool = { false },
        onCancelOptimisticSingleTap: @escaping () -> Void = {},
        onOptimisticSingleTapSettled: @escaping () -> Void = {},
        onDoubleTap: @escaping () -> Void,
        onLongPressStart: @escaping () -> Void,
        onLongPressEnd: @escaping () -> Void,
        onTapDisabled: @escaping () -> Void = {},
        isFeatureEnabled: @escaping () -> Bool = { true },
        isAuxMouseInterceptEnabled: @escaping () -> Bool = { false },
        hasTrustedPlayPauseSource: @escaping () -> Bool = { true }
    ) {
        self.onSingleTap = onSingleTap
        self.onOptimisticSingleTap = onOptimisticSingleTap
        self.onCancelOptimisticSingleTap = onCancelOptimisticSingleTap
        self.onOptimisticSingleTapSettled = onOptimisticSingleTapSettled
        self.onDoubleTap = onDoubleTap
        self.onLongPressStart = onLongPressStart
        self.onLongPressEnd = onLongPressEnd
        self.onTapDisabled = onTapDisabled
        self.isFeatureEnabled = isFeatureEnabled
        self.isAuxMouseInterceptEnabled = isAuxMouseInterceptEnabled
        self.hasTrustedPlayPauseSource = hasTrustedPlayPauseSource
        
        start()
    }
    
    /// 禁用耳机按键监控
    public func disable() {
        stop()
        clearCallbacks()
    }
    
    /// 检查是否已启用
    public func isMonitoring() -> Bool {
        return isEnabled
    }
    
    /// 发送回车键（用于双击 → Enter）
    public func sendReturnKey() {
        DispatchQueue.global(qos: .userInitiated).async {
            let source = CGEventSource(stateID: .privateState)
            let returnKeyCode: CGKeyCode = 0x24
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: false) else {
                return
            }
            down.flags = []
            up.flags = []
            down.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.01)
            up.post(tap: .cghidEventTap)
        }
    }
    
    // MARK: - Private Methods
    
    private func start() {
        guard eventTap == nil else { return }
        
        let mask: CGEventMask = (1 << HeadphoneMonitor.nxSysDefinedType)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HeadphoneMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return MainActor.assumeIsolated {
                    monitor.handleEvent(type: type, event: event)
                }
            },
            userInfo: Unmanaged.passRetained(self).toOpaque()
        ) else {
            Self.logger.error("Failed to create event tap (missing Accessibility permission?)")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isEnabled = true
        Self.logger.info("Started")
    }
    
    private func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            Unmanaged<HeadphoneMonitor>.passUnretained(self).release()
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        resetGesture()
        isEnabled = false
        Self.logger.info("Stopped")
    }
    
    private func clearCallbacks() {
        onSingleTap = nil
        onOptimisticSingleTap = nil
        onCancelOptimisticSingleTap = nil
        onOptimisticSingleTapSettled = nil
        onDoubleTap = nil
        onLongPressStart = nil
        onLongPressEnd = nil
        onTapDisabled = nil
    }
    
    // MARK: - Event Handling
    
    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                if !CGEvent.tapIsEnabled(tap: tap) {
                    DispatchQueue.main.async { [weak self] in self?.onTapDisabled?() }
                }
            }
            return Unmanaged.passUnretained(event)
        }
        
        guard type.rawValue == HeadphoneMonitor.nxSysDefinedType else {
            return Unmanaged.passUnretained(event)
        }
        
        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }
        let data1 = nsEvent.data1
        let keyCode = Int32((data1 & 0xFFFF0000) >> 16)
        
        // 辅助鼠标按钮事件
        if nsEvent.subtype.rawValue == HeadphoneMonitor.nxSubtypeAuxMouseButtons && data1 == 1 {
            guard isAuxMouseInterceptEnabled() else {
                return Unmanaged.passUnretained(event)
            }
            return Unmanaged.passUnretained(event)
        }
        
        // 只处理 AUX 控制按钮中的 PLAY 键
        guard nsEvent.subtype.rawValue == HeadphoneMonitor.nxSubtypeAuxControlButtons else {
            return Unmanaged.passUnretained(event)
        }
        guard keyCode == HeadphoneMonitor.nxKeyTypePlay else {
            Self.logger.debug("Passing through non-PLAY media key keyCode=\(keyCode) subtype=\(nsEvent.subtype.rawValue)")
            return Unmanaged.passUnretained(event)
        }
        
        guard isFeatureEnabled() else {
            return Unmanaged.passUnretained(event)
        }
        
        let keyFlags = data1 & 0x0000FFFF
        let keyState = (keyFlags & 0xFF00) >> 8
        let isKeyDown = keyState == 0x0A
        
        if isKeyDown {
            guard hasTrustedPlayPauseSource() else {
                Self.logger.debug("Passing through PLAY: missing trusted HID source proof")
                return Unmanaged.passUnretained(event)
            }
            trustedPlayPausePressActive = true
        } else {
            guard trustedPlayPausePressActive else {
                return Unmanaged.passUnretained(event)
            }
            trustedPlayPausePressActive = false
        }
        
        let copy = event.copy()
        if isKeyDown {
            handlePlayKeyDown(originalCopy: copy)
        } else {
            handlePlayKeyUp()
        }
        return nil
    }
    
    private func handlePlayKeyDown(originalCopy: CGEvent?) {
        switch state {
        case .idle:
            isSecondPress = false
            optimisticSingleHandled = onOptimisticSingleTap?() ?? false
            pendingPlayPauseEvent = optimisticSingleHandled ? nil : originalCopy
            state = .pressed
            if optimisticSingleHandled {
                Self.logger.info("Single tap handled optimistically, waiting for double-tap window")
            } else {
                scheduleLongPressTimer()
            }
        case .awaitingSecondTap:
            doubleTapTimer?.invalidate()
            doubleTapTimer = nil
            pendingPlayPauseEvent = nil
            isSecondPress = true
            state = .pressed
            scheduleLongPressTimer()
        case .pressed, .longPressActive:
            break
        }
    }
    
    private func handlePlayKeyUp() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        
        switch state {
        case .longPressActive:
            state = .idle
            isSecondPress = false
            pendingPlayPauseEvent = nil
            settleOptimisticSingleTap(cancel: false)
            onLongPressEnd?()
        case .pressed:
            if isSecondPress {
                state = .idle
                isSecondPress = false
                pendingPlayPauseEvent = nil
                settleOptimisticSingleTap(cancel: true)
                onDoubleTap?()
            } else {
                state = .awaitingSecondTap
                scheduleDoubleTapTimer()
            }
        default:
            break
        }
    }
    
    private func scheduleLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: HeadphoneMonitor.longPressThreshold, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.state == .pressed else { return }
                self.state = .longPressActive
                self.pendingPlayPauseEvent = nil
                self.onLongPressStart?()
            }
        }
    }
    
    private func scheduleDoubleTapTimer() {
        doubleTapTimer?.invalidate()
        doubleTapTimer = Timer.scheduledTimer(withTimeInterval: HeadphoneMonitor.doubleTapWindow, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.state == .awaitingSecondTap else { return }
                let cachedEvent = self.pendingPlayPauseEvent
                self.pendingPlayPauseEvent = nil
                self.state = .idle
                if self.optimisticSingleHandled {
                    self.settleOptimisticSingleTap(cancel: false)
                    return
                }
                let handled = self.onSingleTap?() ?? false
                if !handled, let event = cachedEvent {
                    event.post(tap: .cgSessionEventTap)
                }
            }
        }
    }
    
    private func settleOptimisticSingleTap(cancel: Bool) {
        guard optimisticSingleHandled else { return }
        optimisticSingleHandled = false
        if cancel {
            Self.logger.info("Double tap confirmed, canceling optimistic single tap")
            onCancelOptimisticSingleTap?()
        } else {
            onOptimisticSingleTapSettled?()
        }
    }
    
    private func resetGesture() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        doubleTapTimer?.invalidate()
        doubleTapTimer = nil
        pendingPlayPauseEvent = nil
        isSecondPress = false
        settleOptimisticSingleTap(cancel: false)
        trustedPlayPausePressActive = false
        state = .idle
    }
}
