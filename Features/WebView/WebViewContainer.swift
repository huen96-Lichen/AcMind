import SwiftUI
import WebKit

// MARK: - WebViewContainer

/// WebView 容器视图
///
/// ⚠️ 【重要】WebView 仅作为临时过渡方案，所有页面都应迁移到原生 SwiftUI。
/// 本容器会在加载前通过 WebViewGuard 检查页面是否被允许使用 WebView。
///
/// 预计完全移除 WebView：2025 Q2
struct WebViewContainer: NSViewRepresentable {
    let page: WebViewPage

    func makeNSView(context: Context) -> WKWebView {
        // ⛔ 架构边界保护：禁止加载不允许的 WebView 页面
        guard WebViewGuard.check(page) else {
            print("⛔ WebView 页面 '\(page)' 已被禁用，返回空视图")
            return WKWebView()
        }

        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        context.coordinator.setupBridge(webView: webView)

        loadPage(webView: webView)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 页面切换时重新加载
        if context.coordinator.currentPage != page {
            // ⛔ 架构边界保护：禁止切换到不允许的页面
            guard WebViewGuard.check(page) else {
                print("⛔ 禁止切换到 WebView 页面 '\(page)'")
                return
            }
            context.coordinator.currentPage = page
            loadPage(webView: nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(page: page)
    }

    private func loadPage(webView: WKWebView) {
        // ⛔ 二次检查：确保只有允许的页面才能加载
        guard page.isAllowed else {
            print("⛔ 页面 '\(page)' 不在允许列表中，拒绝加载")
            return
        }

        guard let url = Bundle.main.url(forResource: page.htmlFile, withExtension: "html", subdirectory: "WebViewApp")
            ?? Bundle.main.url(forResource: page.htmlFile, withExtension: "html") else {
            print("Failed to load HTML file for page: \(page)")
            return
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = page.queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }

        if let finalURL = components?.url {
            webView.loadFileURL(finalURL, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var currentPage: WebViewPage
        var bridge: WebViewBridge?

        init(page: WebViewPage) {
            self.currentPage = page
        }

        func setupBridge(webView: WKWebView) {
            bridge = WebViewBridge(webView: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView loaded: \(currentPage)")

            // 注入迁移警告（仅在 DEBUG 模式）
            #if DEBUG
            let warningScript = """
            console.warn('⚠️ [AcMind] WebView 页面 "\(currentPage.rawValue)" 正在使用过渡方案。');
            console.warn('⚠️ [AcMind] 预计完全移除 WebView: 2025 Q2');
            console.warn('⚠️ [AcMind] 迁移信息: \(currentPage.migrationMessage)');
            """
            webView.evaluateJavaScript(warningScript)
            #endif
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView failed: \(error)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView provisional navigation failed: \(error)")
        }
    }
}

// MARK: - WebView Fallback View

/// WebView 禁用时的替代视图
/// 当尝试加载不允许的 WebView 页面时显示此视图
struct WebViewDisabledView: View {
    let page: WebViewPage

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("页面已迁移到原生实现")
                .font(.title2)
                .fontWeight(.semibold)

            Text("'\(page.rawValue)' 页面已从 WebView 迁移到原生 SwiftUI 实现")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Label("请使用原生导航访问此页面", systemImage: "arrow.right.circle")
                Label(page.migrationMessage, systemImage: "info.circle")
            }
            .font(.callout)
            .foregroundColor(.secondary)
            .padding()
            .background(AppSurfaceTokens.cardBackgroundSoft)
            .cornerRadius(8)

            if page == .shelf {
                Text("🚧 Shelf 页面正在迁移中，预计 2025-05-15 完成")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
