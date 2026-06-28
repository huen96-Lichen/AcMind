#if DEBUG
import AppKit
import SwiftUI

@MainActor
enum DebugScreenshotRenderer {
    static func exportHostingView(
        _ hostingView: NSView,
        to path: URL,
        errorDomain: String,
        logPrefix: String
    ) throws {
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw NSError(
                domain: errorDomain,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap representation"]
            )
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(
                domain: errorDomain,
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG representation"]
            )
        }
        try data.write(to: path)
        print("[\(logPrefix)] wrote \(path.lastPathComponent)")
    }

    static func renderImage(
        from hostingView: NSView,
        errorDomain: String = "DebugScreenshotExport"
    ) throws -> NSImage {
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw NSError(
                domain: errorDomain,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap representation"]
            )
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
        let image = NSImage(size: hostingView.bounds.size)
        image.addRepresentation(rep)
        return image
    }

    static func writeImage(
        _ image: NSImage,
        to url: URL,
        errorDomain: String = "DebugScreenshotExport"
    ) throws {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(
                domain: errorDomain,
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"]
            )
        }
        try data.write(to: url)
    }

    static func exportView<V: View>(
        _ path: URL,
        size: NSSize,
        colorScheme: ColorScheme = .light,
        showLayoutDebugOverlay: Bool = false,
        errorDomain: String = "DebugScreenshotExport",
        logPrefix: String,
        @ViewBuilder rootView: () -> V
    ) throws {
        LayoutDebugStore.shared.isOverlayVisible = showLayoutDebugOverlay
        defer { LayoutDebugStore.shared.isOverlayVisible = false }

        let hostingView = NSHostingView(rootView: AnyView(rootView().preferredColorScheme(colorScheme)))
        hostingView.frame = NSRect(origin: .zero, size: size)
        try exportHostingView(
            hostingView,
            to: path,
            errorDomain: errorDomain,
            logPrefix: logPrefix
        )
    }
}
#endif
