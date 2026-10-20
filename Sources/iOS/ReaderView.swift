import SwiftUI
import WebKit

struct ReaderView: View {
    let text: String
    let baseURL: URL?

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
            .toolbar { themeMenu }
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
        let view = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        view.isOpaque = false
        view.backgroundColor = UIColor(hex: background)
        view.scrollView.backgroundColor = view.backgroundColor
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        view.backgroundColor = UIColor(hex: background)
        view.scrollView.backgroundColor = view.backgroundColor
        if context.coordinator.loaded != html {
            context.coordinator.loaded = html
            view.loadHTMLString(html, baseURL: baseURL)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loaded: String?
    }
}

private extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt32(s, radix: 16) ?? 0
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }
}

private extension Color {
    init(hex: String) { self.init(uiColor: UIColor(hex: hex)) }
}
