import Cocoa
import QuickLookUI
import WebKit

/// Finder'da bir .md dosyasini secip boşluk tusuna basildiginda calisir.
final class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {

    private var webView: WKWebView!
    private var completion: ((Error?) -> Void)?

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600),
                            configuration: config)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]

        let container = NSView(frame: webView.frame)
        container.autoresizingMask = [.width, .height]
        container.addSubview(webView)
        view = container
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let data = try Data(contentsOf: url)
            let markdown = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""

            let settings = AppSettings.shared
            let isDark = view.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let theme = settings.activeTheme(dark: isDark)

            let body = MarkdownHTMLRenderer.render(markdown)
            let html = StyleSheet.document(bodyHTML: body, theme: theme,
                                           settings: settings, includeScrollBridge: false)

            completion = handler
            // Goreli gorsellerin yuklenebilmesi icin dosyanin klasoru taban URL olur.
            webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
        } catch {
            handler(error)
        }
    }

    // Icerik ekrana cizildikten sonra Quick Look'a hazir oldugumuzu bildir.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        completion?(nil)
        completion = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completion?(error)
        completion = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        completion?(error)
        completion = nil
    }
}
