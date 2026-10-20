import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let markdownDocument = UTType(importedAs: "net.daringfireball.markdown")
}

/// Markdown metnini uygulamadaki temayla tam bir HTML belgesine cevirir.
/// iPhone, iPad ve Quick Look ayni ciktıyı kullanır.
enum FormattedMarkdown {

    static func text(from data: Data) -> String {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    static func html(for text: String, compact: Bool) -> String {
        let settings = AppSettings.shared
        return StyleSheet.document(
            bodyHTML: MarkdownHTMLRenderer.render(text),
            theme: settings.activeTheme(),
            settings: settings,
            includeScrollBridge: false,
            compact: compact)
    }
}
