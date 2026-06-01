import Foundation
import AppKit
import Vision

public final class ScrollCaptureService: @unchecked Sendable {
    
    public static let shared = ScrollCaptureService()
    
    private let captureQueue = DispatchQueue(label: "com.acmind.scrollcapture", qos: .userInitiated)
    
    public struct CaptureConfig {
        public var autoScrollEnabled: Bool = true
        public var autoScrollSpeed: Int = 3
        public var maxScrollHeight: Int = 30000
        public var frozenDetectionEnabled: Bool = true
        
        public init() {}
    }
    
    public struct CaptureState {
        public var stripCount: Int = 0
        public var stitchedImage: CGImage?
        public var estimatedTotalHeight: CGFloat = 0
        public var isActive: Bool = false
        public var frozenTopHeight: CGFloat = 0
    }
    
    public var onStripAdded: ((Int) -> Void)?
    public var onSessionDone: ((NSImage?) -> Void)?
    public var onPreviewUpdated: ((NSImage) -> Void)?
    
    private var config: CaptureConfig = CaptureConfig()
    private var state: CaptureState = CaptureState()
    private var isCapturing: Bool = false
    
    private var mergedImage: CGImage?
    private var shotA: CGImage?
    private var headerHeight: Int = 0
    private var headerDetectionDone: Bool = false
    private var matchNotFoundCount: Int = 0
    private var hasScrolledOnce: Bool = false
    private var consecutiveZeroShifts: Int = 0
    private var backingScale: CGFloat = 1.0
    private var captureDisplayID: CGDirectDisplayID?
    
    private var autoScrollTask: Task<Void, Never>?
    
    public func setConfig(_ config: CaptureConfig) {
        self.config = config
    }
    
    public func startCapture(captureRect: NSRect, screen: NSScreen) async {
        guard !state.isActive else { return }
        
        backingScale = screen.backingScaleFactor
        captureDisplayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        
        guard let firstFrame = await captureSettledFrame(captureRect: captureRect) else {
            onSessionDone?(nil)
            return
        }
        
        state.isActive = true
        state.stripCount = 1
        mergedImage = firstFrame
        state.stitchedImage = firstFrame
        shotA = nil
        headerHeight = 0
        headerDetectionDone = false
        matchNotFoundCount = 0
        hasScrolledOnce = false
        consecutiveZeroShifts = 0
        
        emitPreview()
        onStripAdded?(state.stripCount)
        
        if config.autoScrollEnabled {
            startAutoScroll(captureRect: captureRect, screen: screen)
        }
    }
    
    public func stopCapture() {
        guard state.isActive else { return }
        state.isActive = false
        
        autoScrollTask?.cancel()
        autoScrollTask = nil
        
        let finalImage: NSImage?
        if let cg = mergedImage {
            let ptSize = CGSize(
                width: CGFloat(cg.width) / backingScale,
                height: CGFloat(cg.height) / backingScale
            )
            finalImage = NSImage(cgImage: cg, size: ptSize)
        } else {
            finalImage = nil
        }
        
        onSessionDone?(finalImage)
    }
    
    public func cancelCapture() {
        guard state.isActive else { return }
        state.isActive = false
        
        autoScrollTask?.cancel()
        autoScrollTask = nil
        
        mergedImage = nil
        shotA = nil
    }
    
    public func getState() -> CaptureState {
        return state
    }
    
