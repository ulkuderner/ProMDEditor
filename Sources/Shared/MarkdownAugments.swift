import Foundation

struct FootnoteBlock {
    var number: Int
    var body: String
    var referenced: Bool
}

struct PreparedMarkdown {
    var markdown: String
    var replacements: [(token: String, html: String, block: Bool)]
    var footnotes: [FootnoteBlock]

    static let identity = PreparedMarkdown(markdown: "", replacements: [], footnotes: [])
}

/// CommonMark'ın tek başına bırakmadığı GitHub sözdizimini HTML'e çevirir:
/// `$` / `$$` matematiği, ` ```math ` çitleri ve `[^dipnot]`.
/// Kod bloklarının içine dokunmaz. Değiştirilen bölgeler ayrıştırıcıdan sonra
/// yerine konur; böylece LaTeX'teki `_` vurgu sanılmaz.
enum MarkdownAugments {

    static func prepare(_ input: String) -> PreparedMarkdown {
        let bank = Bank()
        var text = transformFences(input, bank: bank)
        text = maskInlineCode(text, bank: bank)
        text = replaceMath(text, bank: bank)
        var notes: [FootnoteBlock] = []
        if text.contains("[^") {
            let extracted = extractFootnotes(text, bank: bank)
            text = extracted.markdown
            notes = extracted.notes
        }
        text = bank.restoreCode(text)
        notes = notes.map {
            FootnoteBlock(number: $0.number, body: bank.restoreCode($0.body), referenced: $0.referenced)
        }
        return PreparedMarkdown(markdown: text, replacements: bank.replacements, footnotes: notes)
    }

    static func substituting(_ html: String, with prepared: PreparedMarkdown) -> String {
        var html = html
        for item in prepared.replacements.reversed() {
            if item.block {
                let wrappedNL = "<p>\(item.token)</p>\n"
                let wrapped = "<p>\(item.token)</p>"
                if html.contains(wrappedNL) {
                    html = html.replacingOccurrences(of: wrappedNL, with: item.html + "\n")
                    continue
                }
                if html.contains(wrapped) {
                    html = html.replacingOccurrences(of: wrapped, with: item.html)
                    continue
                }
            }
            html = html.replacingOccurrences(of: item.token, with: item.html)
        }
        return html
    }

    // MARK: - Banka

    private final class Bank {
        var replacements: [(token: String, html: String, block: Bool)] = []
        private var codes: [(token: String, text: String)] = []
        private var mathN = 0
        private var codeN = 0

        func math(html: String, block: Bool) -> String {
            let token = "MPMATHTOKEN\(mathN)END"
            mathN += 1
            replacements.append((token, html, block))
            return token
        }

        func footnote(_ html: String) -> String {
            let token = "MPFNTOKEN\(mathN)END"
            mathN += 1
            replacements.append((token, html, false))
            return token
        }

        func park(_ code: String) -> String {
            let token = "MPCODETOKEN\(codeN)END"
            codeN += 1
            codes.append((token, code))
            return token
        }

        func restoreCode(_ text: String) -> String {
            var text = text
            for item in codes.reversed() {
                text = text.replacingOccurrences(of: item.token, with: item.text)
            }
            return text
        }
    }

    // MARK: - Çitler

    private struct Fence {
        var marker: String
        var lang: String
    }

    private static func transformFences(_ text: String, bank: Bank) -> String {
        let ns = text as NSString
        var i = 0
        var out = ""
        while i < ns.length {
            let lineRange = ns.lineRange(for: NSRange(location: i, length: 0))
            let line = ns.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if let open = openingFence(trimmed) {
                if open.lang == "math" || open.lang == "latex" {
                    var j = NSMaxRange(lineRange)
                    var body = ""
                    var closed = false
                    while j < ns.length {
                        let lr = ns.lineRange(for: NSRange(location: j, length: 0))
                        let ln = ns.substring(with: lr)
                        let tr = ln.trimmingCharacters(in: .whitespacesAndNewlines)
                        if isClosingFence(tr, marker: open.marker) {
                            j = NSMaxRange(lr)
                            closed = true
                            break
                        }
                        body += ln
                        j = NSMaxRange(lr)
                    }
                    if closed {
                        let tex = body.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !tex.isEmpty {
                            out += bank.math(html: mathHTML(tex: tex, display: true), block: true) + "\n"
                        }
                        i = j
                        continue
                    }
                }
                var j = NSMaxRange(lineRange)
                var block = line
                var closed = false
                while j < ns.length {
                    let lr = ns.lineRange(for: NSRange(location: j, length: 0))
                    let ln = ns.substring(with: lr)
                    block += ln
                    j = NSMaxRange(lr)
                    if isClosingFence(ln.trimmingCharacters(in: .whitespacesAndNewlines), marker: open.marker) {
                        closed = true
                        break
                    }
                }
                if closed || block != line {
                    out += bank.park(block)
                    i = j
                    continue
                }
            }
            out += line
            i = NSMaxRange(lineRange)
        }
        return out
    }

