import AppKit
import WebKit
import Markdown
import UniformTypeIdentifiers

/// Menü cubugu ve arac cubugunun paylastigi disa aktarma komutlari.
enum DocumentExportCommand {
    case html
    case pdf
    case docx
    case rtf
    case copyRichText
    case copyHTML
    case print
}

extension Notification.Name {
    static let markPadExport = Notification.Name("markPadExport")
}

enum DocumentExportError: LocalizedError {
    case failed

    var errorDescription: String? {
        String(localized: "Could not export the document.")
    }
}

enum DocumentFileTypes {
    static let docx = UTType("org.openxmlformats.wordprocessingml.document")
        ?? UTType(filenameExtension: "docx")
        ?? .data
}

// MARK: - Zengin metin

/// Markdown'i Word, Pages ve panonun okuyabilecegi NSAttributedString'e cevirir.
///
/// Koyu temada acik yazi, beyaz sayfada kaybolur. Cagiran, kagida gidecek
/// belgeler icin acik temayi gecirir. HTML ve PDF sayfa zemini tasidigi icin
/// aktif temayi kullanmaya devam eder.
enum MarkdownRichText {

    static func render(_ markdown: String, settings: AppSettings, theme: Theme, baseURL: URL?) -> NSAttributedString {
        let document = Document(parsing: markdown, options: [.parseBlockDirectives])
        var renderer = RichTextRenderer(style: RichTextStyle(settings: settings, theme: theme, baseURL: baseURL))
        let rendered = renderer.visit(document)
        if rendered.length > 0 { return rendered }
        return NSAttributedString(string: "\n", attributes: renderer.textAttributes())
    }

    static func rtfData(_ text: NSAttributedString) throws -> Data {
        try data(text, type: .rtf)
    }

    static func docxData(_ text: NSAttributedString) throws -> Data {
        try data(text, type: .officeOpenXML)
    }

    private static func data(_ text: NSAttributedString, type: NSAttributedString.DocumentType) throws -> Data {
        let source = text.length > 0 ? text : NSAttributedString(string: "\n")
        return try source.data(
            from: NSRange(location: 0, length: source.length),
            documentAttributes: [.documentType: type]
        )
    }
}

/// Word ve RTF icin okunakli tipografi. Renkler cagiranin verdigi temadan gelir.
private struct RichTextStyle {
    let bodyName: String
    let headingName: String
    let monoName: String
    let bodySize: CGFloat
    let lineHeight: CGFloat
    let justify: Bool
    let foreground: NSColor
    let muted: NSColor
    let accent: NSColor
    let codeBG: NSColor
    let codeFG: NSColor
    let border: NSColor
    let quote: NSColor
    let baseURL: URL?

    init(settings: AppSettings, theme: Theme, baseURL: URL?) {
        bodyName = settings.bodyFontName
        headingName = settings.headingFontName
        monoName = settings.monoFontName
        bodySize = CGFloat(settings.bodyFontSize)
        lineHeight = CGFloat(min(max(settings.lineHeight, 1), 2.4))
        justify = settings.justifyText
        foreground = theme.nsForeground
        muted = theme.nsMuted
        accent = theme.nsAccent
        codeBG = theme.nsCodeBG
        codeFG = theme.nsForeground
        border = NSColor(hex: theme.border) ?? .separatorColor
        quote = NSColor(hex: theme.quoteBar) ?? .separatorColor
        self.baseURL = baseURL
    }

    func headingSize(_ level: Int) -> CGFloat {
        let em: CGFloat
        switch level {
        case 1: em = 2.05
        case 2: em = 1.55
        case 3: em = 1.28
        case 4: em = 1.08
        case 5: em = 1
        default: em = 0.92
        }
        return bodySize * em
    }
}

private struct RichTextRenderer: MarkupVisitor {

    typealias Result = NSAttributedString

    let style: RichTextStyle

    init(style: RichTextStyle) {
        self.style = style
    }

