import AppKit
import ApplicationServices
import AcMindKit

@MainActor
struct PlaceholderWindowPruneContext {
    var mainWindow: NSWindow?
    var launchWindow: NSWindow?
    var excludedWindows: [NSWindow?]

    static let empty = PlaceholderWindowPruneContext(
        mainWindow: nil,
        launchWindow: nil,
        excludedWindows: []
    )
}

@MainActor
final class PlaceholderWindowPruner {
    private var pruneTask: Task<Void, Never>?

    func prune(context: PlaceholderWindowPruneContext) {
        for window in NSApp.windows {
            guard shouldClose(window: window, context: context) else { continue }
            window.orderOut(nil)
            window.close()
        }

        pruneAccessibilityWindows()
    }

    func schedule(contextProvider: @escaping @MainActor () -> PlaceholderWindowPruneContext) {
        guard pruneTask == nil else { return }
        pruneTask = Task { @MainActor in
            while Task.isCancelled == false {
                self.prune(context: contextProvider())
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stop() {
        pruneTask?.cancel()
        pruneTask = nil
    }

    private func shouldClose(window: NSWindow, context: PlaceholderWindowPruneContext) -> Bool {
        guard window !== context.mainWindow,
              window !== context.launchWindow,
              context.excludedWindows.contains(where: { excludedWindow in
                  guard let excludedWindow else { return false }
                  return window === excludedWindow
              }) == false else {
            return false
        }
        guard window.level < .statusBar else { return false }

        let title = window.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return isPlaceholder(title: title, width: window.frame.width, height: window.frame.height)
    }

    private func pruneAccessibilityWindows() {
        let appElement = AXUIElementCreateApplication(pid_t(ProcessInfo.processInfo.processIdentifier))
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return }

        for window in windows {
            var titleValue: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            let title = (titleValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            var sizeValue: CFTypeRef?
            let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)
            var windowSize = CGSize.zero
            if sizeResult == .success, let sizeValue, CFGetTypeID(sizeValue) == AXValueGetTypeID() {
                let axValue = unsafeDowncast(sizeValue as AnyObject, to: AXValue.self)
                AXValueGetValue(axValue, .cgSize, &windowSize)
            }

            guard windowSize.width > 64 || windowSize.height > 64 else { continue }
            guard shouldConsiderAccessibilityWindow(size: windowSize) else { continue }
            guard isPlaceholder(title: title, width: windowSize.width, height: windowSize.height) else { continue }

            if titleResult == .success || sizeResult == .success {
                var closeButtonValue: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &closeButtonValue) == .success,
                   let closeButtonValue,
                   CFGetTypeID(closeButtonValue) == AXUIElementGetTypeID() {
                    let closeButton = unsafeDowncast(closeButtonValue as AnyObject, to: AXUIElement.self)
                    AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
                }
            }
        }
    }

    private func shouldConsiderAccessibilityWindow(size: CGSize) -> Bool {
        let isCompanionCollapsedWindow =
            size.width >= CompanionMenuBarLayout.collapsedMinWidth &&
            size.width <= CompanionMenuBarLayout.collapsedMaxWidth &&
            size.height >= CompanionMenuBarLayout.collapsedMinHeight &&
            size.height <= CompanionMenuBarLayout.collapsedMaxHeight
        let isDesktopCapsuleWindow = size.width <= 60 && size.height <= 60
        return isCompanionCollapsedWindow == false && isDesktopCapsuleWindow == false
    }

    private func isPlaceholder(title: String, width: CGFloat, height: CGFloat) -> Bool {
        let isSmallLaunchShell = width <= 520 && height <= 420
        let isThinPlaceholder = width >= 800 && height <= 120
        let isAcMindTitle = title == "AcMind"
        let isBrandTitle = [AcWorkBrand.displayName, AcWorkBrand.legacyInternalName].contains(title)
        let isBlankAuxiliaryWindow =
            title.isEmpty &&
            width >= 500 && width <= 540 &&
            height >= 280 && height <= 320

        return
            (title.isEmpty && isSmallLaunchShell) ||
            (title == "AcMind" && isSmallLaunchShell) ||
            (isBrandTitle && isSmallLaunchShell) ||
            ((title.isEmpty || title == "AcMind") && isThinPlaceholder) ||
            ((title.isEmpty || isBrandTitle) && isThinPlaceholder) ||
            (isAcMindTitle && isThinPlaceholder) ||
            isBlankAuxiliaryWindow
    }
}