    private static func openingFence(_ line: String) -> Fence? {
        guard line.hasPrefix("```") || line.hasPrefix("~~~") else { return nil }
        let marker = line.hasPrefix("```") ? "```" : "~~~"
        let rest = line.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
        let lang = rest.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map { String($0).lowercased() } ?? ""
        return Fence(marker: marker, lang: lang)
    }

    private static func isClosingFence(_ line: String, marker: String) -> Bool {
        guard line.count >= marker.count, let ch = marker.first else { return false }
        return line.allSatisfy { $0 == ch }
    }

    // MARK: - Satır içi kod

    private static func maskInlineCode(_ text: String, bank: Bank) -> String {
        let ns = text as NSString
        var result = ""
        var i = 0
        while i < ns.length {
            let ch = ns.substring(with: NSRange(location: i, length: 1))
            if ch == "`" {
                var n = 0
                while i + n < ns.length && ns.substring(with: NSRange(location: i + n, length: 1)) == "`" {
                    n += 1
                }
                var j = i + n
                var found = -1
                while j < ns.length {
                    let c = ns.substring(with: NSRange(location: j, length: 1))
                    if c == "\n" { break }
                    if c == "`" {
                        var m = 0
                        while j + m < ns.length && ns.substring(with: NSRange(location: j + m, length: 1)) == "`" {
                            m += 1
                        }
                        if m == n { found = j; break }
                        j += m
                        continue
                    }
                    j += 1
                }
                if found >= 0 {
                    let end = found + n
                    let span = ns.substring(with: NSRange(location: i, length: end - i))
                    result += bank.park(span)
                    i = end
                    continue
                }
            }
            result += ch
            i += 1
        }
        return result
    }

    // MARK: - Matematik

