import SwiftUI
import UniformTypeIdentifiers

/// Düzenlenebilir Markdown belgesi. Mattermost, Dosyalar ve posta
/// `.md` dosyasını bu türle açar.
struct MarkdownFile: FileDocument {
    static var readableContentTypes: [UTType] { [.markdownDocument, .plainText] }
    static var writableContentTypes: [UTType] { [.markdownDocument, .plainText] }

    var text: String

    init(text: String = MarkdownFile.starter) {
        self.text = text
    }

    static let starter = """
    # New Document

    Start writing here. **Bold**, *italic*, `code` and ~~strikethrough~~ text are supported.

    Inline formula: $E = mc^2$.

    $$
    \\frac{a}{b}
    $$
    """

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = FormattedMarkdown.text(from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