    private var traits: NSFontTraitMask = []
    private var inlineCode = false
    private var strike = false
    private var linkURL: URL?
    private var headingLevel = 0
    private var quoteDepth = 0
    private var listStack: [NSTextList] = []

    mutating func defaultVisit(_ markup: Markup) -> NSAttributedString {
        joined(markup)
    }

    mutating func visitDocument(_ document: Document) -> NSAttributedString {
        joined(document)
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
        block(inlineSequence(paragraph), paragraph: quoteDepth > 0 ? quoteParagraph() : bodyParagraph())
    }

    mutating func visitHeading(_ heading: Heading) -> NSAttributedString {
        let saved = headingLevel
        headingLevel = heading.level
        let inner = inlineSequence(heading)
        headingLevel = saved
        return block(inner, paragraph: headingParagraph(level: heading.level))
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSAttributedString {
        let paragraph = bodyParagraph()
        let rule = NSTextBlock()
        rule.setContentWidth(100, type: .percentageValueType)
        rule.setWidth(1, type: .absoluteValueType, for: .border, edge: .minY)
        rule.setBorderColor(style.border, for: .minY)
        paragraph.textBlocks = [rule]
        paragraph.paragraphSpacingBefore = style.bodySize * 0.6
        paragraph.paragraphSpacing = style.bodySize * 0.6
        return NSAttributedString(string: "\n", attributes: [
            .paragraphStyle: paragraph,
            .font: fontForCurrent()
        ])
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSAttributedString {
        quoteDepth += 1
        let result = joined(blockQuote)
        quoteDepth -= 1
        return result
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        inlineCode = true
        let inner = NSAttributedString(string: codeBlock.code, attributes: textAttributes())
        inlineCode = false
        return block(inner, paragraph: codeParagraph())
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> NSAttributedString {
        let plain = Self.stripTags(html.rawHTML).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plain.isEmpty else { return NSAttributedString() }
        return block(NSAttributedString(string: plain, attributes: textAttributes()), paragraph: bodyParagraph())
    }

    mutating func visitUnorderedList(_ list: UnorderedList) -> NSAttributedString {
        let formats: [NSTextList.MarkerFormat] = [.disc, .circle, .square]
        let marker = formats[listStack.count % formats.count]
        listStack.append(NSTextList(markerFormat: marker, options: 0))
        let result = joined(list)
        listStack.removeLast()
        return result
    }

    mutating func visitOrderedList(_ list: OrderedList) -> NSAttributedString {
        let marker = NSTextList(markerFormat: .decimal, options: 0)
        marker.startingItemNumber = Int(list.startIndex)
        listStack.append(marker)
        let result = joined(list)
        listStack.removeLast()
        return result
    }

    mutating func visitListItem(_ item: ListItem) -> NSAttributedString {
        let out = NSMutableAttributedString()
        var firstBlock = true
        for child in item.children {
            if child is UnorderedList || child is OrderedList {
                var copy = self
                out.append(copy.visit(child))
                firstBlock = false
                continue
            }
            if let paragraph = child as? Paragraph {
                var copy = self
                let inner = copy.inlineSequence(paragraph)
                let marked = firstBlock
                firstBlock = false
                out.append(copy.block(inner,
                                      paragraph: copy.listParagraph(marker: marked),
                                      leadingTab: marked,
                                      checkbox: marked ? item.checkbox : nil))
                continue
            }
            var copy = self
            out.append(copy.visit(child))
            firstBlock = false
        }
        if out.length == 0 {
            out.append(block(NSAttributedString(),
                             paragraph: listParagraph(marker: true),
                             leadingTab: true,
                             checkbox: item.checkbox))
        }
        return out
    }

    mutating func visitText(_ text: Text) -> NSAttributedString {
        NSAttributedString(string: text.string, attributes: textAttributes())
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> NSAttributedString {
        traits.insert(.italicFontMask)
        let result = inlineSequence(emphasis)
        traits.remove(.italicFontMask)
        return result
    }

    mutating func visitStrong(_ strong: Strong) -> NSAttributedString {
        traits.insert(.boldFontMask)
        let result = inlineSequence(strong)
        traits.remove(.boldFontMask)
        return result
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> NSAttributedString {
        strike = true
        let result = inlineSequence(strikethrough)
        strike = false
        return result
    }

    mutating func visitInlineCode(_ inlineCodeNode: InlineCode) -> NSAttributedString {
        inlineCode = true
        let result = NSAttributedString(string: inlineCodeNode.code, attributes: textAttributes())
        inlineCode = false
        return result
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> NSAttributedString {
        NSAttributedString(string: Self.stripTags(inlineHTML.rawHTML), attributes: textAttributes())
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> NSAttributedString {
        NSAttributedString(string: "\n", attributes: textAttributes())
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> NSAttributedString {
        NSAttributedString(string: " ", attributes: textAttributes())
    }

    mutating func visitLink(_ link: Link) -> NSAttributedString {
        let saved = linkURL
        if let destination = link.destination, let url = URL(string: destination), !destination.isEmpty {
            linkURL = url
        }
        let result = inlineSequence(link)
        linkURL = saved
        return result
    }

    mutating func visitImage(_ image: Image) -> NSAttributedString {
        let alt = image.plainText
        if let source = image.source, let url = resolve(source), let nsImage = NSImage(contentsOf: url) {
            let maxWidth = 640 as CGFloat
            var size = nsImage.size
            if size.width > maxWidth, size.width > 0 {
                let scale = maxWidth / size.width
                size = NSSize(width: maxWidth, height: size.height * scale)
            }
            let attachment = NSTextAttachment()
            attachment.image = nsImage
            attachment.bounds = NSRect(origin: .zero, size: size)
            return NSAttributedString(attachment: attachment)
        }
        let fallback = alt.isEmpty ? (image.source ?? "") : alt
        return NSAttributedString(string: fallback, attributes: textAttributes())
    }

    mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> NSAttributedString {
        inlineCode = true
        let result = NSAttributedString(string: symbolLink.destination ?? "", attributes: textAttributes())
        inlineCode = false
        return result
    }

    mutating func visitTable(_ table: Table) -> NSAttributedString {
        let alignments = table.columnAlignments
        let columnCount = max(Int(table.head.childCount), alignments.count, 1)
        let textTable = NSTextTable()
        textTable.numberOfColumns = columnCount
        textTable.collapsesBorders = true
        textTable.setContentWidth(100, type: .percentageValueType)

        let out = NSMutableAttributedString()
        appendRow(table.head, row: 0, header: true, alignments: alignments, table: textTable, into: out)
        for (offset, row) in table.body.rows.enumerated() {
            appendRow(row, row: offset + 1, header: false, alignments: alignments, table: textTable, into: out)
        }
        return out
    }

    mutating func visitTableHead(_ tableHead: Table.Head) -> NSAttributedString { joined(tableHead) }
    mutating func visitTableBody(_ tableBody: Table.Body) -> NSAttributedString { joined(tableBody) }
    mutating func visitTableRow(_ tableRow: Table.Row) -> NSAttributedString { joined(tableRow) }
    mutating func visitTableCell(_ tableCell: Table.Cell) -> NSAttributedString { inlineSequence(tableCell) }

    // MARK: - Blok kurulumu

    private func joined(_ markup: Markup) -> NSAttributedString {
        let out = NSMutableAttributedString()
        for child in markup.children {
            var copy = self
            out.append(copy.visit(child))
        }
        return out
    }

    private func inlineSequence(_ markup: Markup) -> NSAttributedString {
        joined(markup)
    }

    private func block(_ content: NSAttributedString,
                       paragraph: NSParagraphStyle,
                       leadingTab: Bool = false,
                       checkbox: Checkbox? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if leadingTab {
            result.append(NSAttributedString(string: "\t", attributes: textAttributes()))
        }
        if let checkbox {
            let mark = checkbox == .checked ? "☑ " : "☐ "
            result.append(NSAttributedString(string: mark, attributes: textAttributes()))
        }
        result.append(content)
        if result.length == 0 {
            result.append(NSAttributedString(string: "\u{00A0}", attributes: textAttributes()))
        }
        if !result.string.hasSuffix("\n") {
            result.append(NSAttributedString(string: "\n", attributes: textAttributes()))
        }
        result.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: result.length))
        return result
    }

    private mutating func appendRow(_ row: Markup, row rowIndex: Int, header: Bool,
                                    alignments: [Table.ColumnAlignment?], table: NSTextTable,
                                    into out: NSMutableAttributedString) {
        var column = 0
        for child in row.children {
            guard let cell = child as? Table.Cell else { continue }
            let span = max(1, Int(cell.colspan))
            var copy = self
            let inner = NSMutableAttributedString(attributedString: copy.inlineSequence(cell))
            if inner.length == 0 {
                inner.append(NSAttributedString(string: "\u{00A0}", attributes: textAttributes()))
            }
            if !inner.string.hasSuffix("\n") {
                inner.append(NSAttributedString(string: "\n", attributes: textAttributes()))
            }
            let paragraph = cellParagraph(table: table, row: rowIndex, column: column,
                                          span: span, alignments: alignments, header: header)
            inner.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: inner.length))
            if header {
                let bold = NSFontManager.shared.convert(fontForCurrent(), toHaveTrait: .boldFontMask)
                inner.addAttribute(.font, value: bold, range: NSRange(location: 0, length: inner.length))
            }
            out.append(inner)
            column += span
        }
    }

    // MARK: - Paragraf stilleri

    private func bodyParagraph() -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = style.lineHeight
        paragraph.paragraphSpacing = style.bodySize * 0.45
        paragraph.alignment = style.justify ? .justified : .left
        paragraph.lineBreakMode = .byWordWrapping
        return paragraph
    }

    private func headingParagraph(level: Int) -> NSMutableParagraphStyle {
        let paragraph = bodyParagraph()
        paragraph.alignment = .left
        paragraph.lineHeightMultiple = 1.15
        paragraph.paragraphSpacingBefore = level == 1 ? 0 : style.bodySize * 0.7
        paragraph.paragraphSpacing = style.bodySize * 0.3
        return paragraph
    }

    private func listParagraph(marker: Bool) -> NSMutableParagraphStyle {
        let paragraph = bodyParagraph()
        paragraph.alignment = .left
        paragraph.paragraphSpacing = style.bodySize * 0.2
        let level = max(listStack.count, 1)
        let step: CGFloat = 22
        let markerGap: CGFloat = 18
        paragraph.firstLineHeadIndent = CGFloat(level - 1) * step
        paragraph.headIndent = paragraph.firstLineHeadIndent + markerGap
        paragraph.tabStops = [NSTextTab(textAlignment: .left, location: paragraph.headIndent, options: [:])]
        paragraph.defaultTabInterval = markerGap
        if marker {
            paragraph.textLists = listStack
        }
        return paragraph
    }

    private func quoteParagraph() -> NSMutableParagraphStyle {
        let paragraph = bodyParagraph()
        paragraph.alignment = .left
        paragraph.headIndent = 16
        paragraph.firstLineHeadIndent = 16
        let block = NSTextBlock()
        block.setContentWidth(100, type: .percentageValueType)
        for edge: NSRectEdge in [.minX, .maxX, .minY, .maxY] {
            block.setWidth(0, type: .absoluteValueType, for: .border, edge: edge)
        }
        block.setWidth(3, type: .absoluteValueType, for: .border, edge: .minX)
        block.setBorderColor(style.quote, for: .minX)
        block.setWidth(10, type: .absoluteValueType, for: .padding, edge: .minX)
        paragraph.textBlocks = [block]
        return paragraph
    }

    private func codeParagraph() -> NSMutableParagraphStyle {
        let paragraph = bodyParagraph()
        paragraph.alignment = .left
        paragraph.lineHeightMultiple = 1.35
        paragraph.headIndent = 10
        paragraph.firstLineHeadIndent = 10
        let block = NSTextBlock()
        block.backgroundColor = style.codeBG
        block.setContentWidth(100, type: .percentageValueType)
        for edge: NSRectEdge in [.minX, .maxX, .minY, .maxY] {
            block.setWidth(1, type: .absoluteValueType, for: .border, edge: edge)
            block.setBorderColor(style.border, for: edge)
            block.setWidth(8, type: .absoluteValueType, for: .padding, edge: edge)
        }
        paragraph.textBlocks = [block]
        return paragraph
    }

    private func cellParagraph(table: NSTextTable, row: Int, column: Int, span: Int,
                               alignments: [Table.ColumnAlignment?], header: Bool) -> NSParagraphStyle {
        let block = NSTextTableBlock(table: table, startingRow: row, rowSpan: 1,
                                     startingColumn: column, columnSpan: span)
        block.verticalAlignment = .topAlignment
        for edge: NSRectEdge in [.minX, .maxX, .minY, .maxY] {
            block.setWidth(0.5, type: .absoluteValueType, for: .border, edge: edge)
            block.setBorderColor(style.border, for: edge)
            let pad: CGFloat = (edge == .minY || edge == .maxY) ? 3 : 6
            block.setWidth(pad, type: .absoluteValueType, for: .padding, edge: edge)
        }
        if header { block.backgroundColor = style.codeBG }
        let paragraph = bodyParagraph()
        paragraph.textBlocks = [block]
        paragraph.paragraphSpacing = 0
        paragraph.paragraphSpacingBefore = 0
        let align = column < alignments.count ? alignments[column] : nil
        switch align {
        case .center: paragraph.alignment = .center
        case .right: paragraph.alignment = .right
        default: paragraph.alignment = .left
        }
        return paragraph
    }

    // MARK: - Yazi

    fileprivate func textAttributes() -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: fontForCurrent(),
            .foregroundColor: textColor()
        ]
        if inlineCode {
            attributes[.backgroundColor] = style.codeBG
        }
        if strike {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attributes[.strikethroughColor] = style.muted
        }
        if let linkURL {
            attributes[.link] = linkURL
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            attributes[.foregroundColor] = style.accent
        }
        return attributes
    }

    private func textColor() -> NSColor {
        if inlineCode { return style.codeFG }
        if linkURL != nil { return style.accent }
        if headingLevel == 6 || quoteDepth > 0 { return style.muted }
        return style.foreground
    }

    private func fontForCurrent() -> NSFont {
        let size: CGFloat
        let name: String
        let mono: Bool
        if inlineCode {
            size = style.bodySize * 0.9
            name = style.monoName
            mono = true
        } else if headingLevel > 0 {
            size = style.headingSize(headingLevel)
            name = style.headingName
            mono = false
        } else {
            size = style.bodySize
            name = style.bodyName
            mono = false
        }
        var font = Self.makeFont(name: name, size: size, mono: mono)
        var applied = traits
        if headingLevel > 0 && !inlineCode {
            applied.insert(.boldFontMask)
        }
        if !applied.isEmpty {
            font = NSFontManager.shared.convert(font, toHaveTrait: applied)
        }
        return font
    }

    private static func makeFont(name: String, size: CGFloat, mono: Bool) -> NSFont {
        if name == "-apple-system" {
            return mono
                ? .monospacedSystemFont(ofSize: size, weight: .regular)
                : .systemFont(ofSize: size)
        }
        if let font = NSFont(name: name, size: size) { return font }
        return mono
            ? .monospacedSystemFont(ofSize: size, weight: .regular)
            : .systemFont(ofSize: size)
    }

    private func resolve(_ source: String) -> URL? {
        if let url = URL(string: source), url.scheme == "file" { return url }
        if source.hasPrefix("/") { return URL(fileURLWithPath: source) }
        if source.hasPrefix("http://") || source.hasPrefix("https://") { return nil }
        return style.baseURL?.appendingPathComponent(source)
    }

    private static func stripTags(_ raw: String) -> String {
        var out = ""
        var inTag = false
        for character in raw {
            if character == "<" { inTag = true; continue }
            if character == ">" { inTag = false; continue }
            if !inTag { out.append(character) }
        }
        return out
    }
}

// MARK: - Pano

enum DocumentClipboard {

