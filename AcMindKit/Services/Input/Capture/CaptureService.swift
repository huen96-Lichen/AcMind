import Foundation
import CoreGraphics
import AppKit
import ScreenCaptureKit

// MARK: - Capture Service

/// 统一采集服务
/// 职责：
/// 1. 截图（全屏/区域/窗口）
/// 2. 文件导入
/// 3. 网页采集
/// 4. 手动文本输入
/// 5. 剪贴板图片/文本
/// 6. 语音输入（占位）
/// 7. OCR 文本提取
public final class CaptureService: CaptureServiceProtocol {
    
    // MARK: - Dependencies
    
    private let storage: StorageServiceProtocol
    private let assetStore: AssetStore
    
    // MARK: - Initialization
    
    public init(
        storage: StorageServiceProtocol? = nil,
        assetStore: AssetStore? = nil
    ) {
        self.storage = storage ?? StorageService()
        self.assetStore = assetStore ?? AssetStore()
    }
    
    // MARK: - Screenshot Capture
    
    public func captureScreenshot(mode: ScreenshotMode) async throws -> CaptureResult {
        // 请求屏幕录制权限
        let hasPermission = await requestScreenCapturePermission()
        guard hasPermission else {
            throw CaptureError.permissionDenied
        }
        
        let image: NSImage
        switch mode {
        case .fullscreen:
            image = try await captureFullscreen()
        case .area:
            image = try await captureArea()
        case .window:
            image = try await captureWindow()
        }
        
        // 保存图片到 AssetStore
        let assetFile = try await assetStore.saveImage(
            image,
            fileName: "screenshot_\(Date().timeIntervalSince1970).png"
        )
        
        // 创建 SourceItem
        let sourceItem = SourceItem(
            type: .screenshot,
            source: .screenshot,
            status: .captured,
            title: "截图 \(formatDate())",
            previewText: "截图 \(formatDate())",
            assetFileIds: [assetFile.id]
        )
        
        try await storage.insertSourceItem(sourceItem)
        
        // 尝试 OCR
        Task {
            if let ocrText = try? await performOCR(imageURL: URL(fileURLWithPath: assetFile.filePath)) {
                var updatedItem = sourceItem
                updatedItem.ocrText = ocrText
                updatedItem.previewText = ocrText.prefix(200).description
                try? await storage.updateSourceItem(updatedItem)
            }
        }
        
        return CaptureResult(sourceItem: sourceItem, assetFiles: [assetFile])
    }
    
