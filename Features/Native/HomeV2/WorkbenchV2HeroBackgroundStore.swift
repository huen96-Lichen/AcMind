import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class WorkbenchV2HeroBackgroundStore: ObservableObject {
    static let shared = WorkbenchV2HeroBackgroundStore()

    private enum Constants {
        static let storageKey = "WorkbenchV2.heroBackgroundPath"
        static let destinationFolderName = "WorkbenchV2/Backgrounds"
        static let destinationBaseName = "hero-background"
    }

    @Published private(set) var backgroundImage: NSImage
    @Published private(set) var backgroundPath: String

    private let fileManager: FileManager
    private let userDefaults: UserDefaults

    init(fileManager: FileManager = .default, userDefaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        self.backgroundPath = userDefaults.string(forKey: Constants.storageKey) ?? ""
        self.backgroundImage = Self.makeDefaultBackgroundImage()
        reloadStoredBackground()
    }

    func chooseBackground() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        panel.resolvesAliases = true
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = "选择背景"
        panel.message = "只允许本地图片，选择后会复制到应用持久化目录。"

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        do {
            try setBackground(from: selectedURL)
        } catch {
            NSLog("WorkbenchV2 background selection failed: \(error.localizedDescription)")
            resetToDefaultBackground()
        }
    }

    func setBackground(from sourceURL: URL) throws {
        let destinationURL = try copyBackgroundIntoAppSupport(from: sourceURL)
        applyBackground(url: destinationURL)
    }

    func resetToDefaultBackground() {
        backgroundPath = ""
        userDefaults.removeObject(forKey: Constants.storageKey)
        backgroundImage = Self.makeDefaultBackgroundImage()
    }

    var resolvedBackgroundImage: NSImage {
        backgroundImage
    }

    private func reloadStoredBackground() {
        guard backgroundPath.isEmpty == false else {
            backgroundImage = Self.makeDefaultBackgroundImage()
            return
        }

        let url = URL(fileURLWithPath: backgroundPath)
        guard let image = NSImage(contentsOf: url) else {
            resetToDefaultBackground()
            return
        }

        backgroundImage = image
    }

    private func applyBackground(url: URL) {
        backgroundPath = url.path
        userDefaults.set(url.path, forKey: Constants.storageKey)
        if let image = NSImage(contentsOf: url) {
            backgroundImage = image
        } else {
            resetToDefaultBackground()
        }
    }

    private func copyBackgroundIntoAppSupport(from sourceURL: URL) throws -> URL {
        let destinationFolder = try ensureDestinationFolder()
        let extensionName = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let destinationURL = destinationFolder.appendingPathComponent("\(Constants.destinationBaseName).\(extensionName)")

        try removeExistingBackgroundFiles(in: destinationFolder)
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private func removeExistingBackgroundFiles(in folder: URL) throws {
        let contents = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for url in contents where url.deletingPathExtension().lastPathComponent == Constants.destinationBaseName {
            try? fileManager.removeItem(at: url)
        }
    }

    private func ensureDestinationFolder() throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let bundleName = Bundle.main.bundleIdentifier ?? "AcMind"
        let rootFolder = applicationSupportURL.appendingPathComponent(bundleName, isDirectory: true)
        let destinationFolder = rootFolder.appendingPathComponent(Constants.destinationFolderName, isDirectory: true)
        if fileManager.fileExists(atPath: destinationFolder.path) == false {
            try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        }
        return destinationFolder
    }

    static func makeDefaultBackgroundImage() -> NSImage {
        let size = NSSize(width: 1600, height: 900)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let bounds = NSRect(origin: .zero, size: size)
        NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.15, alpha: 1).setFill()
        bounds.fill()

        let backgroundGradient = NSGradient(
            colors: [
                NSColor(calibratedRed: 0.13, green: 0.22, blue: 0.31, alpha: 1),
                NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.19, alpha: 1),
                NSColor(calibratedRed: 0.04, green: 0.07, blue: 0.11, alpha: 1)
            ]
        )
        backgroundGradient?.draw(in: bounds, angle: 0)

        let accentGradient = NSGradient(
            colors: [
                NSColor(calibratedRed: 0.36, green: 0.77, blue: 0.97, alpha: 0.42),
                NSColor(calibratedRed: 0.55, green: 0.44, blue: 0.98, alpha: 0.20),
                NSColor.clear
            ]
        )
        accentGradient?.draw(in: NSRect(x: -120, y: 330, width: 980, height: 540), angle: -8)

        let warmGradient = NSGradient(
            colors: [
                NSColor(calibratedRed: 0.96, green: 0.68, blue: 0.27, alpha: 0.28),
                NSColor(calibratedRed: 0.95, green: 0.88, blue: 0.56, alpha: 0.10),
                NSColor.clear
            ]
        )
        warmGradient?.draw(in: NSRect(x: 760, y: 540, width: 720, height: 400), angle: 18)

        let circles: [(rect: CGRect, color: NSColor)] = [
            (CGRect(x: 120, y: 92, width: 480, height: 480), NSColor(calibratedRed: 0.18, green: 0.48, blue: 0.92, alpha: 0.24)),
            (CGRect(x: 820, y: 220, width: 380, height: 380), NSColor(calibratedRed: 0.98, green: 0.62, blue: 0.24, alpha: 0.18)),
            (CGRect(x: 1040, y: 80, width: 260, height: 260), NSColor(calibratedRed: 0.28, green: 0.80, blue: 0.60, alpha: 0.16))
        ]

        for entry in circles {
            entry.color.setFill()
            NSBezierPath(ovalIn: entry.rect).fill()
        }

        let vignette = NSGradient(
            colors: [
                NSColor.clear,
                NSColor(calibratedWhite: 0, alpha: 0.18),
                NSColor(calibratedWhite: 0, alpha: 0.34)
            ]
        )
        vignette?.draw(in: bounds, angle: 90)

        return image
    }
}
