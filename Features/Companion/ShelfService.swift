//
//  ShelfService.swift
//  AcMind
//
//  Adapted from BoringNotch Shelf
//  Simplified file drop zone for temporary storage
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import AcMindKit

// MARK: - Shelf Item

/// Shelf 暂存项类型
public enum ShelfItemKind: Codable, Equatable, Sendable {
    case file(url: URL)
    case text(String)
    case link(URL)

    enum CodingKeys: String, CodingKey { case type, value }
    enum KindTag: String, Codable { case file, text, link }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(KindTag.self, forKey: .type)
        switch type {
        case .file:
            self = .file(url: try container.decode(URL.self, forKey: .value))
        case .text:
            self = .text(try container.decode(String.self, forKey: .value))
        case .link:
            self = .link(try container.decode(URL.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .file(let url):
            try container.encode(KindTag.file, forKey: .type)
            try container.encode(url, forKey: .value)
        case .text(let string):
            try container.encode(KindTag.text, forKey: .type)
            try container.encode(string, forKey: .value)
        case .link(let url):
            try container.encode(KindTag.link, forKey: .type)
            try container.encode(url, forKey: .value)
        }
    }

    var icon: NSImage {
        switch self {
        case .file(let url):
            return NSWorkspace.shared.icon(forFile: url.path)
        case .text:
            return NSImage(systemSymbolName: "text.justifyleft", accessibilityDescription: nil) ?? NSImage()
        case .link:
            return NSImage(systemSymbolName: "link", accessibilityDescription: nil) ?? NSImage()
        }
    }

    var displayName: String {
        switch self {
        case .file(let url):
            return url.lastPathComponent
        case .text(let string):
            let firstLine = string.components(separatedBy: .newlines).first ?? string
            return firstLine.count > 30 ? String(firstLine.prefix(27)) + "..." : firstLine
        case .link(let url):
            return url.host ?? url.absoluteString
        }
    }
}

/// Shelf 暂存项
public struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var kind: ShelfItemKind
    public var addedAt: Date

    public init(id: UUID = UUID(), kind: ShelfItemKind, addedAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.addedAt = addedAt
    }
}

// MARK: - Shelf Service

/// Shelf 服务 - 管理暂存文件
@MainActor
public class ShelfService: ObservableObject {
    public static let shared = ShelfService()

    @Published public var items: [ShelfItem] = []
    @Published public var isDropTargeting: Bool = false

    private let maxItems = 10
    private let storageKey = "acmind.shelf.items"

    private init() {
        loadItems()
    }

    // MARK: - CRUD

    public func addItem(_ item: ShelfItem) {
        // 去重
        if items.contains(where: { $0.kind == item.kind }) { return }

        items.insert(item, at: 0)

        // 限制数量
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        saveItems()
    }

    public func removeItem(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    public func clearAll() {
        items.removeAll()
        saveItems()
    }

    // MARK: - Persistence

    private func saveItems() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let loaded = try? JSONDecoder().decode([ShelfItem].self, from: data) else { return }
        items = loaded
    }

    // MARK: - Drop Handling

    public func handleDrop(providers: [NSItemProvider]) -> Bool {
        var addedCount = 0

        for provider in providers {
            // 文件 URL
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] data, _ in
                    guard let self = self, let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in
                        self.addItem(ShelfItem(kind: .file(url: url)))
                    }
                }
                addedCount += 1
            }
            // 纯文本
            else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] data, _ in
                    guard let self = self, let text = data as? String else { return }
                    Task { @MainActor in
                        self.addItem(ShelfItem(kind: .text(text)))
                    }
                }
                addedCount += 1
            }
            // URL
            else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] data, _ in
                    guard let self = self, let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in
                        self.addItem(ShelfItem(kind: .link(url)))
                    }
                }
                addedCount += 1
            }
        }

        return addedCount > 0
    }
}

// MARK: - Shelf View

/// Shelf 暂存区视图
public struct ShelfView: View {
    @ObservedObject private var shelfService = ShelfService.shared
    @State private var isDropTargeting = false

    private let itemSize: CGFloat = 48
    private let spacing: CGFloat = 8

    public init() {}

