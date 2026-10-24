import Foundation

/// Menüden uygulanan bir Markdown düzenlemesi.
///
/// macOS menü çubuğu, biçim çubuğu ve iOS araç çubuğu aynı komutları kullanır.
enum FormatCommand: Equatable {
    case bold, italic, boldItalic, strikethrough, inlineCode
    case heading(Int)          // 0 = başlık işaretini kaldır
    case bulletList, numberedList, taskList, toggleTask
    case indent, outdent
    case blockQuote
    case codeBlock(String?)
    case alert(AlertKind)
    case link, image, autolink, referenceLink
    case horizontalRule, hardLineBreak
    case table(TableAlign)
    case footnote
    case inlineMath
    case formula(Formula)
    case symbol(String)

    func post() {
        NotificationCenter.default.post(name: .markPadFormat, object: self)
    }
}

enum TableAlign: Equatable {
    case plain, left, center, right
}

/// GitHub uyarı kutusu. `> [!NOTE]` sözdizimi.
enum AlertKind: String, Equatable, CaseIterable {
    case note = "NOTE"
    case tip = "TIP"
    case important = "IMPORTANT"
    case warning = "WARNING"
    case caution = "CAUTION"

    var title: String {
        switch self {
        case .note: return String(localized: "Note")
        case .tip: return String(localized: "Tip")
        case .important: return String(localized: "Important")
        case .warning: return String(localized: "Warning")
        case .caution: return String(localized: "Caution")
        }
    }

    var cssClass: String { "mp-" + rawValue.lowercased() }
}

/// Menüye konan hazır LaTeX kalıpları. Seçilecek yer `«»` ile işaretlenir.
enum Formula: Equatable {
    case display
    case fraction
    case squareRoot
    case power
    case index
    case sum
    case integral
    case product
    case limit
    case matrix
    case cases
    case aligned

    var piece: LatexPiece {
        switch self {
        case .display:
            return LatexPiece.marked("«\(String(localized: "formula"))»")
        case .fraction:
            return LatexPiece.marked("\\frac{«a»}{b}")
        case .squareRoot:
            return LatexPiece.marked("\\sqrt{«x»}")
        case .power:
            return LatexPiece.marked("x^{«n»}")
        case .index:
            return LatexPiece.marked("x_{«i»}")
        case .sum:
            return LatexPiece.marked("\\sum_{«i=1»}^{n} a_i")
        case .integral:
            return LatexPiece.marked("\\int_{«a»}^{b} f(x)\\,dx")
        case .product:
            return LatexPiece.marked("\\prod_{«i=1»}^{n} a_i")
        case .limit:
            return LatexPiece.marked("\\lim_{«x» \\to \\infty} f(x)")
        case .matrix:
            return LatexPiece.marked("\\begin{pmatrix} «a» & b \\\\ c & d \\end{pmatrix}")
        case .cases:
            return LatexPiece.marked("\\begin{cases} «a» & x > 0 \\\\ b & x \\le 0 \\end{cases}")
        case .aligned:
            return LatexPiece.marked("\\begin{aligned} «a» &= b \\\\ c &= d \\end{aligned}")
        }
    }
}

/// Bir LaTeX parçasının metni ve parçanın içinde seçilecek aralık (UTF-16).
struct LatexPiece: Equatable {
    var source: String
    var selection: NSRange

    static func marked(_ pattern: String) -> LatexPiece {
        let ns = pattern as NSString
        let open = ns.range(of: "«")
        let close = ns.range(of: "»")
        guard open.location != NSNotFound, close.location != NSNotFound,
              close.location >= open.location + open.length else {
            return LatexPiece(source: pattern, selection: NSRange(location: ns.length, length: 0))
        }
        let selectedLen = close.location - (open.location + open.length)
        let selected = ns.substring(with: NSRange(location: open.location + open.length, length: selectedLen))
        let span = NSRange(location: open.location, length: close.location + close.length - open.location)
        let source = ns.replacingCharacters(in: span, with: selected)
        return LatexPiece(source: source, selection: NSRange(location: open.location,
                                                             length: (selected as NSString).length))
    }
}

enum ViewMode: String, CaseIterable, Identifiable {
    case editor, split, preview, compare
    var id: String { rawValue }
    var label: String {
        switch self {
        case .editor: return String(localized: "Editor")
        case .split: return String(localized: "Split")
        case .preview: return String(localized: "Preview")
        case .compare: return String(localized: "Compare")
        }
    }
    var symbol: String {
        switch self {
        case .editor: return "pencil"
        case .split: return "rectangle.split.2x1"
        case .preview: return "doc.richtext"
        case .compare: return "arrow.left.arrow.right"
        }
    }
}

extension Notification.Name {
    static let markPadFormat = Notification.Name("markPadFormat")
}