    private func captureFullscreen() async throws -> NSImage {
        return try await MainActor.run {
            guard let displayID = CGMainDisplayID() as CGDirectDisplayID? else {
                throw CaptureError.captureFailed("无法获取主显示器")
            }
            
            guard let cgImage = CGDisplayCreateImage(displayID) else {
                throw CaptureError.captureFailed("无法创建屏幕图像")
            }
            
            return NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )
        }
    }
    
    private func captureArea() async throws -> NSImage {
        // 使用系统截图工具的 area 模式
        // 实际实现需要调用 screencapture 命令或自定义选择框
        return try await MainActor.run {
            // 临时实现：使用全屏截图
            guard let displayID = CGMainDisplayID() as CGDirectDisplayID? else {
                throw CaptureError.captureFailed("无法获取主显示器")
            }
            
            guard let cgImage = CGDisplayCreateImage(displayID) else {
                throw CaptureError.captureFailed("无法创建屏幕图像")
            }
            
            return NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )
        }
    }
    
    private func captureWindow() async throws -> NSImage {
        let shareableContent = try await SCShareableContent.current

        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let targetWindow = shareableContent.windows.first(where: {
                  $0.owningApplication?.processID == frontmostApp.processIdentifier
              }) else {
            return try captureFullscreenSync()
        }

        let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
        let configuration = SCStreamConfiguration()
        configuration.width = Int(targetWindow.frame.width)
        configuration.height = Int(targetWindow.frame.height)
        configuration.scalesToFit = true

        let cgImage = try await captureScreenshotImage(filter: filter, configuration: configuration)
        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }

    private func captureScreenshotImage(
        filter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let image else {
                    continuation.resume(throwing: CaptureError.captureFailed("无法捕获窗口图像"))
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }
    
    private func captureFullscreenSync() throws -> NSImage {
        let displayID = CGMainDisplayID()
        guard let cgImage = CGDisplayCreateImage(displayID) else {
            throw CaptureError.captureFailed("无法创建屏幕图像")
        }
        
        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }
    
    // MARK: - Clipboard Capture
    
    public func captureFromClipboard() async throws -> CaptureResult? {
        let pasteboard = NSPasteboard.general
        
        // 检查图片
        if let image = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
            let assetFile = try await assetStore.saveImage(
                image,
                fileName: "clipboard_\(Date().timeIntervalSince1970).png"
            )
            
            let sourceItem = SourceItem(
                type: .image,
                source: .clipboard,
                status: .captured,
                title: "剪贴板图片 \(formatDate())",
                previewText: "剪贴板图片",
                assetFileIds: [assetFile.id]
            )
            
            try await storage.insertSourceItem(sourceItem)
            
            // 尝试 OCR
            Task {
                if let ocrText = try? await performOCR(imageURL: URL(fileURLWithPath: assetFile.filePath)) {
                    var updatedItem = sourceItem
                    updatedItem.ocrText = ocrText
                    updatedItem.previewText = ocrText.prefix(200).description
                    try? await storage.updateSourceItem(updatedItem)
                }
            }
            
            return CaptureResult(sourceItem: sourceItem, assetFiles: [assetFile])
        }
        
        // 检查文本
        if let text = pasteboard.string(forType: .string) {
            return try await captureFromManualText(text)
        }
        
        // 检查文件 URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let firstURL = urls.first {
            return try await captureFromFile(url: firstURL)
        }
        
        return nil
    }
    
    // MARK: - File Import
    
    public func captureFromFile(url: URL) async throws -> CaptureResult {
        let assetFile = try await assetStore.copyFile(from: url, preserveName: true)
        
        let ext = url.pathExtension.lowercased()
        let type: SourceType
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff":
            type = .image
        case "pdf":
            type = .pdf
        case "docx", "doc":
            type = .docx
        case "txt", "md", "markdown":
            type = .text
        default:
            type = .unknownFile
        }
        
        let sourceItem = SourceItem(
            type: type,
            source: .file,
            status: .captured,
            title: url.lastPathComponent,
            previewText: "导入文件: \(url.lastPathComponent)",
            assetFileIds: [assetFile.id]
        )
        
        try await storage.insertSourceItem(sourceItem)
        
        // 图片类型尝试 OCR
        if type == .image {
            Task {
                if let ocrText = try? await performOCR(imageURL: URL(fileURLWithPath: assetFile.filePath)) {
                    var updatedItem = sourceItem
                    updatedItem.ocrText = ocrText
                    updatedItem.previewText = ocrText.prefix(200).description
                    try? await storage.updateSourceItem(updatedItem)
                }
            }
        }
        
        return CaptureResult(sourceItem: sourceItem, assetFiles: [assetFile])
    }
    
    // MARK: - Webpage Capture
    
    public func captureFromWebpage(url: URL) async throws -> CaptureResult {
        // 下载网页内容
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CaptureError.downloadFailed("HTTP 错误")
        }
        
        // 尝试提取标题
        let content = String(data: data, encoding: .utf8) ?? ""
        let title = extractTitle(from: content) ?? url.host ?? "网页"
        
        // 保存 HTML
        let assetFile = try await assetStore.saveText(
            content,
            fileName: "webpage_\(Date().timeIntervalSince1970).html"
        )
        
        // 提取纯文本预览
        let previewText = extractTextPreview(from: content)
        
        let sourceItem = SourceItem(
            type: .webpage,
            source: .webpage,
            status: .captured,
            title: title,
            previewText: previewText,
            originalUrl: url.absoluteString,
            assetFileIds: [assetFile.id]
        )
        
        try await storage.insertSourceItem(sourceItem)
        
        return CaptureResult(sourceItem: sourceItem, assetFiles: [assetFile])
    }
    
    private func extractTitle(from html: String) -> String? {
        // 简单的正则提取标题
        let pattern = "<title[^>]*>(.*?)</title>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)) else {
            return nil
        }
        
        if let range = Range(match.range(at: 1), in: html) {
            return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func extractTextPreview(from html: String) -> String? {
        // 移除 HTML 标签获取纯文本
        let pattern = "<[^>]+>"
        let text = html.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        
        // 解码 HTML 实体
        var decoded = text
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        
        // 清理空白
        decoded = decoded.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        return decoded.prefix(500).description
    }
    
    // MARK: - Manual Text
    
    public func captureFromManualText(_ text: String) async throws -> CaptureResult {
        let assetFile = try await assetStore.saveText(
            text,
            fileName: "manual_\(Date().timeIntervalSince1970).txt"
        )
        
        let title = text.prefix(50).description
        let previewText = text.prefix(500).description
        
        let sourceItem = SourceItem(
            type: .text,
            source: .manual,
            status: .captured,
            title: title,
            previewText: previewText,
            assetFileIds: [assetFile.id]
        )
        
        try await storage.insertSourceItem(sourceItem)
        
        return CaptureResult(sourceItem: sourceItem, assetFiles: [assetFile])
    }
    
    // MARK: - Voice Capture (Placeholder)
    
    public func captureFromVoice() async throws -> CaptureResult {
        // TODO: 实现语音输入
        throw CaptureError.notImplemented("语音输入尚未实现")
    }
    
    // MARK: - OCR
    
    public func performOCR(imageURL: URL) async throws -> String {
        // 使用 vision_ocr.swift 脚本
        let scriptPath = Bundle.main.path(forResource: "vision_ocr", ofType: "swift")
            ?? "scripts/vision_ocr.swift"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", scriptPath, imageURL.path]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        if process.terminationStatus != 0 {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "OCR 失败"
            throw CaptureError.ocrFailed(errorMessage)
        }
        
        return String(data: outputData, encoding: .utf8) ?? ""
    }
    
    // MARK: - Permission
    
    private func requestScreenCapturePermission() async -> Bool {
        await MainActor.run {
            CGPreflightScreenCaptureAccess()
        }
    }
    
    // MARK: - Helpers
    
    private func formatDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }
}

// MARK: - Errors

public enum CaptureError: Error, LocalizedError {
    case permissionDenied
    case captureFailed(String)
    case downloadFailed(String)
    case ocrFailed(String)
    case notImplemented(String)
    case invalidURL
    case fileNotFound
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "需要屏幕录制权限"
        case .captureFailed(let message):
            return "截图失败: \(message)"
        case .downloadFailed(let message):
            return "下载失败: \(message)"
        case .ocrFailed(let message):
            return "OCR 失败: \(message)"
        case .notImplemented(let feature):
            return "\(feature)"
        case .invalidURL:
            return "无效的 URL"
        case .fileNotFound:
            return "文件未找到"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "请前往系统设置 > 隐私与安全性 > 屏幕录制，授予 AcMind 权限"
        case .captureFailed:
            return "请重试或尝试其他截图模式"
        case .downloadFailed:
            return "请检查网络连接和 URL 是否正确"
        case .ocrFailed:
            return "请确保图片包含可识别的文本"
        case .notImplemented:
            return "该功能将在后续版本推出"
        default:
            return nil
        }
    }
}
