// AI_Tutor/Views/Components/KaTeXView.swift
import SwiftUI
import WebKit

struct KaTeXView: UIViewRepresentable {
    let content: String
    var onHeightChange: ((CGFloat) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "heightChanged")

        let config = WKWebViewConfiguration()
        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator

        // Load the HTML template once
        if let templateURL = Bundle.main.url(
            forResource: "katex_template",
            withExtension: "html",
            subdirectory: "katex"
        ) {
            if var html = try? String(contentsOf: templateURL, encoding: .utf8) {
                // Replace placeholder with empty string on initial load
                html = html.replacingOccurrences(of: "CONTENT_PLACEHOLDER", with: "")
                let baseURL = templateURL.deletingLastPathComponent()
                webView.loadHTMLString(html, baseURL: baseURL)
            }
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.pendingContent = content
        // Only inject if page is loaded
        if context.coordinator.isPageLoaded {
            context.coordinator.injectContent(into: webView)
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "heightChanged")
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: KaTeXView
        var pendingContent: String = ""
        var isPageLoaded = false

        init(_ parent: KaTeXView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageLoaded = true
            injectContent(into: webView)
        }

        func injectContent(into webView: WKWebView) {
            // Escape for JS string: backslashes and backticks
            let escaped = pendingContent
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            let js = "window.updateContent(`\(escaped)`);"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        // Handle heightChanged messages from JS
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "heightChanged", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.onHeightChange?(height)
                }
            }
        }
    }
}

// MARK: - Dynamic-height wrapper for use in ScrollView
struct DynamicKaTeXView: View {
    let content: String
    @State private var height: CGFloat = 100

    var body: some View {
        KaTeXView(content: content) { newHeight in
            if abs(newHeight - height) > 1 {
                withAnimation(.easeInOut(duration: 0.15)) {
                    height = max(newHeight, 40)
                }
            }
        }
        .frame(height: height)
    }
}
