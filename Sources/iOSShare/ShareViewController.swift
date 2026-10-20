import UIKit
import UniformTypeIdentifiers
import WebKit

/// Paylaş sayfasından gelen `.md` veya düz metni biçimli gösterir.
/// Mattermost eki bu yolla açılır.
final class ShareViewController: UIViewController, WKNavigationDelegate {
    private let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        web.frame = view.bounds
        web.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        web.navigationDelegate = self
        view.addSubview(web)

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(close))
        preferredContentSize = CGSize(width: 520, height: 720)
        loadSharedItem()
    }

    @objc private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func loadSharedItem() {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []
        let markdownID = UTType.markdownDocument.identifier

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(markdownID) }) {
            read(provider, type: markdownID)
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            read(provider, type: UTType.plainText.identifier)
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            read(provider, type: UTType.fileURL.identifier)
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.data.identifier) }) {
            read(provider, type: UTType.data.identifier)
        }
    }

    private func read(_ provider: NSItemProvider, type: String) {
        provider.loadItem(forTypeIdentifier: type) { [weak self] item, _ in
            let text = Self.string(from: item)
            DispatchQueue.main.async {
                self?.show(text)
            }
        }
    }

    private func show(_ text: String) {
        let html = FormattedMarkdown.html(for: text, compact: traitCollection.horizontalSizeClass == .compact)
        web.loadHTMLString(html, baseURL: nil)
    }

    private static func string(from item: NSSecureCoding?) -> String {
        if let text = item as? String { return text }
        if let url = item as? URL,
           let data = try? Data(contentsOf: url) {
            return FormattedMarkdown.text(from: data)
        }
        if let data = item as? Data { return FormattedMarkdown.text(from: data) }
        return ""
    }
}
