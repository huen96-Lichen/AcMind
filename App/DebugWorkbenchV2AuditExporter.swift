#if DEBUG
import AppKit
import SwiftUI

@MainActor
enum DebugWorkbenchV2AuditExporter {
    static func exportLayoutAudit(
        outputDirectory: URL,
        selectedBackgroundURL: URL
    ) throws {
        let screenshotsDirectory = outputDirectory.appendingPathComponent("screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
        print("[AcWorkV2Audit] output directory ready: \(outputDirectory.path)")

        guard FileManager.default.fileExists(atPath: selectedBackgroundURL.path) else {
            throw NSError(domain: "AcWorkWorkbenchV2Audit", code: 20, userInfo: [NSLocalizedDescriptionKey: "Missing hero background image at \(selectedBackgroundURL.path)"])
        }

        let heroBackgroundStore = WorkbenchV2HeroBackgroundStore()
        heroBackgroundStore.resetToDefaultBackground()

        let layouts: [(name: String, size: NSSize, data: WorkbenchV2DashboardData)] = [
            ("default", NSSize(width: WorkbenchV2Metrics.defaultContentWidth, height: WorkbenchV2Metrics.defaultContentHeight), .preview()),
            ("compact", NSSize(width: WorkbenchV2Metrics.minimumWindowWidth, height: WorkbenchV2Metrics.minimumWindowHeight), .compactWarning())
        ]

        var snapshots: [WorkbenchV2RuntimeLayoutSnapshot] = []
        var currentFocusSnapshots: [WorkbenchV2CurrentFocusLayoutSnapshot] = []
        var validationSummaries: [String] = []
        var currentFocusValidationSummaries: [String] = []
        var defaultCurrentFocusFrame: AuditComponentFrame?
        var pixelValidationSummaries: [String] = []

        let beforeBackgroundPath = screenshotsDirectory.appendingPathComponent("background-before-1500x888.png")
        try exportStandaloneViewScreenshot(
            beforeBackgroundPath,
            size: NSSize(width: WorkbenchV2Metrics.defaultContentWidth, height: WorkbenchV2Metrics.defaultContentHeight)
        ) {
            WorkbenchV2View(
                previewDashboardData: .preview(),
                debugOverlayEnabled: true,
                heroBackgroundStore: heroBackgroundStore
            )
        }

        try heroBackgroundStore.setBackground(from: selectedBackgroundURL)
        let afterBackgroundPath = screenshotsDirectory.appendingPathComponent("background-after-1500x888.png")
        try exportStandaloneViewScreenshot(
            afterBackgroundPath,
            size: NSSize(width: WorkbenchV2Metrics.defaultContentWidth, height: WorkbenchV2Metrics.defaultContentHeight)
        ) {
            WorkbenchV2View(
                previewDashboardData: .preview(),
                debugOverlayEnabled: true,
                heroBackgroundStore: heroBackgroundStore
            )
        }

        let fullWindowPath = screenshotsDirectory.appendingPathComponent("full-window-1500x888.png")
        try exportFullWindowScreenshot(
            fullWindowPath,
            size: NSSize(width: WorkbenchV2Metrics.defaultContentWidth, height: WorkbenchV2Metrics.defaultContentHeight),
            dashboardData: .preview()
        )

        let compactFullWindowPath = screenshotsDirectory.appendingPathComponent("full-window-1200x800.png")
        try exportFullWindowScreenshot(
            compactFullWindowPath,
            size: NSSize(width: 1200, height: 800),
            dashboardData: .runtimeCompactAudit()
        )

        for entry in layouts {
            LayoutDebugStore.shared.update([])
            let normalPath = screenshotsDirectory.appendingPathComponent("swiftui-\(Int(entry.size.width))x\(Int(entry.size.height)).png")
            let debugPath = screenshotsDirectory.appendingPathComponent("swiftui-\(Int(entry.size.width))x\(Int(entry.size.height))-debug.png")

            LayoutDebugStore.shared.update([])
            try exportStandaloneViewScreenshot(
                normalPath,
                size: entry.size
            ) {
                WorkbenchV2View(
                    previewDashboardData: entry.data,
                    debugOverlayEnabled: true,
                    heroBackgroundStore: heroBackgroundStore
                )
            }

            LayoutDebugStore.shared.update([])
            try exportStandaloneViewScreenshot(
                debugPath,
                size: entry.size,
                showLayoutDebugOverlay: true
            ) {
                WorkbenchV2View(
                    previewDashboardData: entry.data,
                    debugOverlayEnabled: true,
                    heroBackgroundStore: heroBackgroundStore
                )
            }

            let frames = LayoutDebugStore.shared.measurements.map {
                AuditComponentFrame(
                    name: $0.name,
                    x: Int($0.frame.minX),
                    y: Int($0.frame.minY),
                    width: Int($0.frame.width),
                    height: Int($0.frame.height)
                )
            }
            let validation = try validateWorkbenchV2Frames(
                layoutName: entry.name,
                frames: frames,
                contentSize: entry.size
            )
            print("[AcWorkV2Audit] validation result for \(entry.name):\n\(validation)")
            validationSummaries.append(validation)

            let currentFocusFrames = frames.filter { $0.name.hasPrefix("CurrentFocus") }
            if let cardFrame = frames.first(where: { $0.name == "CurrentFocusCard" }) {
                if entry.name == "default" {
                    defaultCurrentFocusFrame = cardFrame
                }
                let currentFocusValidation = try validateCurrentFocusFrames(
                    layoutName: entry.name,
                    cardFrame: cardFrame,
                    frames: currentFocusFrames,
                    contentSize: entry.size
                )
                print("[AcWorkV2Audit] current focus validation result for \(entry.name):\n\(currentFocusValidation)")
                currentFocusValidationSummaries.append(currentFocusValidation)
            }

            currentFocusSnapshots.append(
                WorkbenchV2CurrentFocusLayoutSnapshot(
                    name: entry.name,
                    window: AuditWindowFrame(width: Int(entry.size.width), height: Int(entry.size.height)),
                    components: currentFocusFrames
                )
            )
            snapshots.append(
                WorkbenchV2RuntimeLayoutSnapshot(
                    name: entry.name,
                    window: AuditWindowFrame(width: Int(entry.size.width), height: Int(entry.size.height)),
                    components: frames
                )
            )
        }

        let restoredStore = WorkbenchV2HeroBackgroundStore()
        let restoredBackgroundPath = screenshotsDirectory.appendingPathComponent("background-restored-1500x888.png")
        try exportStandaloneViewScreenshot(
            restoredBackgroundPath,
            size: NSSize(width: WorkbenchV2Metrics.defaultContentWidth, height: WorkbenchV2Metrics.defaultContentHeight)
        ) {
            WorkbenchV2View(
                previewDashboardData: .preview(),
                debugOverlayEnabled: true,
                heroBackgroundStore: restoredStore
            )
        }

        let persistedBackgroundPath = restoredStore.backgroundPath
        if persistedBackgroundPath.isEmpty == false {
            try? FileManager.default.removeItem(atPath: persistedBackgroundPath)
        }

        let fallbackStore = WorkbenchV2HeroBackgroundStore()
        let fallbackBackgroundPath = screenshotsDirectory.appendingPathComponent("background-fallback-1500x888.png")
        try exportStandaloneViewScreenshot(
            fallbackBackgroundPath,
            size: NSSize(width: WorkbenchV2Metrics.defaultContentWidth, height: WorkbenchV2Metrics.defaultContentHeight)
        ) {
            WorkbenchV2View(
                previewDashboardData: .preview(),
                debugOverlayEnabled: true,
                heroBackgroundStore: fallbackStore
            )
        }

        if let defaultCurrentFocusFrame {
            let pixelValidation = try validateWorkbenchV2BackgroundPixels(
                cardFrame: defaultCurrentFocusFrame,
                baselinePath: beforeBackgroundPath,
                comparisonPaths: [
                    afterBackgroundPath,
                    restoredBackgroundPath,
                    fallbackBackgroundPath
                ]
            )
            print("[AcWorkV2Audit] background pixel validation result:\n\(pixelValidation)")
            pixelValidationSummaries.append(pixelValidation)
        }

        let jsonURL = outputDirectory.appendingPathComponent("WorkbenchV17_Frames.json")
        let data = try JSONEncoder.prettyPrinted.encode(WorkbenchV2RuntimeFrames(layouts: snapshots))
        try data.write(to: jsonURL)
        print("[AcWorkV2Audit] wrote \(jsonURL.path)")

        let currentFocusJSONURL = outputDirectory.appendingPathComponent("WorkbenchV17_CurrentFocus_Frames.json")
        let currentFocusData = try JSONEncoder.prettyPrinted.encode(WorkbenchV2CurrentFocusFrames(layouts: currentFocusSnapshots))
        try currentFocusData.write(to: currentFocusJSONURL)
        print("[AcWorkV2Audit] wrote \(currentFocusJSONURL.path)")

        let validationURL = outputDirectory.appendingPathComponent("WorkbenchV17_Validation.txt")
        let validationReport = (validationSummaries + currentFocusValidationSummaries + pixelValidationSummaries).joined(separator: "\n\n")
        try validationReport.write(to: validationURL, atomically: true, encoding: .utf8)
        print("[AcWorkV2Audit] wrote \(validationURL.path)")
    }

    static func exportBackgroundVerification(
        outputDirectory: URL,
        selectedBackgroundURL: URL,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) throws {
        let screenshotsDirectory = outputDirectory.appendingPathComponent("screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: selectedBackgroundURL.path) else {
            throw NSError(domain: "AcWorkWorkbenchV2BackgroundVerification", code: 20, userInfo: [NSLocalizedDescriptionKey: "Missing hero background image at \(selectedBackgroundURL.path)"])
        }

        let stage = arguments.first(where: { $0.hasPrefix("--acwork-workbench-v2-background-stage=") })
        let stageValue = stage.flatMap { String($0.dropFirst("--acwork-workbench-v2-background-stage=".count)) } ?? "restore"

        let heroBackgroundStore = WorkbenchV2HeroBackgroundStore()
        if stageValue == "seed" {
            heroBackgroundStore.resetToDefaultBackground()
            try heroBackgroundStore.setBackground(from: selectedBackgroundURL)
        }

        let exportedName: String
        switch stageValue {
        case "seed":
            exportedName = "background-selected-1500x888.png"
        case "fallback":
            exportedName = "background-fallback-1500x888.png"
        default:
            exportedName = "background-restored-1500x888.png"
        }

        let exportPath = screenshotsDirectory.appendingPathComponent(exportedName)
        try exportStandaloneViewScreenshot(
            exportPath,
            size: NSSize(width: WorkbenchV2Metrics.defaultContentWidth, height: WorkbenchV2Metrics.defaultContentHeight)
        ) {
            WorkbenchV2View(
                previewDashboardData: .preview(),
                debugOverlayEnabled: true,
                heroBackgroundStore: heroBackgroundStore
            )
        }

        let reportURL = outputDirectory.appendingPathComponent("WorkbenchV17_BackgroundPersistence.txt")
        let persistedPath = heroBackgroundStore.backgroundPath.isEmpty ? "(empty)" : heroBackgroundStore.backgroundPath
        let fileExists = heroBackgroundStore.backgroundPath.isEmpty == false && FileManager.default.fileExists(atPath: heroBackgroundStore.backgroundPath)
        let fallbackBehavior = fileExists ? "restored selected background" : "fell back to generated default background"
        let report = [
            "[background verification]",
            "stage=\(stageValue)",
            "userDefaultsKey=WorkbenchV2.heroBackgroundPath",
            "persistedPath=\(persistedPath)",
            "fileExists=\(fileExists)",
            "fallbackBehavior=\(fallbackBehavior)",
            "selectedBackgroundSource=\(selectedBackgroundURL.path)"
        ].joined(separator: "\n")
        try report.write(to: reportURL, atomically: true, encoding: .utf8)
        print("[AcWorkV2Background] wrote \(exportPath.lastPathComponent)")
        print("[AcWorkV2Background] wrote \(reportURL.path)")
        print("[AcWorkV2Background] persistedPath=\(persistedPath)")
        print("[AcWorkV2Background] fallbackBehavior=\(fallbackBehavior)")
    }

    private static func exportStandaloneViewScreenshot<V: View>(
        _ path: URL,
        size: NSSize,
        showLayoutDebugOverlay: Bool = false,
        @ViewBuilder rootView: () -> V
    ) throws {
        try DebugScreenshotRenderer.exportView(
            path,
            size: size,
            showLayoutDebugOverlay: showLayoutDebugOverlay,
            errorDomain: "AcWorkScreenshotExport",
            logPrefix: "AcWorkV2Audit",
            rootView: rootView
        )
    }

    private static func exportFullWindowScreenshot(
        _ path: URL,
        size: NSSize,
        dashboardData: WorkbenchV2DashboardData
    ) throws {
        let auditDefaults = UserDefaults(suiteName: "AcMind.WorkbenchV2.FullWindowAudit") ?? .standard
        auditDefaults.removeObject(forKey: "WorkbenchV2.heroBackgroundPath")
        let heroBackgroundStore = WorkbenchV2HeroBackgroundStore(userDefaults: auditDefaults)
        heroBackgroundStore.resetToDefaultBackground()

        let appState = AppState.shared
        appState.sidebarCollapsed = false
        appState.sidebarSelection = .home
        let serviceContainer = ServiceContainer.preview()

        try exportStandaloneViewScreenshot(path, size: size) {
            WorkbenchV2FullWindowAuditShell(
                heroBackgroundStore: heroBackgroundStore,
                dashboardData: dashboardData
            )
            .environmentObject(appState)
            .environmentObject(serviceContainer)
        }
    }

    private static func validateWorkbenchV2Frames(
        layoutName: String,
        frames: [AuditComponentFrame],
        contentSize: NSSize
    ) throws -> String {
        let trackedOrder: [String] = [
            "WorkbenchHeader",
            "CurrentFocusCard",
            "TodayOverviewPanel",
            "PendingItemsCard",
            "RecentCollectionCard",
            "QuickActionsCard",
            "ActivityTrendCard",
            "DeviceStatusBar"
        ]
        let trackedFrames = trackedOrder.compactMap { name in
            frames.first(where: { $0.name == name })
        }
        let missingNames = trackedOrder.filter { name in frames.contains(where: { $0.name == name }) == false }
        if missingNames.isEmpty == false {
            throw NSError(
                domain: "AcWorkWorkbenchV2Audit",
                code: 9,
                userInfo: [NSLocalizedDescriptionKey: "\(layoutName): missing tracked frames: \(missingNames.joined(separator: ", "))"]
            )
        }
        let duplicates = Dictionary(grouping: trackedFrames, by: \.name).filter { $1.count > 1 }
        if duplicates.isEmpty == false {
            let duplicateList = duplicates.keys.sorted().joined(separator: ", ")
            throw NSError(
                domain: "AcWorkWorkbenchV2Audit",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "\(layoutName): duplicated tracked frames: \(duplicateList)"]
            )
        }

        func rect(for frame: AuditComponentFrame) -> CGRect {
            CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
        }

        var reportLines: [String] = ["[\(layoutName)] frame audit"]
        var violations: [String] = []

        for frame in trackedFrames {
            let frameRect = rect(for: frame)
            let boundsOk = frameRect.maxX <= contentSize.width && frameRect.maxY <= contentSize.height
            if boundsOk == false {
                violations.append("\(frame.name) exceeds bounds \(Int(contentSize.width))x\(Int(contentSize.height))")
            }
            reportLines.append(
                "\(frame.name): x=\(frame.x) y=\(frame.y) w=\(frame.width) h=\(frame.height) maxX=\(Int(frameRect.maxX)) maxY=\(Int(frameRect.maxY)) bounds=\(boundsOk ? "PASS" : "FAIL")"
            )
        }

        for lhsIndex in trackedFrames.indices {
            let lhs = trackedFrames[lhsIndex]
            let lhsRect = rect(for: lhs)
            guard lhsIndex + 1 < trackedFrames.count else { continue }
            for rhsIndex in (lhsIndex + 1)..<trackedFrames.count {
                let rhs = trackedFrames[rhsIndex]
                let rhsRect = rect(for: rhs)
                let intersection = lhsRect.intersection(rhsRect)
                let intersects = lhsRect.intersects(rhsRect)
                let pairName = "\(lhs.name) × \(rhs.name)"
                let intersectionText = intersection.isNull
                    ? "null"
                    : "x=\(Int(intersection.minX)) y=\(Int(intersection.minY)) w=\(Int(intersection.width)) h=\(Int(intersection.height))"
                reportLines.append("\(pairName): \(intersects ? "FAIL" : "PASS")")
                reportLines.append("  A: x=\(lhs.x) y=\(lhs.y) w=\(lhs.width) h=\(lhs.height)")
                reportLines.append("  B: x=\(rhs.x) y=\(rhs.y) w=\(rhs.width) h=\(rhs.height)")
                reportLines.append("  intersection: \(intersectionText)")
                if intersects {
                    violations.append("\(pairName) intersects")
                }
            }
        }

        let today = trackedFrames.first(where: { $0.name == "TodayOverviewPanel" })
        let quick = trackedFrames.first(where: { $0.name == "QuickActionsCard" })
        let trend = trackedFrames.first(where: { $0.name == "ActivityTrendCard" })
        let footer = trackedFrames.first(where: { $0.name == "DeviceStatusBar" })
        let currentFocus = trackedFrames.first(where: { $0.name == "CurrentFocusCard" })
        let pending = trackedFrames.first(where: { $0.name == "PendingItemsCard" })
        let recent = trackedFrames.first(where: { $0.name == "RecentCollectionCard" })

        if let today, let quick, rect(for: today).maxY > rect(for: quick).minY {
            violations.append("TodayOverviewPanel.maxY exceeds QuickActionsCard.minY")
        }
        if let trend, let footer, rect(for: trend).maxY > rect(for: footer).minY {
            violations.append("ActivityTrendCard.maxY exceeds DeviceStatusBar.minY")
        }

        let minimumGap = Int(WorkbenchV2Tokens.Layout.dashboardRowGap)
        let spacingChecks: [(String, AuditComponentFrame?, AuditComponentFrame?)] = [
            ("ActivityTrendCard.minY - PendingItemsCard.maxY", pending, trend),
            ("ActivityTrendCard.minY - RecentCollectionCard.maxY", recent, trend),
            ("QuickActionsCard.minY - TodayOverviewPanel.maxY", today, quick),
            ("DeviceStatusBar.minY - ActivityTrendCard.maxY", trend, footer)
        ]
        reportLines.append("[\(layoutName)] spacing audit minimum=\(minimumGap)")
        for check in spacingChecks {
            guard let upper = check.1, let lower = check.2 else {
                violations.append("\(check.0) missing frames")
                continue
            }
            let actualGap = lower.y - (upper.y + upper.height)
            let passes = actualGap >= minimumGap
            reportLines.append("\(check.0): \(actualGap) \(passes ? "PASS" : "FAIL")")
            if passes == false {
                violations.append("\(check.0) is \(actualGap), expected >= \(minimumGap)")
            }
        }

        let exactGap = Int(WorkbenchV2Tokens.Layout.dashboardRowGap)
        let gridGapChecks: [(String, AuditComponentFrame?, AuditComponentFrame?, (AuditComponentFrame, AuditComponentFrame) -> Int)] = [
            ("CurrentFocusCard.right -> TodayOverviewPanel.left", currentFocus, today, { left, right in right.x - (left.x + left.width) }),
            ("PendingItemsCard.right -> RecentCollectionCard.left", pending, recent, { left, right in right.x - (left.x + left.width) }),
            ("CurrentFocusCard.bottom -> PendingItemsCard.top", currentFocus, pending, { upper, lower in lower.y - (upper.y + upper.height) }),
            ("CurrentFocusCard.bottom -> RecentCollectionCard.top", currentFocus, recent, { upper, lower in lower.y - (upper.y + upper.height) }),
            ("PendingItemsCard.bottom -> ActivityTrendCard.top", pending, trend, { upper, lower in lower.y - (upper.y + upper.height) }),
            ("RecentCollectionCard.bottom -> ActivityTrendCard.top", recent, trend, { upper, lower in lower.y - (upper.y + upper.height) }),
            ("TodayOverviewPanel.bottom -> QuickActionsCard.top", today, quick, { upper, lower in lower.y - (upper.y + upper.height) })
        ]
        reportLines.append("[\(layoutName)] six-card grid gutter audit expected=\(exactGap)")
        for check in gridGapChecks {
            guard let first = check.1, let second = check.2 else {
                violations.append("\(check.0) missing frames")
                continue
            }
            let actualGap = check.3(first, second)
            let passes = actualGap == exactGap
            reportLines.append("\(check.0): \(actualGap) \(passes ? "PASS" : "FAIL")")
            if passes == false {
                violations.append("\(check.0) is \(actualGap), expected \(exactGap)")
            }
        }

        let gridAlignmentChecks: [(String, Bool)] = [
            (
                "CurrentFocusCard.y == TodayOverviewPanel.y",
                currentFocus.flatMap { focus in today.map { focus.y == $0.y } } ?? false
            ),
            (
                "PendingItemsCard.y == RecentCollectionCard.y",
                pending.flatMap { pending in recent.map { pending.y == $0.y } } ?? false
            ),
            (
                "PendingItemsCard.maxY == RecentCollectionCard.maxY",
                pending.flatMap { pending in recent.map { pending.y + pending.height == $0.y + $0.height } } ?? false
            )
        ]
        reportLines.append("[\(layoutName)] six-card grid alignment audit")
        for check in gridAlignmentChecks {
            reportLines.append("\(check.0): \(check.1 ? "PASS" : "FAIL")")
            if check.1 == false {
                violations.append("\(check.0) failed")
            }
        }

        if violations.isEmpty == false {
            throw NSError(
                domain: "AcWorkWorkbenchV2Audit",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "\(layoutName): " + violations.joined(separator: "; ")]
            )
        }

