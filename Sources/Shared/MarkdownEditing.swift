import Foundation

/// Bir metin değişiminin UTF-16 aralığı. NSTextView ve UITextView aynı birimi kullanır.
struct TextMutation: Equatable {
    var range: NSRange
    var replacement: String
    var selection: NSRange

    var changesText: Bool { range.length > 0 || !replacement.isEmpty }
}

/// Biçim komutlarını düz metin üzerinde uygular. Platformdan bağımsızdır;
/// geri almayı metin görünümü kaydeder.
enum MarkdownEditing {

    static func mutation(_ command: FormatCommand, in text: String, selection: NSRange) -> TextMutation {
        let ns = text as NSString
        let range = clamp(selection, ns.length)
        switch command {
        case .bold:          return wrap(text, selection: range, marker: "**")
        case .italic:        return wrap(text, selection: range, marker: "*")
        case .boldItalic:    return wrap(text, selection: range, marker: "***")
        case .strikethrough: return wrap(text, selection: range, marker: "~~")
        case .inlineCode:    return wrap(text, selection: range, marker: "`")
        case .heading(let level):
            let mark = level == 0 ? "" : String(repeating: "#", count: min(6, max(1, level))) + " "
            return prefixLines(text, selection: range, prefix: { _ in mark },
                               stripping: "^#{1,6}\\s+")
        case .bulletList:
            return prefixLines(text, selection: range, prefix: { _ in "- " },
                               stripping: "^\\s*([-*+]|\\d+\\.)\\s+")
        case .taskList:
            return prefixLines(text, selection: range, prefix: { _ in "- [ ] " },
                               stripping: "^\\s*([-*+]\\s+(\\[[ xX]\\]\\s+)?|\\d+\\.\\s+)")
        case .numberedList:
            return prefixLines(text, selection: range, prefix: { i in "\(i + 1). " },
                               stripping: "^\\s*([-*+]|\\d+\\.)\\s+")
        case .toggleTask:
            return mapLines(text, selection: range, toggleTaskLine)
        case .indent:
            return mapLines(text, selection: range) { "  " + $0 }
        case .outdent:
            return mapLines(text, selection: range, outdentLine)
        case .blockQuote:
            return prefixLines(text, selection: range, prefix: { _ in "> " },
                               stripping: "^>\\s?")
        case .codeBlock(let language):
            let clean = (language ?? "").filter { $0.isLetter || $0.isNumber || "+-#.".contains($0) }
            let open = clean.isEmpty ? "```\n" : "```\(clean)\n"
            return surround(text, selection: range, open: open, close: "\n```")
        case .alert(let kind):
            return alert(kind, text: text, selection: range)
        case .link:
            return link(text, selection: range)
        case .image:
            return image(text, selection: range)
        case .autolink:
            return autolink(text, selection: range)
        case .referenceLink:
            return referenceLink(text, selection: range)
        case .horizontalRule:
            return insert(text, selection: range, block: "\n---\n")
        case .hardLineBreak:
            let end = NSMaxRange(range)
            return TextMutation(range: NSRange(location: end, length: 0),
                                replacement: "\\\n",
                                selection: NSRange(location: end + 2, length: 0))
        case .table(let align):
            return insert(text, selection: range, block: tableTemplate(align))
        case .footnote:
            return footnote(text, selection: range)
        case .inlineMath:
            if insideMath(text, range.location) {
                return TextMutation(range: NSRange(location: range.location, length: 0),
                                    replacement: "", selection: range)
            }
            return wrap(text, selection: range, marker: "$")
        case .formula(let formula):
            return insertSnippet(formula.piece, display: true, text: text, selection: range)
        case .symbol(let latex):
            let len = (latex as NSString).length
            let piece = LatexPiece(source: latex, selection: NSRange(location: len, length: 0))
            return insertSnippet(piece, display: false, text: text, selection: range)
        }
    }

    /// Return tuşu bir liste maddesindeyse devam metnini üretir.
    static func listContinuation(in text: String, replacing range: NSRange, with replacement: String) -> TextMutation? {
        guard replacement == "\n" else { return nil }
        let ns = text as NSString
        let loc = min(max(0, range.location), ns.length)
        let lineRange = ns.lineRange(for: NSRange(location: loc, length: 0))
        let line = ns.substring(with: lineRange).trimmingCharacters(in: .newlines)
        guard let re = try? NSRegularExpression(pattern: "^(\\s*)([-*+]\\s(?:\\[[ xX]\\]\\s)?|(\\d+)\\.\\s)"),
              let m = re.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
        else { return nil }

        let lineNS = line as NSString
        let content = lineNS.substring(from: m.range.length)
        let indent = lineNS.substring(with: m.range(at: 1))
        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            return TextMutation(range: lineRange, replacement: "",
                                selection: NSRange(location: lineRange.location, length: 0))
        }