    public var body: some View {
        HStack(spacing: spacing) {
            if shelfService.items.isEmpty {
                emptyState
            } else {
                itemsList
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isDropTargeting ? Color.accentColor.opacity(0.8) : Color.white.opacity(0.2),
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(isDropTargeting ? 0.3 : 0.1))
                )
        )
        .onDrop(of: [.fileURL, .url, .plainText], isTargeted: $isDropTargeting) { providers in
            shelfService.handleDrop(providers: providers)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.5))

            Text("拖放文件")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .frame(height: itemSize)
    }

    private var itemsList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(shelfService.items) { item in
                    ShelfItemView(item: item) {
                        shelfService.removeItem(item)
                    }
                }
            }
        }
        .frame(height: itemSize + 8)
    }
}

/// 单个暂存项视图
public struct ShelfItemView: View {
    let item: ShelfItem
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var showContextMenu = false

    public init(item: ShelfItem, onDelete: @escaping () -> Void) {
        self.item = item
        self.onDelete = onDelete
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                Image(nsImage: item.kind.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)

                Text(item.kind.displayName)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .foregroundStyle(Color.white.opacity(0.8))
            }
            .frame(width: 48, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(isHovered ? 0.2 : 0.1))
            )
            .onTapGesture {
                openItem()
            }
            .onHover { hovering in
                isHovered = hovering
            }
            .contextMenu {
                Button("打开") {
                    openItem()
                }

                Button("在 Finder 中显示") {
                    revealInFinder()
                }

                Divider()

                Button("发送到收集箱") {
                    sendToInbox()
                }

                Divider()

                Button("移除", role: .destructive) {
                    onDelete()
                }
            }

            // 删除按钮
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(PlainButtonStyle())
                .offset(x: 4, y: -4)
            }
        }
    }

    // MARK: - Actions

    private func openItem() {
        switch item.kind {
        case .file(let url):
            NSWorkspace.shared.open(url)
            ToastManager.shared.show(.info, "已打开文件")
        case .text(let string):
            // 复制到剪贴板
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
            ToastManager.shared.show(.success, "已复制到剪贴板")
        case .link(let url):
            NSWorkspace.shared.open(url)
            ToastManager.shared.show(.info, "已打开链接")
        }
    }

    private func revealInFinder() {
        switch item.kind {
        case .file(let url):
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        case .link:
            // 链接不支持在 Finder 中显示
            ToastManager.shared.show(.warning, "链接不支持此操作")
        case .text:
            ToastManager.shared.show(.warning, "文本不支持此操作")
        }
    }

    private func sendToInbox() {
        Task {
            do {
                let storage = ServiceContainer.shared.storageService
                switch item.kind {
                case .file(let url):
                    let sourceType = SourceType.inferred(fromFileURL: url)
                    let sourceItem = SourceItem(
                        id: UUID().uuidString,
                        type: sourceType,
                        source: .file,
                        status: .captured,
                        title: url.lastPathComponent,
                        previewText: "文件: \(url.lastPathComponent)",
                        metadata: ["path": url.path, "size": fileSize(at: url)]
                    )
                    try await storage.insertSourceItem(sourceItem)
                    ToastManager.shared.show(.success, "已发送到收集箱")
                    onDelete()

                case .text(let string):
                    let sourceItem = SourceItem(
                        id: UUID().uuidString,
                        type: .text,
                        source: .manual,
                        status: .captured,
                        title: String(string.prefix(50)),
                        previewText: string
                    )
                    try await storage.insertSourceItem(sourceItem)
                    ToastManager.shared.show(.success, "已发送到收集箱")
                    onDelete()

                case .link(let url):
                    let sourceItem = SourceItem(
                        id: UUID().uuidString,
                        type: .webpage,
                        source: .webpage,
                        status: .captured,
                        title: url.host ?? url.absoluteString,
                        previewText: url.absoluteString
                    )
                    try await storage.insertSourceItem(sourceItem)
                    ToastManager.shared.show(.success, "已发送到收集箱")
                    onDelete()
                }
            } catch {
                ToastManager.shared.show(.error, "发送失败: \(error.localizedDescription)")
            }
        }
    }

    private func fileSize(at url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "未知" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
