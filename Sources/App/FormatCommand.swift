import AppKit

enum FormatCommand: Equatable {
    case bold, italic, strikethrough, inlineCode
    case heading(Int)          // 0 = baslik isaretini kaldir
    case bulletList, numberedList, taskList
    case blockQuote, codeBlock
    case link, image, horizontalRule, table
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

/// SwiftUI tarafi ile NSTextView arasindaki koprü.
final class EditorController: ObservableObject {
    weak var textView: NSTextView?

    func apply(_ command: FormatCommand) {
        guard let tv = textView else { NSSound.beep(); return }

        switch command {
        case .bold:          wrap(tv, "**")
        case .italic:        wrap(tv, "*")
        case .strikethrough: wrap(tv, "~~")
        case .inlineCode:    wrap(tv, "`")
        case .heading(let level):     prefixLines(tv) { _ in level == 0 ? "" : String(repeating: "#", count: level) + " " } stripping: { line in
                                          Self.strip(line, pattern: "^#{1,6}\\s+")
                                      }
        case .bulletList:    prefixLines(tv) { _ in "- " } stripping: { Self.strip($0, pattern: "^\\s*([-*+]|\\d+\\.)\\s+") }
        case .taskList:      prefixLines(tv) { _ in "- [ ] " } stripping: { Self.strip($0, pattern: "^\\s*([-*+]\\s+(\\[[ xX]\\]\\s+)?|\\d+\\.\\s+)") }
        case .numberedList:  prefixLines(tv) { i in "\(i + 1). " } stripping: { Self.strip($0, pattern: "^\\s*([-*+]|\\d+\\.)\\s+") }
        case .blockQuote:    prefixLines(tv) { _ in "> " } stripping: { Self.strip($0, pattern: "^>\\s?") }
        case .codeBlock:     surroundBlock(tv, open: "```\n", close: "\n```")
        case .horizontalRule: insertBlock(tv, "\n---\n")
        case .link:          insertLink(tv)
        case .image:         insertImage(tv)
        case .table:         insertBlock(tv, Self.tableTemplate)
        }
    }

    // MARK: - Temel islemler

    private func replace(_ tv: NSTextView, range: NSRange, with string: String, select: NSRange?) {
        guard tv.shouldChangeText(in: range, replacementString: string) else { return }
        tv.textStorage?.replaceCharacters(in: range, with: string)
        tv.didChangeText()
        if let select { tv.setSelectedRange(select) }
    }

    /// Secimi verilen isaretleyici ile sarar; zaten sarilmissa kaldirir (toggle).
    private func wrap(_ tv: NSTextView, _ marker: String) {
        let ns = tv.string as NSString
        var range = tv.selectedRange()
        if range.length == 0 { range = wordRange(in: ns, at: range.location) }

        let selected = ns.substring(with: range)
        let m = marker.count

        // Icten sarilmis mi?
        if selected.hasPrefix(marker), selected.hasSuffix(marker), selected.count >= m * 2 {
            let inner = String(selected.dropFirst(m).dropLast(m))
            replace(tv, range: range, with: inner,
                    select: NSRange(location: range.location, length: (inner as NSString).length))
            return
        }
        // Distan sarilmis mi?
        let outer = NSRange(location: max(0, range.location - m),
                            length: range.length + m * 2)
        if outer.location >= 0, NSMaxRange(outer) <= ns.length,
           ns.substring(with: outer).hasPrefix(marker), ns.substring(with: outer).hasSuffix(marker) {
            replace(tv, range: outer, with: selected,
                    select: NSRange(location: outer.location, length: range.length))
            return
        }

        let wrapped = marker + selected + marker
        replace(tv, range: range, with: wrapped,
                select: NSRange(location: range.location + m, length: range.length))
    }

    private func wordRange(in ns: NSString, at location: Int) -> NSRange {
        guard ns.length > 0 else { return NSRange(location: location, length: 0) }
        let sep = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        var start = location, end = location
        while start > 0 {
            let ch = ns.substring(with: NSRange(location: start - 1, length: 1))
            if ch.rangeOfCharacter(from: sep) != nil { break }
            start -= 1
        }
        while end < ns.length {
            let ch = ns.substring(with: NSRange(location: end, length: 1))
            if ch.rangeOfCharacter(from: sep) != nil { break }
            end += 1
        }
        return NSRange(location: start, length: end - start)
    }

    /// Secili satirlarin basina prefix ekler; zaten varsa kaldirir.
    private func prefixLines(_ tv: NSTextView,
                             _ prefix: @escaping (Int) -> String,
                             stripping strip: (String) -> String?) {
        let ns = tv.string as NSString
        let lineRange = ns.lineRange(for: tv.selectedRange())
        let block = ns.substring(with: lineRange)
        let hadTrailingNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if hadTrailingNewline { lines.removeLast() }

        // Tum satirlarda ayni prefix varsa toggle-off
        let allPrefixed = lines.allSatisfy { !$0.isEmpty && strip($0) != nil }

        var result: [String] = []
        for (i, line) in lines.enumerated() {
            if allPrefixed, let stripped = strip(line) {
                result.append(stripped)
            } else {
                let cleaned = strip(line) ?? line
                result.append(prefix(i) + cleaned)
            }
        }
        var newText = result.joined(separator: "\n")
        if hadTrailingNewline { newText += "\n" }
        replace(tv, range: lineRange, with: newText,
                select: NSRange(location: lineRange.location, length: (newText as NSString).length))
    }

    private static func strip(_ line: String, pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = line as NSString
        guard let m = re.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
              m.range.location == 0, m.range.length > 0 else { return nil }
        return ns.substring(from: m.range.length)
    }

    private func surroundBlock(_ tv: NSTextView, open: String, close: String) {
        let range = tv.selectedRange()
        let selected = (tv.string as NSString).substring(with: range)
        let text = open + selected + close
        replace(tv, range: range, with: text,
                select: NSRange(location: range.location + (open as NSString).length,
                                length: (selected as NSString).length))
    }

    private func insertBlock(_ tv: NSTextView, _ text: String) {
        let range = tv.selectedRange()
        replace(tv, range: range, with: text,
                select: NSRange(location: range.location + (text as NSString).length, length: 0))
    }

    private func insertLink(_ tv: NSTextView) {
        let range = tv.selectedRange()
        let selected = (tv.string as NSString).substring(with: range)
        let label = selected.isEmpty ? String(localized: "link text") : selected
        let text = "[\(label)](https://)"
        replace(tv, range: range, with: text,
                select: NSRange(location: range.location + (label as NSString).length + 3, length: 8))
    }

    private func insertImage(_ tv: NSTextView) {
        let range = tv.selectedRange()
        let text = "![" + String(localized: "description") + "](file.png)"
        replace(tv, range: range, with: text,
                select: NSRange(location: range.location + 12, length: 9))
    }

    private static let tableTemplate = """

    | Column A | Column B |
    |----------|----------|
    | value    | value    |

    """
}