    static func copyRichText(_ text: NSAttributedString) throws {
        let rtf = try MarkdownRichText.rtfData(text)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.rtf, .string], owner: nil)
        pasteboard.setData(rtf, forType: .rtf)
        pasteboard.setString(text.string, forType: .string)
    }

    /// Duz yapistirma HTML kaynagini, HTML isteyen uygulamalar da ayni belgeyi alir.
    static func copyHTML(_ html: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.html, .string], owner: nil)
        pasteboard.setString(html, forType: .html)
        pasteboard.setString(html, forType: .string)
    }
}

// MARK: - PDF

/// Yazdirma panelini, onizleme acik olmasa da calisacak sekilde ayri bir
/// web gorunumunde acar. Editor modunda onizleme hiyerarside yoktur.
@MainActor
final class PreviewPrintSession: NSObject, ObservableObject, WKNavigationDelegate {

    private var webView: WKWebView?
    private var window: NSWindow?

    func print(html: String, baseURL: URL?) {
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 720, height: 900))
        webView.navigationDelegate = self
        let window = NSWindow(contentRect: webView.frame, styleMask: [.borderless],
                              backing: .buffered, defer: true)
        window.contentView = webView
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.orderBack(nil)
        self.webView = webView
        self.window = window
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        release()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        release()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let info = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        info.topMargin = 36
        info.bottomMargin = 36
        info.leftMargin = 36
        info.rightMargin = 36
        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
        release()
    }

    private func release() {
        webView?.navigationDelegate = nil
        webView = nil
        window?.orderOut(nil)
        window = nil
    }
}

