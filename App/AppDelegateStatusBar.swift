import AppKit
import SwiftUI
import AcMindKit

extension AppDelegate {
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "AcMind")
        }

        setupStatusBarMenu()
    }

    private func setupStatusBarMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "显示主窗口", action: #selector(showMainWindowFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "显示胶囊", action: #selector(toggleDesktopCapsuleFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let captureMenu = NSMenu(title: "快速采集")
        captureMenu.addItem(NSMenuItem(title: "截图", action: #selector(captureScreenshot), keyEquivalent: ""))
        captureMenu.addItem(NSMenuItem(title: "胶囊输入", action: #selector(showCapsuleFromMenu), keyEquivalent: ""))
        let captureItem = NSMenuItem(title: "快速采集", action: nil, keyEquivalent: "")
        captureItem.submenu = captureMenu
        menu.addItem(captureItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }
}
