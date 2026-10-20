import QuickLook
import UniformTypeIdentifiers

/// Dosyalar, Mail ve Quick Look kullanan uygulamalar `.md` dosyasını
/// bu önizlemeyle biçimli gösterir.
final class MarkdownQuickLook: QLPreviewProvider {
    func providePreview(for request: QLFilePreviewRequest,
                        completionHandler handler: @escaping (QLPreviewReply?, Error?) -> Void) {
        do {
            let data = try Data(contentsOf: request.fileURL)
            let html = FormattedMarkdown.html(for: FormattedMarkdown.text(from: data), compact: false)
            let reply = QLPreviewReply(dataOfContentType: .html,
                                       contentSize: CGSize(width: 800, height: 1100),
                                       createDataUsing: { _ in Data(html.utf8) })
            handler(reply, nil)
        } catch {
            handler(nil, error)
        }
    }
}
