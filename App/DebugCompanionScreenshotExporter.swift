#if DEBUG
import AppKit
import AcMindKit
import SwiftUI

@MainActor
enum DebugCompanionScreenshotExporter {
    static func exportSixPageScreenshots(
        outputDirectory: URL,
        serviceContainer: ServiceContainer
    ) throws {
        print("[CompanionExport] output directory ready: \(outputDirectory.path)")

        let specs: [CompanionScreenshotSpec] = [
            .init(page: .overview, fileName: "companion-local-880x300.png", title: "本机"),
            .init(page: .launcher, fileName: "companion-launcher-880x300.png", title: "启动器"),
            .init(page: .music, fileName: "companion-music-880x300.png", title: "音乐"),
            .init(page: .agent, fileName: "companion-ai-880x300.png", title: "智能体"),
            .init(page: .systemStatus, fileName: "companion-status-880x300.png", title: "状态"),
            .init(page: .settings, fileName: "companion-settings-880x300.png", title: "设置")
        ]

        var exportedImages: [(title: String, image: NSImage)] = []

        for spec in specs {
            let image = try renderCompanionScreenshot(
                page: spec.page,
                serviceContainer: serviceContainer
            )
            let outputURL = outputDirectory.appendingPathComponent(spec.fileName)
            try DebugScreenshotRenderer.writeImage(image, to: outputURL, errorDomain: "CompanionExport")
            exportedImages.append((title: spec.title, image: image))
            print("[CompanionExport] wrote \(outputURL.lastPathComponent)")
        }

        let contactSheetURL = outputDirectory.appendingPathComponent("companion-six-pages-contact-sheet.png")
        let sheet = try composeContactSheet(images: exportedImages)
        try DebugScreenshotRenderer.writeImage(sheet, to: contactSheetURL, errorDomain: "CompanionExport")
        print("[CompanionExport] wrote \(contactSheetURL.lastPathComponent)")
    }

    private static func renderCompanionScreenshot(
        page: NotchV2Page,
        serviceContainer: ServiceContainer
    ) throws -> NSImage {
        let panelController = CompanionScreenshotPanelController()
        let viewModel = NotchV2ViewModel(
            panelController: panelController,
            batteryService: serviceContainer.batteryService,
            systemStatusService: serviceContainer.systemStatusService,
            systemEventCenter: serviceContainer.systemEventCenter,
            musicService: serviceContainer.musicService
        )
        viewModel.updateDisplaySettings { settings in
            settings.enabledDynamicModules = Set(DynamicContinentModuleID.allCases)
            settings.dynamicModuleOrder = DynamicContinentModuleID.allCases
            settings.overviewVisibleModules = Set(DynamicContinentModuleID.allCases)
            settings.collapsedVisibleContents = Set(CompanionRuntimeContentID.allCases)
            settings.collapsedVisibleContentOrder = CompanionRuntimeContentID.allCases
            settings.primarySurfaceContents = Set(CompanionRuntimeContentID.allCases)
            settings.primarySurfaceContentOrder = CompanionRuntimeContentID.allCases
            settings.enabledSystemEventKinds = Set(SystemEventKind.allCases)
        }
        viewModel.selectedPage = page
        viewModel.presentationState = .expanded
        viewModel.isExpanded = true

        let rootView = NotchV2RootView(viewModel: viewModel)
            .environmentObject(serviceContainer)
            .preferredColorScheme(.dark)
            .frame(
                width: CompanionLayoutTokens.expandedWindowWidth,
                height: CompanionLayoutTokens.expandedWindowHeight,
                alignment: .topLeading
            )

        let hostingView = NSHostingView(rootView: AnyView(rootView))
        hostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(width: CompanionLayoutTokens.expandedWindowWidth, height: CompanionLayoutTokens.expandedWindowHeight)
        )
        return try DebugScreenshotRenderer.renderImage(from: hostingView, errorDomain: "CompanionExport")
    }

    private static func composeContactSheet(images: [(title: String, image: NSImage)]) throws -> NSImage {
        let columns = 3
        let rows = 2
        let tileWidth: CGFloat = CompanionLayoutTokens.expandedWindowWidth
        let tileHeight: CGFloat = CompanionLayoutTokens.expandedWindowHeight
        let titleBandHeight: CGFloat = 24
        let padding: CGFloat = 16
        let gutter: CGFloat = 14
        let sheetWidth = padding * 2 + CGFloat(columns) * tileWidth + CGFloat(columns - 1) * gutter
        let sheetHeight = padding * 2 + CGFloat(rows) * (tileHeight + titleBandHeight) + CGFloat(rows - 1) * gutter
        let canvas = NSImage(size: NSSize(width: sheetWidth, height: sheetHeight))

        canvas.lockFocus()
        defer { canvas.unlockFocus() }

        NSColor(red: 0.03, green: 0.03, blue: 0.035, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight)).fill()

        let titleFont = NSFont.systemFont(ofSize: 16, weight: .semibold)
        let labelFont = NSFont.systemFont(ofSize: 11, weight: .medium)
        let labelColor = NSColor.white.withAlphaComponent(0.88)

        for (index, item) in images.enumerated() {
            let column = index % columns
            let row = index / columns
            let x = padding + CGFloat(column) * (tileWidth + gutter)
            let y = sheetHeight - padding - CGFloat(row + 1) * (tileHeight + titleBandHeight) - CGFloat(row) * gutter

            let labelRect = NSRect(x: x, y: y + tileHeight + 4, width: tileWidth, height: 18)
            let labelStyle = NSMutableParagraphStyle()
            labelStyle.alignment = .left
            let attributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: labelColor,
                .paragraphStyle: labelStyle
            ]
            item.title.draw(in: labelRect, withAttributes: attributes)

            let imageRect = NSRect(x: x, y: y, width: tileWidth, height: tileHeight)
            item.image.draw(in: imageRect)

            let captionRect = NSRect(x: x, y: y + tileHeight - 18, width: tileWidth, height: 16)
            let captionAttributes: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: NSColor.white.withAlphaComponent(0.6)
            ]
            "880 × 300".draw(in: captionRect, withAttributes: captionAttributes)
        }

        return canvas
    }

    private struct CompanionScreenshotSpec {
        let page: NotchV2Page
        let fileName: String
        let title: String
    }

    @MainActor
    private final class CompanionScreenshotPanelController: NotchPanelControlling {
        func hide() {}
        func showCompact(on screen: NSScreen?) {}
    }
}
#endif