/// Onizlemenin temasini koruyarak cok sayfali PDF yazar.
/// Yazdirma paneli acilmaz; kayit yeri cagiranin save panelinden gelir.
@MainActor
final class PreviewPDFWriter: NSObject, WKNavigationDelegate {

    private var webView: WKWebView?
    private var window: NSWindow?
    private var destination: URL?
    private var continuation: CheckedContinuation<Void, Error>?
    private var finished = false

    func write(html: String, baseURL: URL?, to url: URL) async throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation
            self.destination = url

            let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 720, height: 900))
            webView.navigationDelegate = self
            let window = NSWindow(contentRect: webView.frame, styleMask: [.borderless],
                                  backing: .buffered, defer: true)
            window.contentView = webView
            window.isReleasedWhenClosed = false
            window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
            window.orderBack(nil)

            self.webView = webView
            self.window = window
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = destination else {
            finish(.failure(DocumentExportError.failed))
            return
        }
        let info = NSPrintInfo()
        info.paperSize = NSSize(width: 595.28, height: 841.89)
        info.topMargin = 36
        info.bottomMargin = 36
        info.leftMargin = 36
        info.rightMargin = 36
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = true
        info.isVerticallyCentered = false
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url

        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        let wrote = operation.run()
        finish(wrote ? .success(()) : .failure(DocumentExportError.failed))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<Void, Error>) {
        guard !finished else { return }
        finished = true
        continuation?.resume(with: result)
        continuation = nil
        webView?.navigationDelegate = nil
        window?.orderOut(nil)
        webView = nil
        window = nil
        destination = nil
    }
}
