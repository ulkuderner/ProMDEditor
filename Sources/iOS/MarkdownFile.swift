import SwiftUI
import UniformTypeIdentifiers

/// Salt okunur Markdown belgesi. Mattermost, Dosyalar ve posta
/// `.md` dosyasını bu türle açar.
struct MarkdownFile: FileDocument {
    static var readableContentTypes: [UTType] { [.markdownDocument, .plainText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

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
