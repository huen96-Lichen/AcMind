import WebKit
import AcMindKit

// MARK: - WebViewBridge (过渡桥)

/// ⚠️ WebViewBridge 仅作为临时过渡适配层
///
/// 【重要】WebViewBridge 不是新的架构中心，禁止在此添加新的 bridge 接口。
/// 仅保留 Shelf 页面所需的最小化接口，其他功能已全部迁移到原生 Swift 实现。
///
/// 预计移除时间：2025 Q2 (Shelf 迁移完成后)
@MainActor
final class WebViewBridge: NSObject, WKScriptMessageHandler {
    private weak var webView: WKWebView?
    private let services: ServiceContainer

    init(webView: WKWebView, services: ServiceContainer? = nil) {
        self.webView = webView
        self.services = services ?? ServiceContainer.shared
        super.init()
        setup()
    }

    private func setup() {
        let script = WKUserScript(
            source: """
            window.acmind={invoke:(c,m,p)=>new Promise((r,j)=>{const i=crypto.randomUUID();window.webkit.messageHandlers['acmind.'+c].postMessage({method:m,params:p||{},requestId:i});(window.__c||={})[i]={r,j}})},on:(e,cb)=>window.addEventListener('acmind:'+e,x=>cb(x.detail))};
            window.__h=(i,r,e)=>{const c=window.__c[i];if(c){e?c.j(new Error(e)):c.r(r);delete window.__c[i]}};
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        webView?.configuration.userContentController.addUserScript(script)

        // ⚠️ 仅保留 Shelf 页面所需的 bridge 接口
        // 其他接口（capture, clipboard, inbox, distill, export, aiRuntime, settings）
        // 已全部迁移到原生 Swift 实现
        for c in ["shelf"] {
            webView?.configuration.userContentController.add(self, name: "acmind.\(c)")
        }
    }

    func userContentController(_ ucc: WKUserContentController, didReceive msg: WKScriptMessage) {
        guard let b = msg.body as? [String:Any], let m = b["method"] as? String, let r = b["requestId"] as? String else { return }
        let p = b["params"] as? [String:Any] ?? [:]
        let c = msg.name.replacingOccurrences(of: "acmind.", with: "")

        Task {
            do {
                let res = try await handle(c: c, m: m, p: p)
                reply(r: r, res: res, err: nil)
            } catch {
                reply(r: r, res: nil, err: error.localizedDescription)
            }
        }
    }

    /// 处理 bridge 调用
    /// ⚠️ 仅处理 Shelf 相关请求，其他请求返回 nil
    private func handle(c: String, m: String, p: [String:Any]) async throws -> Any? {
        switch c {
        case "shelf":
            return try await handleShelf(method: m, params: p)
        default:
            // ⛔ 已禁用的 bridge 接口
            print("⚠️ Bridge 接口 '\(c)' 已被移除，请使用原生 API")
            return nil
        }
    }

    // MARK: - Shelf Bridge (过渡中)

    /// Shelf 页面专用 bridge 接口
    /// 注意：Shelf 正在迁移中，预计 2025-05-15 完成原生实现
    private func handleShelf(method: String, params: [String:Any]) async throws -> Any? {
        switch method {
        case "listItems":
            // 获取 Shelf 项目列表
            let items = try await services.storageService.listSourceItems(filter: nil)
            return items.map { item in
                [
                    "id": item.id,
                    "title": item.title ?? "",
                    "contentType": item.type.rawValue,
                    "createdAt": ISO8601DateFormatter().string(from: item.createdAt)
                ]
            }

        case "moveToInbox":
            // 将项目移动到 Inbox
            guard let id = params["id"] as? String else { return ["success": false] }
            guard let item = try await services.storageService.getSourceItem(id: id) else {
                return ["success": false]
            }
            var updated = item
            updated.status = .inbox
            try await services.storageService.updateSourceItem(updated)
            return ["success": true]

        case "deleteItem":
            // 删除项目
            guard let id = params["id"] as? String else { return ["success": false] }
            try await services.storageService.deleteSourceItem(id: id)
            return ["success": true]

        default:
            print("⚠️ Shelf bridge 方法 '\(method)' 未实现")
            return nil
        }
    }

    private func reply(r: String, res: Any?, err: String?) {
        let j = (try? JSONSerialization.data(withJSONObject: res ?? NSNull()))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "null"
        let e = err.map { "'\($0)'" } ?? "null"
        DispatchQueue.main.async { [weak webView] in
            webView?.evaluateJavaScript("window.__h('\(r)',\(j),\(e))")
        }
    }
}

// MARK: - Migration Guide

/*
 📋 Bridge 接口迁移指南

 【已移除的接口】请使用对应的原生实现：

 1. capture.screenshot
    替代：CaptureService.captureScreenshot(mode:)
    位置：AcMindKit/Services/Capture/CaptureService.swift

 2. capture.clipboard
    替代：CaptureService.captureFromClipboard()
    位置：AcMindKit/Services/Capture/CaptureService.swift

 3. inbox.list
    替代：StorageService.listSourceItems(filter:)
    位置：AcMindKit/Services/Storage/StorageService.swift

 4. settings.get / settings.set
    替代：SettingsService.getSettings() / updateSettings(_:)
    位置：AcMindKit/Services/Settings/SettingsService.swift

 5. distill.*
    替代：DistillService.distill(item:)
    位置：AcMindKit/Services/Distill/DistillService.swift

 6. export.*
    替代：ExportService.export(items:format:)
    位置：AcMindKit/Services/Export/ExportService.swift

 7. aiRuntime.*
    替代：AIRuntimeService 相关方法
    位置：AcMindKit/Services/AI/AIRuntimeService.swift

 【保留的接口】仅 Shelf 页面使用：

 - shelf.listItems
 - shelf.moveToInbox
 - shelf.deleteItem

 预计移除时间：2025 Q2 (Shelf 迁移完成后)
 */
