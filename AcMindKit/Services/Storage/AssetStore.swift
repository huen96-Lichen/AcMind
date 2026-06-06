import Foundation
import AppKit
import ImageIO

/// Asset storage manager for binary files (images, audio, documents)
/// Manages local file system storage with SQLite metadata tracking
/// Compatible with legacy asset paths: ~/Library/Application Support/AcMind/assets/
public actor AssetStore: AssetStoreProtocol {
    private var assetsDir: URL
    private let db: Database
    
    public init(database: Database = .shared) {
        self.db = database
        self.assetsDir = AssetStore.resolveAssetsDirectory()
    }
    
    // MARK: - Setup
    
    public func setup() async throws {
        for candidate in assetDirectoryCandidates() {
            do {
                try FileManager.default.createDirectory(at: candidate, withIntermediateDirectories: true)
                assetsDir = candidate
                return
            } catch {
                continue
            }
        }

        try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
    }
    
    // MARK: - Save Operations
    
    /// Save an image to the asset store
    /// - Parameters:
    ///   - image: The NSImage to save
    ///   - sourceItemId: Optional associated source item ID
    ///   - fileName: Optional custom filename (defaults to UUID)
    /// - Returns: AssetFile record with metadata
    public func saveImage(_ image: NSImage, sourceItemId: String? = nil, fileName: String? = nil) async throws -> AssetFile {
        let name = fileName ?? "\(UUID().uuidString).png"
        let url = assetsDir.appendingPathComponent(name)
        
        guard let tiff = image.tiffRepresentation,
              let bmp = NSBitmapImageRep(data: tiff),
              let png = bmp.representation(using: .png, properties: [:]) else {
            throw AssetError.invalidImage
        }
        
        try png.write(to: url)
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        
        let assetFile = AssetFile(
            id: UUID().uuidString,
            sourceItemId: sourceItemId,
            fileName: name,
            filePath: url.path,
            mimeType: "image/png",
            fileSize: fileSize,
            kind: .image
        )
        
        try await insertAssetRecord(assetFile)
        return assetFile
    }
    
    /// Save text content to the asset store
    /// - Parameters:
    ///   - text: The text content to save
    ///   - sourceItemId: Optional associated source item ID
    ///   - fileName: Optional custom filename (defaults to UUID)
    ///   - encoding: Text encoding (defaults to UTF-8)
    /// - Returns: AssetFile record with metadata
    public func saveText(_ text: String, sourceItemId: String? = nil, fileName: String? = nil, encoding: String.Encoding = .utf8) async throws -> AssetFile {
        let name = fileName ?? "\(UUID().uuidString).txt"
        let url = assetsDir.appendingPathComponent(name)
        
        try text.write(to: url, atomically: true, encoding: encoding)
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        
        let assetFile = AssetFile(
            id: UUID().uuidString,
            sourceItemId: sourceItemId,
            fileName: name,
            filePath: url.path,
            mimeType: "text/plain",
            fileSize: fileSize,
            kind: .other
        )
        
        try await insertAssetRecord(assetFile)
        return assetFile
    }

    /// Save audio content to the asset store
    /// - Parameters:
    ///   - data: The audio payload to save
    ///   - sourceItemId: Optional associated source item ID
    ///   - fileName: Optional custom filename (defaults to UUID)
    /// - Returns: AssetFile record with metadata
    public func saveAudio(data: Data, sourceItemId: String? = nil, fileName: String? = nil, mimeType: String = "audio/m4a") async throws -> AssetFile {
        let name = fileName ?? "\(UUID().uuidString).m4a"
        let url = assetsDir.appendingPathComponent(name)

        try data.write(to: url)

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0

        let assetFile = AssetFile(
            id: UUID().uuidString,
            sourceItemId: sourceItemId,
            fileName: name,
            filePath: url.path,
            mimeType: mimeType,
            fileSize: fileSize,
            kind: .audio
        )

        try await insertAssetRecord(assetFile)
        return assetFile
    }

    /// Copy an external file to the asset store
    /// - Parameters:
    ///   - sourceURL: The source file URL
    ///   - sourceItemId: Optional associated source item ID
    ///   - preserveName: Whether to preserve original filename (defaults to false for UUID)
    /// - Returns: AssetFile record with metadata
    public func copyFile(from sourceURL: URL, sourceItemId: String? = nil, preserveName: Bool = false) async throws -> AssetFile {
        let name: String
        if preserveName {
            name = "\(UUID().uuidString)_\(sourceURL.lastPathComponent)"
        } else {
            let ext = sourceURL.pathExtension
            name = ext.isEmpty ? UUID().uuidString : "\(UUID().uuidString).\(ext)"
        }
        
        let destinationURL = assetsDir.appendingPathComponent(name)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int) ?? 0
        let mimeType = AssetStore.mimeType(for: destinationURL.pathExtension)
        let kind = AssetFileKind.from(extension: sourceURL.pathExtension)
        
        let assetFile = AssetFile(
            id: UUID().uuidString,
            sourceItemId: sourceItemId,
            fileName: name,
            filePath: destinationURL.path,
            mimeType: mimeType,
            fileSize: fileSize,
            kind: kind
        )
        
        try await insertAssetRecord(assetFile)
        return assetFile
    }
    
    /// Save markdown content with proper extension
    public func saveMarkdown(_ content: String, sourceItemId: String? = nil, fileName: String? = nil) async throws -> AssetFile {
        let name = fileName ?? "\(UUID().uuidString).md"
        let url = assetsDir.appendingPathComponent(name)
        
        try content.write(to: url, atomically: true, encoding: .utf8)
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        
        let assetFile = AssetFile(
            id: UUID().uuidString,
            sourceItemId: sourceItemId,
            fileName: name,
            filePath: url.path,
            mimeType: "text/markdown",
            fileSize: fileSize,
            kind: .markdown
        )
        
        try await insertAssetRecord(assetFile)
        return assetFile
    }
    
    // MARK: - Retrieve Operations
    
    /// Get asset by ID
    public func getAsset(id: String) async throws -> AssetFile? {
        try await db.getAssetFile(id: id)
    }
    
    /// Get all assets for a source item
    public func getAssetsForSourceItem(sourceItemId: String) async throws -> [AssetFile] {
        try await db.listAssetFiles(sourceItemId: sourceItemId)
    }
    
    /// List all assets with optional filtering
    public func listAssets(kind: AssetFileKind? = nil) async throws -> [AssetFile] {
        try await db.listAssetFiles(kind: kind?.rawValue)
    }
    
    // MARK: - Delete Operations
    
    /// Delete an asset (both file and database record)
    public func deleteAsset(id: String) async throws {
        guard let asset = try await getAsset(id: id) else { return }
        
        // Delete file
        try? FileManager.default.removeItem(atPath: asset.filePath)
        
        // Delete database record
        try await db.deleteAssetFile(id: id)
    }
    
    /// Delete all assets for a source item
    public func deleteAssetsForSourceItem(sourceItemId: String) async throws {
        let assets = try await getAssetsForSourceItem(sourceItemId: sourceItemId)
        for asset in assets {
            try await deleteAsset(id: asset.id)
        }
    }
    
    // MARK: - File Operations
    
    /// Load image from asset
    public nonisolated func loadImage(asset: AssetFile) -> NSImage? {
        guard asset.kind == .image else { return nil }
        return NSImage(contentsOfFile: asset.filePath)
    }

    /// Load a display-sized image without decoding the original full-resolution bitmap.
    public nonisolated func loadImage(asset: AssetFile, maxPixelSize: CGFloat) -> NSImage? {
        guard asset.kind == .image else { return nil }
        guard maxPixelSize > 0 else { return loadImage(asset: asset) }

        let url = URL(fileURLWithPath: asset.filePath) as CFURL
        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url, sourceOptions) else {
            return loadImage(asset: asset)
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded(.up)))
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return loadImage(asset: asset)
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    /// Load text content from asset
    public func loadText(asset: AssetFile) -> String? {
        try? String(contentsOfFile: asset.filePath, encoding: .utf8)
    }
    
    /// Load data from asset
    public func loadData(asset: AssetFile) -> Data? {
        try? Data(contentsOf: URL(fileURLWithPath: asset.filePath))
    }
    
    /// Check if asset file exists on disk
    public nonisolated func assetExists(asset: AssetFile) -> Bool {
        FileManager.default.fileExists(atPath: asset.filePath)
    }
    
    // MARK: - Utility
    
    /// Get total size of all assets
    public func getTotalSize() async throws -> Int64 {
        let assets = try await db.listAssetFiles(kind: nil)
        return assets.reduce(0) { $0 + Int64($1.fileSize ?? 0) }
    }
    
    /// Clean up orphaned assets (files without database records)
    public func cleanupOrphanedAssets() async throws -> Int {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: assetsDir, includingPropertiesForKeys: nil)
        
        var removedCount = 0
        for fileURL in files {
            let path = fileURL.path
            let existsInDB = try await db.assetFileExists(path: path)
            if !existsInDB {
                try? fileManager.removeItem(at: fileURL)
                removedCount += 1
            }
        }
        
        return removedCount
    }
    
    // MARK: - Private
    
    private func insertAssetRecord(_ asset: AssetFile) async throws {
        try await db.insertAssetFile(asset)
    }

    private static func resolveAssetsDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AcMind", isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)
    }

    private func assetDirectoryCandidates() -> [URL] {
        let primary = Self.resolveAssetsDirectory()
        let compat = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcMind", isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)
        return [primary, compat]
    }
    
    private static func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "md", "markdown": return "text/markdown"
        case "html", "htm": return "text/html"
        case "json": return "application/json"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Asset File Model

