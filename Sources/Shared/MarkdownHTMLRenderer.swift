import Foundation
import Markdown

/// GitHub Flavored Markdown -> HTML.
/// apple/swift-markdown (cmark-gfm) uzerine yazilmis bir MarkupVisitor.
struct MarkdownHTMLRenderer: MarkupVisitor {

    typealias Result = String

    static func render(_ markdown: String) -> String {
        let document = Document(parsing: markdown, options: [.parseBlockDirectives])
        var renderer = MarkdownHTMLRenderer()
        return renderer.visit(document)
    }

    // MARK: - Yardimcilar

    private func children(of markup: Markup) -> String {
        var out = ""
        for child in markup.children {
            var copy = self
            out += copy.visit(child)
        }
        return out
    }

    private static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(ch)
            }
        }
        return out
    }

    private static func slug(_ s: String) -> String {
        let lowered = s.lowercased()
        let allowed = lowered.map { ch -> Character in
            if ch.isLetter || ch.isNumber { return ch }
            if ch == " " || ch == "-" || ch == "_" { return "-" }
            return "-"
        }
        return String(allowed)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
    }

    // MARK: - Varsayilan

    mutating func defaultVisit(_ markup: Markup) -> String {
        children(of: markup)
    }

    // MARK: - Blok ogeleri

    mutating func visitDocument(_ document: Document) -> String {
        children(of: document)
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        // Liste icindeki tek paragraflar <p> almasin diye kontrol
        if let item = paragraph.parent as? ListItem, item.childCount == 1 {
            return children(of: paragraph)
        }
        return "<p>\(children(of: paragraph))</p>\n"
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let inner = children(of: heading)
        let id = Self.slug(heading.plainText)
        return "<h\(heading.level) id=\"\(id)\">\(inner)</h\(heading.level)>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        "<blockquote>\n\(children(of: blockQuote))</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let lang = codeBlock.language.map { " class=\"language-\(Self.escape($0))\"" } ?? ""
        return "<pre><code\(lang)>\(Self.escape(codeBlock.code))</code></pre>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        html.rawHTML
    }

    mutating func visitUnorderedList(_ list: UnorderedList) -> String {
        "<ul>\n\(children(of: list))</ul>\n"
    }

    mutating func visitOrderedList(_ list: OrderedList) -> String {
        let start = list.startIndex == 1 ? "" : " start=\"\(list.startIndex)\""
        return "<ol\(start)>\n\(children(of: list))</ol>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        let inner = children(of: listItem)
        if let checkbox = listItem.checkbox {
            let checked = checkbox == .checked ? " checked" : ""
            return "<li class=\"task\"><input type=\"checkbox\" disabled\(checked)>\(inner)</li>\n"
        }
        return "<li>\(inner)</li>\n"
    }

    // MARK: - Satir ici ogeler

    mutating func visitText(_ text: Text) -> String {
        Self.escape(text.string)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        "<em>\(children(of: emphasis))</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        "<strong>\(children(of: strong))</strong>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        "<del>\(children(of: strikethrough))</del>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(Self.escape(inlineCode.code))</code>"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        inlineHTML.rawHTML
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br>\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\n"
    }

    mutating func visitLink(_ link: Link) -> String {
        let dest = Self.escape(link.destination ?? "")
        let title = link.title.map { " title=\"\(Self.escape($0))\"" } ?? ""
        let external = dest.hasPrefix("http") ? " target=\"_blank\" rel=\"noopener\"" : ""
        return "<a href=\"\(dest)\"\(title)\(external)>\(children(of: link))</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let src = Self.escape(image.source ?? "")
        let alt = Self.escape(image.plainText)
        let title = image.title.map { " title=\"\(Self.escape($0))\"" } ?? ""
        return "<img src=\"\(src)\" alt=\"\(alt)\"\(title)>"
    }

    mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> String {
        "<code>\(Self.escape(symbolLink.destination ?? ""))</code>"
    }

    // MARK: - Tablolar

    mutating func visitTable(_ table: Table) -> String {
        var out = "<table>\n<thead>\n"
        out += renderRow(table.head, alignments: table.columnAlignments, cellTag: "th")
        out += "</thead>\n<tbody>\n"
        for row in table.body.rows {
            out += renderRow(row, alignments: table.columnAlignments, cellTag: "td")
        }
        out += "</tbody>\n</table>\n"
        return out
    }

    private func renderRow(_ row: Markup, alignments: [Table.ColumnAlignment?], cellTag: String) -> String {
        var out = "<tr>\n"
        var column = 0
        for child in row.children {
            guard let cell = child as? Table.Cell else { continue }
            let align = column < alignments.count ? alignments[column] : nil
            let style: String
            switch align {
            case .left:   style = " style=\"text-align:left\""
            case .center: style = " style=\"text-align:center\""
            case .right:  style = " style=\"text-align:right\""
            default:      style = ""
            }
            let span = cell.colspan > 1 ? " colspan=\"\(cell.colspan)\"" : ""
            var copy = self
            let inner = cell.children.map { c -> String in
                var v = copy
                return v.visit(c)
            }.joined()
            out += "<\(cellTag)\(style)\(span)>\(inner)</\(cellTag)>\n"
            column += Int(cell.colspan)
        }
        out += "</tr>\n"
        return out
    }

    // MARK: - Blok direktifleri (bilinmeyenler duz metin olarak)

    mutating func visitBlockDirective(_ blockDirective: BlockDirective) -> String {
        children(of: blockDirective)
    }
}
