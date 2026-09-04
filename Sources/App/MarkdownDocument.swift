import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown")
}

struct MarkdownDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.markdown, .plainText] }
    static var writableContentTypes: [UTType] { [.markdown] }

    var text: String

    init(text: String = MarkdownDocument.starterText) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        // UTF-8 basarisiz olursa Latin-1'e dus (eski dosyalar icin)
        if let s = String(data: data, encoding: .utf8) {
            text = s
        } else if let s = String(data: data, encoding: .isoLatin1) {
            text = s
        } else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }

    static let starterText = """
    # Yeni Belge

    Yazmaya buradan başla. **Kalın**, *italik*, `kod` ve ~~üstü çizili~~ metin desteklenir.

    - [ ] Yapılacak madde
    - [x] Tamamlanan madde

    > Alıntı bloğu.

    ```swift
    print("Merhaba, ProMDEditor")
    ```

    | Sütun | Açıklama |
    |-------|----------|
    | ⌘B    | Kalın    |
    | ⌘I    | İtalik   |
    """
}