public struct AssetFile: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let sourceItemId: String?
    public let fileName: String
    public let filePath: String
    public let mimeType: String?
    public let fileSize: Int?
    public let kind: AssetFileKind
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        sourceItemId: String? = nil,
        fileName: String,
        filePath: String,
        mimeType: String? = nil,
        fileSize: Int? = nil,
        kind: AssetFileKind = .other,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceItemId = sourceItemId
        self.fileName = fileName
        self.filePath = filePath
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.kind = kind
        self.createdAt = createdAt
    }

    init(row: SQLiteRow) {
        self.id = row.string("id") ?? UUID().uuidString
        self.sourceItemId = row.string("source_item_id")
        self.fileName = row.string("file_name") ?? ""
        self.filePath = row.string("file_path") ?? ""
        self.mimeType = row.string("mime_type")
        self.fileSize = row.int("file_size")
        self.kind = AssetFileKind(rawValue: row.string("kind") ?? "other") ?? .other
        self.createdAt = Date(timeIntervalSince1970: TimeInterval(row.int("created_at") ?? 0))
    }
}

public enum AssetFileKind: String, Codable, Sendable, CaseIterable {
    case image
    case audio
    case video
    case pdf
    case docx
    case html
    case markdown
    case other
    
    static func from(extension ext: String) -> AssetFileKind {
        switch ext.lowercased() {
        case "png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff":
            return .image
        case "mp3", "wav", "aac", "m4a", "ogg":
            return .audio
        case "mp4", "mov", "avi", "mkv":
            return .video
        case "pdf":
            return .pdf
        case "docx", "doc":
            return .docx
        case "html", "htm":
            return .html
        case "md", "markdown":
            return .markdown
        default:
            return .other
        }
    }
}

public enum AssetError: Error {
    case invalidImage
    case fileNotFound
    case invalidPath
    case databaseError(String)
}