    private static func replaceMath(_ text: String, bank: Bank) -> String {
        guard text.contains("$") || text.contains("\\(") || text.contains("\\[") else { return text }
        var result = ""
        var i = text.startIndex
        while i < text.endIndex {
            let ch = text[i]
            if ch == "\\" {
                let next = text.index(after: i)
                if next < text.endIndex {
                    let n = text[next]
                    if n == "(" || n == "[" {
                        let close: Character = n == "(" ? ")" : "]"
                        let from = text.index(after: next)
                        if let end = closingEscaped(text, from: from, closer: close) {
                            let inner = String(text[from..<end])
                            let display = n == "["
                            if !inner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                result += bank.math(html: mathHTML(tex: inner, display: display), block: display)
                                i = text.index(end, offsetBy: 2)
                                continue
                            }
                        }
                    }
                }
                result.append(ch)
                i = text.index(after: i)
                if i < text.endIndex {
                    result.append(text[i])
                    i = text.index(after: i)
                }
                continue
            }
            if ch == "$" {
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == "$" {
                    let from = text.index(after: next)
                    if let end = closingDisplay(text, from: from) {
                        let inner = String(text[from..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !inner.isEmpty {
                            result += bank.math(html: mathHTML(tex: inner, display: true), block: true)
                            i = text.index(end, offsetBy: 2)
                            continue
                        }
                    }
                } else if let end = closingInlineDollar(text, from: next) {
                    let inner = String(text[next..<end])
                    if validInline(inner) {
                        result += bank.math(html: mathHTML(tex: inner, display: false), block: false)
                        i = text.index(after: end)
                        continue
                    }
                }
            }
            result.append(ch)
            i = text.index(after: i)
        }
        return result
    }

    private static func validInline(_ inner: String) -> Bool {
        guard !inner.isEmpty, !inner.contains("\n") else { return false }
        guard let first = inner.first, let last = inner.last else { return false }
        return !first.isWhitespace && !last.isWhitespace
    }

    private static func closingInlineDollar(_ text: String, from: String.Index) -> String.Index? {
        var i = from
        while i < text.endIndex {
            let c = text[i]
            if c == "\n" { return nil }
            if c == "\\" {
                i = text.index(after: i)
                if i < text.endIndex { i = text.index(after: i) }
                continue
            }
            if c == "$" {
                let n = text.index(after: i)
                if n < text.endIndex && text[n] == "$" { return nil }
                return i
            }
            i = text.index(after: i)
        }
        return nil
    }

    private static func closingDisplay(_ text: String, from: String.Index) -> String.Index? {
        var i = from
        while i < text.endIndex {
            if text[i] == "\\" {
                i = text.index(after: i)
                if i < text.endIndex { i = text.index(after: i) }
                continue
            }
            if text[i] == "$" {
                let n = text.index(after: i)
                if n < text.endIndex && text[n] == "$" { return i }
            }
            i = text.index(after: i)
        }
        return nil
    }

    private static func closingEscaped(_ text: String, from: String.Index, closer: Character) -> String.Index? {
        var i = from
        while i < text.endIndex {
            if text[i] == "\\" {
                let n = text.index(after: i)
                if n < text.endIndex && text[n] == closer { return i }
                i = n < text.endIndex ? text.index(after: n) : text.endIndex
                continue
            }
            i = text.index(after: i)
        }
        return nil
    }

    static func mathHTML(tex: String, display: Bool) -> String {
        let trimmed = tex.trimmingCharacters(in: .whitespacesAndNewlines)
        let attr = escape(trimmed).replacingOccurrences(of: "\n", with: "&#10;")
        let visible = escape(trimmed)
        if display {
            return "<div class=\"mp-math\" data-display=\"true\" data-tex=\"\(attr)\">$$\n\(visible)\n$$</div>"
        }
        return "<span class=\"mp-math\" data-display=\"false\" data-tex=\"\(attr)\">$\(visible)$</span>"
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

    // MARK: - Dipnot

    private static func extractFootnotes(_ text: String, bank: Bank) -> (markdown: String, notes: [FootnoteBlock]) {
        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let trailing = normalized.hasSuffix("\n")
        var lines = normalized.components(separatedBy: "\n")
        if trailing, lines.last == "" { lines.removeLast() }

        let def = try! NSRegularExpression(pattern: "^\\[\\^([^\\]]+)\\]:[ \\t]?(.*)$")
        func matchDef(_ line: String) -> (String, String)? {
            let ns = line as NSString
            guard let m = def.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
            return (ns.substring(with: m.range(at: 1)), ns.substring(with: m.range(at: 2)))
        }
        func indented(_ line: String) -> Bool { line.hasPrefix("    ") || line.hasPrefix("\t") }
        func dedent(_ line: String) -> String {
            if line.hasPrefix("    ") { return String(line.dropFirst(4)) }
            if line.hasPrefix("\t") { return String(line.dropFirst()) }
            return line
        }

        var kept: [String] = []
        var defs: [(id: String, body: String)] = []
        var known: Set<String> = []
        var i = 0
        while i < lines.count {
            if let (id, first) = matchDef(lines[i]) {
                var body = [first]
                i += 1
                while i < lines.count {
                    if matchDef(lines[i]) != nil { break }
                    if indented(lines[i]) {
                        body.append(dedent(lines[i]))
                        i += 1
                        continue
                    }
                    if lines[i].isEmpty {
                        let next = i + 1
                        if next < lines.count && indented(lines[next]) {
                            body.append("")
                            i += 1
                            continue
                        }
                        break
                    }
                    break
                }
                if !known.contains(id) {
                    known.insert(id)
                    defs.append((id, body.joined(separator: "\n")))
                }
                continue
            }
            kept.append(lines[i])
            i += 1
        }

        let joined = kept.joined(separator: "\n")
        let replaced = replaceReferences(joined, bank: bank, defs: defs)
        var markdown = replaced.markdown
        if trailing && !markdown.hasSuffix("\n") && !markdown.isEmpty { markdown += "\n" }
        return (markdown, replaced.notes)
    }

    private static func replaceReferences(_ text: String, bank: Bank,
                                          defs: [(id: String, body: String)]) -> (markdown: String, notes: [FootnoteBlock]) {
        guard let re = try? NSRegularExpression(pattern: "\\[\\^([^\\]]+)\\](?!:)") else {
            return (text, [])
        }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let matches = re.matches(in: text, range: full)
        var seen: [String: Int] = [:]
        var counts: [String: Int] = [:]
        var order: [String] = []
        var out = ""
        var cursor = 0
        for match in matches {
            let id = ns.substring(with: match.range(at: 1))
            if match.range.location < cursor { continue }
            out += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let number: Int
            if let existing = seen[id] {
                number = existing
            } else {
                number = order.count + 1
                seen[id] = number
                order.append(id)
            }
            counts[id, default: 0] += 1
            let instance = counts[id] ?? 1
            let anchor = instance == 1 ? "fnref-\(number)" : "fnref-\(number)-\(instance)"
            let html = "<sup class=\"fnref\"><a href=\"#fn-\(number)\" id=\"\(anchor)\">\(number)</a></sup>"
            out += bank.footnote(html)
            cursor = match.range.location + match.range.length
        }
        out += ns.substring(from: cursor)

        let bodies = Dictionary(uniqueKeysWithValues: defs.map { ($0.id, $0.body) })
        var notes: [FootnoteBlock] = order.map {
            FootnoteBlock(number: seen[$0] ?? 0, body: bodies[$0] ?? "", referenced: true)
        }
        for def in defs where seen[def.id] == nil {
            notes.append(FootnoteBlock(number: notes.count + 1, body: def.body, referenced: false))
        }
        return (out, notes)
    }
}
