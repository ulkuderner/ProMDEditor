import SwiftUI
import WebKit

struct ReaderView: View {
    let text: String
    let baseURL: URL?
    var showsThemeMenu = true

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var theme: Theme { settings.activeTheme() }

    private var html: String {
        FormattedMarkdown.html(for: text, compact: sizeClass == .compact)
    }

    var body: some View {
        HTMLView(html: html, baseURL: baseURL, background: theme.bg)
            .background(Color(hex: theme.bg))
            .ignoresSafeArea(edges: .bottom)
            .toolbar { if showsThemeMenu { themeMenu } }
    }

    private var themeMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("Theme", selection: $settings.themeID) {
                    ForEach(Theme.all) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
            } label: {
                Label(theme.name, systemImage: "paintpalette")
            }
        }
    }
}

struct HTMLView: UIViewRepresentable {
    let html: String
    let baseURL: URL?
    let background: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.navigationDelegate = context.coordinator
        view.backgroundColor = UIColor(hex: background)
        view.scrollView.backgroundColor = view.backgroundColor
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        view.backgroundColor = UIColor(hex: background)
        view.scrollView.backgroundColor = view.backgroundColor
        let parts = HTMLPatch.parts(of: html)
        if context.coordinator.ready,
           let parts,
           parts.shell == context.coordinator.shell,
           parts.body != context.coordinator.body,
           let script = HTMLPatch.script(replacingBody: parts.body) {
            context.coordinator.body = parts.body
            context.coordinator.loaded = html
            view.evaluateJavaScript(script)
            return
        }
        if context.coordinator.loaded != html {
            context.coordinator.ready = false
            context.coordinator.loaded = html
            context.coordinator.shell = parts?.shell
            context.coordinator.body = parts?.body
            view.loadHTMLString(html, baseURL: baseURL)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded: String?
        var shell: String?
        var body: String?
        var ready = false

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
        }
    }
}

