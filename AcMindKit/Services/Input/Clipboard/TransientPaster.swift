import Foundation
import AppKit

public final class TransientPaster: @unchecked Sendable {
    
    private let pauseMonitoring: () async -> Void
    private let resumeMonitoring: () async -> Void
    
    public init(
        pauseMonitoring: @escaping () async -> Void,
        resumeMonitoring: @escaping () async -> Void
    ) {
        self.pauseMonitoring = pauseMonitoring
        self.resumeMonitoring = resumeMonitoring
    }
    
    public func pasteTransiently(_ item: ClipboardItem, assetStore: AssetStore) async {
        await pauseMonitoring()
        
        let pasteboard = NSPasteboard.general
        
        let savedTypes = pasteboard.types ?? []
        var savedData: [NSPasteboard.PasteboardType: Data] = [:]
        for type in savedTypes {
            if let data = pasteboard.data(forType: type) {
                savedData[type] = data
            }
        }
        
        await writeItemToPasteboard(item, pasteboard: pasteboard, assetStore: assetStore)
        
        simulatePasteKeystroke()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        pasteboard.clearContents()
        for (type, data) in savedData {
            pasteboard.setData(data, forType: type)
        }
        
        await resumeMonitoring()
    }
    
    private func writeItemToPasteboard(_ item: ClipboardItem, pasteboard: NSPasteboard, assetStore: AssetStore) async {
        pasteboard.clearContents()
        
        switch item.type {
        case .text, .url, .code:
            if let text = item.textContent ?? item.content {
                pasteboard.setString(text, forType: .string)
            }
        case .richText:
            if let html = item.htmlContent ?? item.content {
                pasteboard.setString(html, forType: NSPasteboard.PasteboardType("public.html"))
            }
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let assetId = item.content,
               let asset = try? await assetStore.getAsset(id: assetId),
               let image = assetStore.loadImage(asset: asset) {
                pasteboard.writeObjects([image])
            }
        case .file:
            if let paths = item.content?.split(separator: "\n").map(String.init) {
                let urls = paths.map { URL(fileURLWithPath: $0) }
                pasteboard.writeObjects(urls as [NSURL])
            }
        case .video:
            if let text = item.textContent ?? item.content {
                pasteboard.setString(text, forType: .string)
            }
        }
    }

    private func simulatePasteKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
