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
        if let bundledImage = NSImage(named: "WorkbenchHeroOcean") {
            return bundledImage
        }

        let size = NSSize(width: 1600, height: 900)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let bounds = NSRect(origin: .zero, size: size)
        let skyGradient = NSGradient(
            colors: [
                NSColor(calibratedRed: 0.64, green: 0.76, blue: 0.82, alpha: 1),
                NSColor(calibratedRed: 0.28, green: 0.45, blue: 0.54, alpha: 1),
                NSColor(calibratedRed: 0.06, green: 0.15, blue: 0.23, alpha: 1)
            ]
        )
        skyGradient?.draw(in: bounds, angle: 90)

        let mountainPath = NSBezierPath()
        mountainPath.move(to: NSPoint(x: 0, y: 520))
        mountainPath.curve(to: NSPoint(x: 420, y: 560), controlPoint1: NSPoint(x: 120, y: 570), controlPoint2: NSPoint(x: 250, y: 500))
        mountainPath.curve(to: NSPoint(x: 780, y: 545), controlPoint1: NSPoint(x: 560, y: 610), controlPoint2: NSPoint(x: 650, y: 510))
        mountainPath.curve(to: NSPoint(x: 1160, y: 590), controlPoint1: NSPoint(x: 900, y: 580), controlPoint2: NSPoint(x: 1000, y: 535))
        mountainPath.curve(to: NSPoint(x: 1600, y: 548), controlPoint1: NSPoint(x: 1340, y: 665), controlPoint2: NSPoint(x: 1460, y: 500))
        mountainPath.line(to: NSPoint(x: 1600, y: 900))
        mountainPath.line(to: NSPoint(x: 0, y: 900))
        mountainPath.close()
        NSColor(calibratedRed: 0.06, green: 0.12, blue: 0.17, alpha: 0.50).setFill()
        mountainPath.fill()

        let seaRect = NSRect(x: 0, y: 0, width: size.width, height: 560)
        let seaGradient = NSGradient(
            colors: [
                NSColor(calibratedRed: 0.04, green: 0.16, blue: 0.22, alpha: 1),
                NSColor(calibratedRed: 0.07, green: 0.36, blue: 0.44, alpha: 1),
                NSColor(calibratedRed: 0.28, green: 0.57, blue: 0.62, alpha: 1)
            ]
        )
        seaGradient?.draw(in: seaRect, angle: 90)

        for index in 0..<18 {
            let y = CGFloat(60 + index * 28)
            let path = NSBezierPath()
            path.lineWidth = index < 6 ? 3.2 : 1.7
            path.move(to: NSPoint(x: -40, y: y))
            for step in 0...8 {
                let x = CGFloat(step) * 220
                let crest = y + CGFloat((step + index).isMultiple(of: 2) ? 12 : -10)
                path.curve(
                    to: NSPoint(x: x + 220, y: y + CGFloat(step.isMultiple(of: 2) ? -7 : 8)),
                    controlPoint1: NSPoint(x: x + 70, y: crest),
                    controlPoint2: NSPoint(x: x + 150, y: y - (crest - y))
                )
            }
            NSColor(calibratedWhite: 1, alpha: index < 7 ? 0.26 : 0.15).setStroke()
            path.stroke()
        }

        for index in 0..<6 {
            let y = CGFloat(120 + index * 58)
            let foam = NSBezierPath()
            foam.lineWidth = 4.0
            foam.move(to: NSPoint(x: -80, y: y))
            for step in 0...6 {
                let x = CGFloat(step) * 280
                foam.curve(
                    to: NSPoint(x: x + 280, y: y + CGFloat(step.isMultiple(of: 2) ? 10 : -8)),
                    controlPoint1: NSPoint(x: x + 80, y: y + 20),
                    controlPoint2: NSPoint(x: x + 190, y: y - 22)
                )
            }
            NSColor(calibratedWhite: 1, alpha: 0.10).setStroke()
            foam.stroke()
        }

        let vignette = NSGradient(
            colors: [
                NSColor.clear,
                NSColor(calibratedWhite: 0, alpha: 0.16),
                NSColor(calibratedWhite: 0, alpha: 0.36)
            ]
        )
        vignette?.draw(in: bounds, angle: 90)

        return image
    }
}