        var marker = lineNS.substring(with: m.range(at: 2))
        if m.range(at: 3).location != NSNotFound,
           let n = Int(lineNS.substring(with: m.range(at: 3))) {
            marker = "\(n + 1). "
        }
        marker = marker.replacingOccurrences(of: "[x] ", with: "[ ] ")
                       .replacingOccurrences(of: "[X] ", with: "[ ] ")
        let insert = "\n" + indent + marker
        let caret = range.location + (insert as NSString).length
        return TextMutation(range: range, replacement: insert,
                            selection: NSRange(location: caret, length: 0))
    }

    /// İmleç bir `$…$` veya `$$…$$` bölgesinin içinde mi?
    static func insideMath(_ text: String, _ location: Int) -> Bool {
        let ns = text as NSString
        let loc = min(max(0, location), ns.length)
        let prefix = ns.substring(to: loc) as NSString
        var display = 0
        var search = NSRange(location: 0, length: prefix.length)
        while search.length > 0 {
            let found = prefix.range(of: "$$", options: [], range: search)
            if found.location == NSNotFound { break }
            display += 1
            let next = found.location + found.length
            if next >= prefix.length { break }
            search = NSRange(location: next, length: prefix.length - next)
        }
        if display % 2 == 1 { return true }

        let lineRange = ns.lineRange(for: NSRange(location: loc, length: 0))
        let linePrefixLen = loc - lineRange.location
        guard linePrefixLen > 0 else { return false }
        let linePrefix = ns.substring(with: NSRange(location: lineRange.location, length: linePrefixLen))
        let stripped = linePrefix.replacingOccurrences(of: "$$", with: "")
        let dollars = stripped.reduce(0) { $1 == "$" ? $0 + 1 : $0 }
        return dollars % 2 == 1
    }

    // MARK: - Aralık

    static func clamp(_ range: NSRange, _ length: Int) -> NSRange {
        if length <= 0 { return NSRange(location: 0, length: 0) }
        let loc = min(max(0, range.location), length)
        let len = min(max(0, range.length), length - loc)
        return NSRange(location: loc, length: len)
    }

    // MARK: - Sarma

    private static func wrap(_ text: String, selection: NSRange, marker: String) -> TextMutation {
        let ns = text as NSString
        var range = clamp(selection, ns.length)
        if range.length == 0 { range = wordRange(in: ns, at: range.location) }

        let selected = ns.substring(with: range)
        let m = marker.count

        if selected.hasPrefix(marker), selected.hasSuffix(marker), selected.count >= m * 2 {
            let inner = String(selected.dropFirst(m).dropLast(m))
            return TextMutation(range: range, replacement: inner,
                                selection: NSRange(location: range.location, length: (inner as NSString).length))
        }

        let outer = NSRange(location: max(0, range.location - m), length: range.length + m * 2)
        if outer.location >= 0, NSMaxRange(outer) <= ns.length,
           ns.substring(with: outer).hasPrefix(marker), ns.substring(with: outer).hasSuffix(marker) {
            return TextMutation(range: outer, replacement: selected,
                                selection: NSRange(location: outer.location, length: range.length))
        }

        let wrapped = marker + selected + marker
        return TextMutation(range: range, replacement: wrapped,
                            selection: NSRange(location: range.location + m, length: range.length))
    }

    private static func wordRange(in ns: NSString, at location: Int) -> NSRange {
        guard ns.length > 0 else { return NSRange(location: location, length: 0) }
        let sep = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        var start = min(location, ns.length)
        var end = start
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

    // MARK: - Satırlar

    private static func prefixLines(_ text: String, selection: NSRange,
                                    prefix: (Int) -> String, stripping pattern: String) -> TextMutation {
        rewriteLines(text, selection: selection) { lines in
            let allPrefixed = lines.allSatisfy { !$0.isEmpty && strip($0, pattern: pattern) != nil }
            return lines.enumerated().map { i, line in
                if allPrefixed, let stripped = strip(line, pattern: pattern) { return stripped }
                return prefix(i) + (strip(line, pattern: pattern) ?? line)
            }
        }
    }

    private static func mapLines(_ text: String, selection: NSRange, _ transform: (String) -> String) -> TextMutation {
        rewriteLines(text, selection: selection) { $0.map(transform) }
    }

    private static func rewriteLines(_ text: String, selection: NSRange,
                                     _ transform: ([String]) -> [String]) -> TextMutation {
        let ns = text as NSString
        let range = clamp(selection, ns.length)
        let lineRange = ns.lineRange(for: range)
        let block = ns.substring(with: lineRange)
        let hadTrailingNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if hadTrailingNewline { lines.removeLast() }
        if lines.isEmpty { lines = [""] }

        var newText = transform(lines).joined(separator: "\n")
        if hadTrailingNewline { newText += "\n" }
        return TextMutation(range: lineRange, replacement: newText,
                            selection: NSRange(location: lineRange.location,
                                               length: (newText as NSString).length))
    }

    private static func strip(_ line: String, pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = line as NSString
        guard let m = re.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)),
              m.range.location == 0, m.range.length > 0 else { return nil }
        return ns.substring(from: m.range.length)
    }

    private static func outdentLine(_ line: String) -> String {
        if line.hasPrefix("\t") { return String(line.dropFirst()) }
        if line.hasPrefix("  ") { return String(line.dropFirst(2)) }
        if line.hasPrefix(" ") { return String(line.dropFirst()) }
        return line
    }

    private static let taskLine = try! NSRegularExpression(pattern: "^(\\s*(?:[-*+]|\\d+\\.)\\s+)\\[([ xX])\\](.*)$")
    private static let listLine = try! NSRegularExpression(pattern: "^(\\s*)([-*+]|\\d+\\.)\\s+(.*)$")

    private static func toggleTaskLine(_ line: String) -> String {
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)
        if let m = taskLine.firstMatch(in: line, range: full) {
            let flipped = ns.substring(with: m.range(at: 2)) == " " ? "x" : " "
            return ns.substring(with: m.range(at: 1)) + "[" + flipped + "]" + ns.substring(with: m.range(at: 3))
        }
        if let m = listLine.firstMatch(in: line, range: full) {
            return ns.substring(with: m.range(at: 1)) + ns.substring(with: m.range(at: 2))
                + " [ ] " + ns.substring(with: m.range(at: 3))
        }
        if line.isEmpty { return "- [ ] " }
        return "- [ ] " + line
    }

    // MARK: - Bloklar

    private static func surround(_ text: String, selection: NSRange, open: String, close: String) -> TextMutation {
        let ns = text as NSString
        let range = clamp(selection, ns.length)
        let selected = ns.substring(with: range)
        let replacement = open + selected + close
        return TextMutation(range: range, replacement: replacement,
                            selection: NSRange(location: range.location + (open as NSString).length,
                                               length: (selected as NSString).length))
    }

    private static func insert(_ text: String, selection: NSRange, block: String) -> TextMutation {
        let range = clamp(selection, (text as NSString).length)
        return TextMutation(range: range, replacement: block,
                            selection: NSRange(location: range.location + (block as NSString).length, length: 0))
    }

    private static func alert(_ kind: AlertKind, text: String, selection: NSRange) -> TextMutation {
        let ns = text as NSString
        let range = clamp(selection, ns.length)
        let lineRange = ns.lineRange(for: range)
        let block = ns.substring(with: lineRange)
        let hadTrailingNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if hadTrailingNewline { lines.removeLast() }
        if lines.isEmpty { lines = [""] }

        let marker = "> [!\(kind.rawValue)]"
        func unquote(_ line: String) -> String {
            if line.hasPrefix("> ") { return String(line.dropFirst(2)) }
            if line.hasPrefix(">") { return String(line.dropFirst()) }
            return line
        }

        let already = unquote(lines[0]) == "[!\(kind.rawValue)]" || lines[0] == marker
        let body: [String]
        if already {
            body = lines.dropFirst().map(unquote)
        } else {
            body = [marker] + lines.map { "> " + unquote($0) }
        }
        let produced = body.isEmpty ? [""] : body
        var newText = produced.joined(separator: "\n")
        if hadTrailingNewline { newText += "\n" }
        let caretBase = lineRange.location + (newText as NSString).length - (hadTrailingNewline ? 1 : 0)
        return TextMutation(range: lineRange, replacement: newText,
                            selection: NSRange(location: max(lineRange.location, caretBase), length: 0))
    }

    // MARK: - Bağlantı ve dipnot

    private static func link(_ text: String, selection: NSRange) -> TextMutation {
        let ns = text as NSString
        let range = clamp(selection, ns.length)
        let selected = ns.substring(with: range)
        let label = selected.isEmpty ? String(localized: "link text") : selected
        let replacement = "[\(label)](https://)"
        return TextMutation(range: range, replacement: replacement,
                            selection: NSRange(location: range.location + (label as NSString).length + 3, length: 8))
    }

    private static func image(_ text: String, selection: NSRange) -> TextMutation {
        let range = clamp(selection, (text as NSString).length)
        let alt = String(localized: "description")
        let replacement = "![\(alt)](file.png)"
        let urlStart = 2 + (alt as NSString).length + 2
        return TextMutation(range: range, replacement: replacement,
                            selection: NSRange(location: range.location + urlStart, length: 8))
    }

    private static func autolink(_ text: String, selection: NSRange) -> TextMutation {
        let ns = text as NSString
        let range = clamp(selection, ns.length)
        let selected = ns.substring(with: range)
        if selected.isEmpty {
            return TextMutation(range: range, replacement: "<https://>",
                                selection: NSRange(location: range.location + 1, length: 8))
        }
        return TextMutation(range: range, replacement: "<\(selected)>",
                            selection: NSRange(location: range.location + 1, length: range.length))
    }

    private static func referenceLink(_ text: String, selection: NSRange) -> TextMutation {
        let ns = text as NSString
        let range = clamp(selection, ns.length)
        let selected = ns.substring(with: range)
        let label = selected.isEmpty ? String(localized: "link text") : selected
        let id = referenceID(for: label, in: text)
        let marker = "[\(label)][\(id)]"
        let tail = "\n\n[\(id)]: "
        let url = "https://"
        let suffix = ns.substring(from: NSMaxRange(range))
        let replacement = marker + suffix + tail + url
        let urlAt = range.location + (marker as NSString).length + (suffix as NSString).length + (tail as NSString).length
        return TextMutation(range: NSRange(location: range.location, length: ns.length - range.location),
                            replacement: replacement,
                            selection: NSRange(location: urlAt, length: (url as NSString).length))
    }

    private static func referenceID(for label: String, in text: String) -> String {
        let chars = label.lowercased().map { ch -> Character in
            ch.isLetter || ch.isNumber ? ch : "-"
        }
        var base = String(chars).split(separator: "-").joined(separator: "-")
        if base.isEmpty { base = "ref" }
        var id = base
        var n = 2
        while text.contains("[\(id)]:") && n < 1000 {
            id = "\(base)-\(n)"
            n += 1
        }
        return id
    }

    private static func footnote(_ text: String, selection: NSRange) -> TextMutation {
        let ns = text as NSString
        let range = clamp(selection, ns.length)
        let n = nextFootnote(in: text)
        let marker = "[^\(n)]"
        let placeholder = String(localized: "note")
        let tail = "\n\n[^\(n)]: "
        let suffix = ns.substring(from: NSMaxRange(range))
        let selected = ns.substring(with: range)
        let replacement = marker + selected + suffix + tail + placeholder
        let noteAt = range.location + (marker as NSString).length + (selected as NSString).length
            + (suffix as NSString).length + (tail as NSString).length
        return TextMutation(range: NSRange(location: range.location, length: ns.length - range.location),
                            replacement: replacement,
                            selection: NSRange(location: noteAt, length: (placeholder as NSString).length))
    }

    private static func nextFootnote(in text: String) -> Int {
        guard let re = try? NSRegularExpression(pattern: "\\[\\^(\\d+)\\]") else { return 1 }
        let ns = text as NSString
        var maxN = 0
        re.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match else { return }
            if let n = Int(ns.substring(with: match.range(at: 1))) { maxN = max(maxN, n) }
        }
        return maxN + 1
    }

    // MARK: - Matematik

    private static func insertSnippet(_ piece: LatexPiece, display: Bool,
                                      text: String, selection: NSRange) -> TextMutation {
        let ns = text as NSString
        let range = clamp(selection, ns.length)
        if insideMath(text, range.location) {
            return TextMutation(range: range, replacement: piece.source,
                                selection: NSRange(location: range.location + piece.selection.location,
                                                   length: piece.selection.length))
        }
        if !display {
            let wrapped = "$\(piece.source)$"
            return TextMutation(range: range, replacement: wrapped,
                                selection: NSRange(location: range.location + 1 + piece.selection.location,
                                                   length: piece.selection.length))
        }
        let atLineStart = range.location == 0 || ns.substring(with: NSRange(location: range.location - 1, length: 1)) == "\n"
        let prefix = atLineStart ? "$$\n" : "\n$$\n"
        let replacement = prefix + piece.source + "\n$$\n"
        return TextMutation(range: range, replacement: replacement,
                            selection: NSRange(location: range.location + (prefix as NSString).length + piece.selection.location,
                                               length: piece.selection.length))
    }

    private static func tableTemplate(_ align: TableAlign) -> String {
        let rule: String
        switch align {
        case .plain:  rule = "|----------|----------|"
        case .left:   rule = "|:---------|:---------|"
        case .center: rule = "|:--------:|:--------:|"
        case .right:  rule = "|---------:|---------:|"
        }
        return """

        | Column A | Column B |
        \(rule)
        | value    | value    |

        """
    }
}