        let footerCheck = footer.map { $0.y + $0.height <= Int(contentSize.height) } ?? true
        if footerCheck == false {
            throw NSError(
                domain: "AcWorkWorkbenchV2Audit",
                code: 12,
                userInfo: [NSLocalizedDescriptionKey: "\(layoutName): DeviceStatusBar.maxY exceeds content height"]
            )
        }

        return reportLines.joined(separator: "\n")
    }

    private static func validateCurrentFocusFrames(
        layoutName: String,
        cardFrame: AuditComponentFrame,
        frames: [AuditComponentFrame],
        contentSize: NSSize
    ) throws -> String {
        let trackedOrder = [
            "CurrentFocusBackground",
            "CurrentFocusContent",
            "CurrentFocusMetrics",
            "CurrentFocusActions"
        ]
        let cardRect = CGRect(x: cardFrame.x, y: cardFrame.y, width: cardFrame.width, height: cardFrame.height)
        let namedFrames = trackedOrder.compactMap { name in
            frames.first(where: { $0.name == name })
        }

        if namedFrames.count != trackedOrder.count {
            let missing = trackedOrder.filter { name in frames.contains(where: { $0.name == name }) == false }
            throw NSError(
                domain: "AcWorkWorkbenchV2Audit",
                code: 21,
                userInfo: [NSLocalizedDescriptionKey: "\(layoutName): missing current focus frames: \(missing.joined(separator: ", "))"]
            )
        }

        var reportLines: [String] = ["[\(layoutName)] current focus internal audit"]
        var violations: [String] = []

        for frame in namedFrames {
            let rect = CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height)
            let boundsOk = rect.minX >= cardRect.minX
                && rect.maxX <= cardRect.maxX
                && rect.minY >= cardRect.minY
                && rect.maxY <= cardRect.maxY
                && rect.maxX <= contentSize.width
                && rect.maxY <= contentSize.height
            reportLines.append(
                "\(frame.name): x=\(frame.x) y=\(frame.y) w=\(frame.width) h=\(frame.height) maxX=\(Int(rect.maxX)) maxY=\(Int(rect.maxY)) bounds=\(boundsOk ? "PASS" : "FAIL")"
            )
            if boundsOk == false {
                violations.append("\(frame.name) exceeds CurrentFocusCard bounds")
            }
        }

        if let actions = namedFrames.first(where: { $0.name == "CurrentFocusActions" }) {
            let actionsRect = CGRect(x: actions.x, y: actions.y, width: actions.width, height: actions.height)
            if actionsRect.maxY > cardRect.maxY - 1 {
                violations.append("CurrentFocusActions.maxY exceeds CurrentFocusCard.maxY")
            }
        }

        if let background = namedFrames.first(where: { $0.name == "CurrentFocusBackground" }) {
            let backgroundRect = CGRect(x: background.x, y: background.y, width: background.width, height: background.height)
            if backgroundRect.minX < cardRect.minX
                || backgroundRect.minY < cardRect.minY
                || backgroundRect.maxX > cardRect.maxX
                || backgroundRect.maxY > cardRect.maxY {
                violations.append("CurrentFocusBackground exceeds CurrentFocusCard bounds")
            }
        }

        if violations.isEmpty == false {
            throw NSError(
                domain: "AcWorkWorkbenchV2Audit",
                code: 22,
                userInfo: [NSLocalizedDescriptionKey: "\(layoutName): " + violations.joined(separator: "; ")]
            )
        }

        return reportLines.joined(separator: "\n")
    }

    private static func validateWorkbenchV2BackgroundPixels(
        cardFrame: AuditComponentFrame,
        baselinePath: URL,
        comparisonPaths: [URL]
    ) throws -> String {
        let cardRect = CGRect(
            x: cardFrame.x,
            y: cardFrame.y,
            width: cardFrame.width,
            height: cardFrame.height
        )
        guard let baselineBitmap = bitmapImageRep(from: baselinePath) else {
            throw NSError(
                domain: "AcWorkWorkbenchV2Audit",
                code: 30,
                userInfo: [NSLocalizedDescriptionKey: "Unable to read baseline screenshot \(baselinePath.path)"]
            )
        }

        var reportLines: [String] = ["[background] pixel audit"]
        reportLines.append("CurrentFocusCard: x=\(cardFrame.x) y=\(cardFrame.y) w=\(cardFrame.width) h=\(cardFrame.height)")

        for path in comparisonPaths {
            guard let comparisonBitmap = bitmapImageRep(from: path) else {
                throw NSError(
                    domain: "AcWorkWorkbenchV2Audit",
                    code: 31,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to read comparison screenshot \(path.path)"]
                )
            }

            let result = comparePixelsOutsideCard(
                baseline: baselineBitmap,
                comparison: comparisonBitmap,
                cardRect: cardRect
            )
            let status = result.changedPixels == 0 ? "PASS" : "FAIL"
            reportLines.append("\(path.lastPathComponent): \(status) outsideChangedPixels=\(result.changedPixels) sampledPixels=\(result.sampledPixels)")
        }

        return reportLines.joined(separator: "\n")
    }

    private static func bitmapImageRep(from path: URL) -> NSBitmapImageRep? {
        guard let image = NSImage(contentsOf: path),
              let tiffData = image.tiffRepresentation else {
            return nil
        }
        return NSBitmapImageRep(data: tiffData)
    }

    private static func comparePixelsOutsideCard(
        baseline: NSBitmapImageRep,
        comparison: NSBitmapImageRep,
        cardRect: CGRect
    ) -> (changedPixels: Int, sampledPixels: Int) {
        let width = min(baseline.pixelsWide, comparison.pixelsWide)
        let height = min(baseline.pixelsHigh, comparison.pixelsHigh)
        let scaleX = CGFloat(width) / CGFloat(WorkbenchV2Metrics.defaultContentWidth)
        let scaleY = CGFloat(height) / CGFloat(WorkbenchV2Metrics.defaultContentHeight)
        let pixelCardRect = CGRect(
            x: cardRect.minX * scaleX,
            y: cardRect.minY * scaleY,
            width: cardRect.width * scaleX,
            height: cardRect.height * scaleY
        ).insetBy(dx: -24, dy: -24)

        var changedPixels = 0
        var sampledPixels = 0
        for y in 0..<height {
            for x in 0..<width {
                if pixelCardRect.contains(CGPoint(x: x, y: y)) {
                    continue
                }

                sampledPixels += 1
                guard let baselineColor = baseline.colorAt(x: x, y: y),
                      let comparisonColor = comparison.colorAt(x: x, y: y) else {
                    continue
                }

                let delta = abs(baselineColor.redComponent - comparisonColor.redComponent)
                    + abs(baselineColor.greenComponent - comparisonColor.greenComponent)
                    + abs(baselineColor.blueComponent - comparisonColor.blueComponent)
                    + abs(baselineColor.alphaComponent - comparisonColor.alphaComponent)
                if delta > 0.1 {
                    changedPixels += 1
                }
            }
        }

        return (changedPixels, sampledPixels)
    }
}

private struct WorkbenchV2FullWindowAuditShell: View {
    @ObservedObject var heroBackgroundStore: WorkbenchV2HeroBackgroundStore
    let dashboardData: WorkbenchV2DashboardData

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: AppSurfaceTokens.Layout.sidebarWidth, alignment: .topLeading)

            WorkbenchV2View(
                previewDashboardData: dashboardData,
                debugOverlayEnabled: false,
                heroBackgroundStore: heroBackgroundStore
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(AppSurfaceBackdrop())
    }
}
#endif
