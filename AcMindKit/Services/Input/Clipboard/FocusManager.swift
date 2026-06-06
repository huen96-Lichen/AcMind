import Foundation
import AppKit

public final class FocusManager: @unchecked Sendable {
    
    private var savedApp: NSRunningApplication?
    
    public init() {}
    
    public func saveCurrentFocus() {
        savedApp = NSWorkspace.shared.frontmostApplication
    }
    
    public func restoreFocus() {
        guard let app = savedApp else { return }
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
        }
        savedApp = nil
    }
    
    public func clearSavedFocus() {
        savedApp = nil
    }
}
