import SwiftUI
import WebKit

struct PreviewWebView: NSViewRepresentable {

    let html: String
    let baseURL: URL?
    /// 0...1 arasi; editor kaydirmasina eslesmek icin.
    var scrollPercent: Double?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = true
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastHTML != html {
            context.coordinator.lastHTML = html
            context.coordinator.pendingScroll = context.coordinator.currentScroll
            webView.loadHTMLString(html, baseURL: baseURL)
        } else if let scrollPercent, abs(scrollPercent - context.coordinator.currentScroll) > 0.005 {
            context.coordinator.currentScroll = scrollPercent
            webView.evaluateJavaScript("window.mpScrollTo(\(scrollPercent));")
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML: String = ""
        var currentScroll: Double = 0
        var pendingScroll: Double?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let p = pendingScroll {
                webView.evaluateJavaScript("window.mpScrollTo(\(p));")
                pendingScroll = nil
            }
        }

        /// Disari acilan baglantilari varsayilan tarayiciya gonder.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               url.scheme == "http" || url.scheme == "https" {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