    private func startAutoScroll(captureRect: NSRect, screen: NSScreen) {
        let linesPerTick: Int32
        let burstCount: Int
        
        switch config.autoScrollSpeed {
        case 1:
            linesPerTick = 1
            burstCount = 1
        case 2:
            linesPerTick = 1
            burstCount = 2
        case 4:
            linesPerTick = 2
            burstCount = 4
        default:
            linesPerTick = 1
            burstCount = 3
        }
        
        autoScrollTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self = self, self.state.isActive else { return }
            await self.autoScrollLoop(linesPerTick: linesPerTick, burstCount: burstCount, captureRect: captureRect)
        }
    }
    
    private func autoScrollLoop(linesPerTick: Int32, burstCount: Int, captureRect: NSRect) async {
        while state.isActive {
            for _ in 0..<burstCount {
                if let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1,
                                        wheel1: -linesPerTick, wheel2: 0, wheel3: 0) {
                    event.post(tap: .cghidEventTap)
                }
            }
            
            let success = await captureAndCompare(captureRect: captureRect)
            
            if !success {
                matchNotFoundCount += 1
                if matchNotFoundCount >= 8 {
                    stopCapture()
                    return
                }
            } else {
                matchNotFoundCount = 0
            }
            
            if let merged = mergedImage, config.maxScrollHeight > 0 {
                if merged.height >= config.maxScrollHeight {
                    stopCapture()
                    return
                }
            }
            
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
    
    private func captureAndCompare(captureRect: NSRect) async -> Bool {
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        var previousTIFF: Data? = nil
        var settledCG: CGImage? = nil
        var waitNs: UInt64 = 12_000_000
        
        for _ in 0..<30 {
            guard state.isActive else { return false }
            
            guard let cg = captureFrame(captureRect: captureRect) else {
                try? await Task.sleep(nanoseconds: 30_000_000)
                continue
            }
            
            let tiffData: Data? = await withCheckedContinuation { cont in
                captureQueue.async {
                    let bitmapRep = NSBitmapImageRep(cgImage: cg)
                    cont.resume(returning: bitmapRep.tiffRepresentation)
                }
            }
            
            guard let currentTIFF = tiffData else {
                try? await Task.sleep(nanoseconds: waitNs)
                waitNs = min(waitNs * 3 / 2, 80_000_000)
                continue
            }
            
            if let prevTIFF = previousTIFF, currentTIFF == prevTIFF {
                settledCG = cg
                break
            }
            
            previousTIFF = currentTIFF
            try? await Task.sleep(nanoseconds: waitNs)
            waitNs = min(waitNs * 3 / 2, 80_000_000)
        }
        
        guard let currentFrame = settledCG else { return false }
        guard let previousFrame = shotA ?? mergedImage?.cropping(to: CGRect(x: 0, y: 0, width: currentFrame.width, height: currentFrame.height)) else {
            shotA = currentFrame
            return false
        }
        
        guard let offset = computeVisionShift(current: currentFrame, previous: previousFrame) else {
            shotA = currentFrame
            consecutiveZeroShifts += 1
            if hasScrolledOnce && consecutiveZeroShifts >= 6 {
                stopCapture()
            }
            return false
        }
        
        let offsetPx = Int(round(offset))
        guard offsetPx > 0 else {
            shotA = currentFrame
            return false
        }
        
        let minShift = currentFrame.height / 10
        if offsetPx < minShift {
            return false
        }
        
        consecutiveZeroShifts = 0
        hasScrolledOnce = true
        
        if config.frozenDetectionEnabled && !headerDetectionDone {
            detectHeader(current: currentFrame, previous: previousFrame, shiftPx: offsetPx)
        }
        
        let safeOffset = max(1, offsetPx - 1)
        mergeNewContent(currentFrame: currentFrame, offsetPx: safeOffset)
        
        shotA = currentFrame
        state.stripCount += 1
        
        emitPreview()
        onStripAdded?(state.stripCount)
        
        return true
    }
    
    private func captureFrame(captureRect: NSRect) -> CGImage? {
        guard let displayID = captureDisplayID else {
            return nil
        }

        let primaryScreenH = NSScreen.screens.first?.frame.height ?? 0
        let cgRect = CGRect(
            x: captureRect.origin.x,
            y: primaryScreenH - captureRect.maxY,
            width: captureRect.width,
            height: captureRect.height
        )

        return CGDisplayCreateImage(displayID, rect: cgRect)
    }
    
    private func captureSettledFrame(captureRect: NSRect) async -> CGImage? {
        var previousTIFF: Data? = nil
        var previousCG: CGImage? = nil
        var waitNs: UInt64 = 10_000_000
        
        for _ in 0..<30 {
            guard let cg = captureFrame(captureRect: captureRect) else {
                try? await Task.sleep(nanoseconds: 30_000_000)
                continue
            }
            
            let tiffData: Data? = await withCheckedContinuation { cont in
                captureQueue.async {
                    let bitmapRep = NSBitmapImageRep(cgImage: cg)
                    cont.resume(returning: bitmapRep.tiffRepresentation)
                }
            }
            
            guard let currentTIFF = tiffData else {
                try? await Task.sleep(nanoseconds: waitNs)
                waitNs = min(waitNs * 3 / 2, 80_000_000)
                continue
            }
            
            if let prevTIFF = previousTIFF, currentTIFF == prevTIFF {
                return cg
            }
            
            previousTIFF = currentTIFF
            previousCG = cg
            try? await Task.sleep(nanoseconds: waitNs)
            waitNs = min(waitNs * 3 / 2, 80_000_000)
        }
        
        return previousCG
    }
    
    private func computeVisionShift(current: CGImage, previous: CGImage) -> CGFloat? {
        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: previous)
        let handler = VNImageRequestHandler(cgImage: current, options: [:])
        
        guard (try? handler.perform([request])) != nil,
              let obs = request.results?.first as? VNImageTranslationAlignmentObservation else {
            return nil
        }
        
        return obs.alignmentTransform.ty
    }
    
    private func detectHeader(current: CGImage, previous: CGImage, shiftPx: Int) {
        guard current.width == previous.width, current.height == previous.height, shiftPx > 5 else {
            headerDetectionDone = true
            return
        }
        
        headerDetectionDone = true
    }
    
    private func mergeNewContent(currentFrame: CGImage, offsetPx: Int) {
        guard let existing = mergedImage else {
            mergedImage = currentFrame
            return
        }
        
        let w = currentFrame.width
        let existingH = existing.height
        let newRows = offsetPx
        guard newRows > 0, newRows <= currentFrame.height else { return }
        
        let totalH = existingH + newRows
        
        let cs = existing.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: totalH,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: cs,
            bitmapInfo: bitmapInfo
        ) else { return }
        
        ctx.draw(existing, in: CGRect(x: 0, y: newRows, width: w, height: existingH))
        
        if headerDetectionDone && headerHeight > 0 {
            let stripY = currentFrame.height - newRows
            if let strip = currentFrame.cropping(to: CGRect(x: 0, y: stripY, width: w, height: newRows)) {
                ctx.draw(strip, in: CGRect(x: 0, y: 0, width: w, height: newRows))
            }
        } else {
            ctx.draw(currentFrame, in: CGRect(x: 0, y: 0, width: w, height: currentFrame.height))
        }
        
        guard let merged = ctx.makeImage() else { return }
        mergedImage = merged
        state.stitchedImage = merged
        state.estimatedTotalHeight = CGFloat(totalH) / backingScale
    }
    
    private func emitPreview() {
        guard let cg = mergedImage, let callback = onPreviewUpdated else { return }
        let ptSize = CGSize(
            width: CGFloat(cg.width) / backingScale,
            height: CGFloat(cg.height) / backingScale
        )
        callback(NSImage(cgImage: cg, size: ptSize))
    }
}

public enum ScrollCaptureError: Error, LocalizedError {
    case permissionDenied
    case captureFailed(String)
    case scrollDetectionFailed
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "需要屏幕录制权限"
        case .captureFailed(let message):
            return "截图失败: \(message)"
        case .scrollDetectionFailed:
            return "滚动检测失败"
        }
    }
}
