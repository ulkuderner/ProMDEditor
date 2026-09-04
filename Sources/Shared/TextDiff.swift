import Foundation

/// İki metin arasindaki farki hesaplayan saf motor.
/// Dosya sistemi, tema ve arayuz bilmez; girdisi ve ciktisi degerdir.
enum TextDiff {

    /// Bir metnin satirlari ve bicim bilgisi.
    /// `lines` satir sonu karakterlerini icermez; bicim `ending` ve
    /// `hasTrailingNewline` ile ayrica tasinir, boylece `join` orijinali
    /// birebir geri kurabilir.
    struct Lines: Equatable {
        var lines: [String]
        var ending: String
        var hasTrailingNewline: Bool
    }

    /// Metni LF, CRLF ve CR ayraclarinda satirlara boler.
    static func split(_ text: String) -> Lines {
        if text.isEmpty {
            return Lines(lines: [], ending: "\n", hasTrailingNewline: false)
        }

        let ending = text.contains("\r\n") ? "\r\n" : "\n"
        let scalars = Array(text.unicodeScalars)
        let hasTrailing = scalars.last == "\n" || scalars.last == "\r"

        var lines: [String] = []
        var current = ""
        var i = 0

        while i < scalars.count {
            let c = scalars[i]
            if c == "\r" {
                lines.append(current)
                current = ""
                // CRLF tek ayrac sayilir
                if i + 1 < scalars.count && scalars[i + 1] == "\n" {
                    i += 2
                } else {
                    i += 1
                }
            } else if c == "\n" {
                lines.append(current)
                current = ""
                i += 1
            } else {
                current.append(Character(c))
                i += 1
            }
        }

        // Son satir ayracla bitmediyse henuz eklenmemistir.
        if !hasTrailing { lines.append(current) }
        return Lines(lines: lines, ending: ending, hasTrailingNewline: hasTrailing)
    }

    /// Satirlari `model`in bicimiyle (ayrac + sondaki yeni satir) birlestirir.
    static func join(_ lines: [String], like model: Lines) -> String {
        if lines.isEmpty { return "" }
        var s = lines.joined(separator: model.ending)
        if model.hasTrailingNewline { s += model.ending }
        return s
    }
}

// MARK: - Myers O(ND) diff

extension TextDiff {

    /// Tek bir duzenleme adimi. Indeksler kaynak dizilere aittir.
    enum Edit: Equatable {
        case keep(left: Int, right: Int)
        case delete(left: Int)
        case insert(right: Int)
    }

    /// Myers'in greedy O(ND) algoritmasi.
    ///
    /// Maliyet dizilerin boyutuyla degil, **fark sayisiyla** (D) orantilidir;
    /// benzer iki dosyada D kucuktur. Klasik LCS matrisi yerine bu secildi
    /// cunku LCS O(n*m) bellek ister (5.000x5.000 satir = ~25M hucre).
    ///
    /// - Parameter maxD: izin verilen en buyuk fark sayisi. Asilirsa `nil`
    ///   doner ve cagiran kaba bir geri dusus uygular.
    static func myers<T: Equatable>(_ a: [T], _ b: [T], maxD: Int) -> [Edit]? {
        let n = a.count, m = b.count
        let bound = n + m
        if bound == 0 { return [] }

        let offset = bound
        var v = [Int](repeating: 0, count: 2 * bound + 1)
        var trace: [[Int]] = []

        var d = 0
        while d <= min(bound, maxD) {
            trace.append(v)          // trace[d] = d turunun BASINDAKI durum
            var k = -d
            while k <= d {
                var x: Int
                // k == -d ve k == d kenarlarinda kisa devre sart:
                // v[k-1] / v[k+1] o durumlarda dizi disina taşar.
                if k == -d || (k != d && v[k - 1 + offset] < v[k + 1 + offset]) {
                    x = v[k + 1 + offset]
                } else {
                    x = v[k - 1 + offset] + 1
                }
                var y = x - k
                while x < n && y < m && a[x] == b[y] { x += 1; y += 1 }
                v[k + offset] = x
                if x >= n && y >= m {
                    return backtrack(trace, offset: offset, n: n, m: m)
                }
                k += 2
            }
            d += 1
        }
        return nil
    }

    /// Kaydedilmis `V` durumlarindan geriye yurüyerek edit listesini kurar.
    private static func backtrack(_ trace: [[Int]], offset: Int, n: Int, m: Int) -> [Edit] {
        var edits: [Edit] = []
        var x = n, y = m

        for d in stride(from: trace.count - 1, through: 0, by: -1) {
            let v = trace[d]
            let k = x - y
            let prevK: Int
            if k == -d || (k != d && v[k - 1 + offset] < v[k + 1 + offset]) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }
            let prevX = v[prevK + offset]
            let prevY = prevX - prevK

            while x > prevX && y > prevY {
                edits.append(.keep(left: x - 1, right: y - 1))
                x -= 1; y -= 1
            }
            if d > 0 {
                if x == prevX {
                    edits.append(.insert(right: y - 1))
                } else {
                    edits.append(.delete(left: x - 1))
                }
            }
            x = prevX; y = prevY
        }
        return edits.reversed()
    }
}

// MARK: - Sonuc tipleri

enum DiffLineKind {
    case equal, inserted, deleted, changed
}

/// Bir satirin icindeki parca. Parcalarin `text` birlesimi satirin
/// birebir kendisidir; bu degismez tum uretim yollarinda korunur.
struct InlineSpan: Equatable {
    let text: String
    let changed: Bool
}

/// Tabloda tek bir gorsel satir.
/// `left` / `right`, ilgili taraftaki 0 tabanli satir indeksidir;
/// o tarafta karsiligi yoksa nil olur ve bos dolgu cizilir.
struct DiffRow: Equatable {
    let left: Int?
    let right: Int?
    let kind: DiffLineKind
    let leftSpans: [InlineSpan]
    let rightSpans: [InlineSpan]
}

/// Bitisik farkli satirlarin olusturdugu blok.
/// `rows` satir tablosundaki aralik; `leftLines` / `rightLines` kaynak
/// metinlerdeki aralik. Saf ekleme/silmede bunlardan biri bos araliktir.
struct DiffHunk: Identifiable, Equatable {
    let id: Int
    let rows: Range<Int>
    let leftLines: Range<Int>
    let rightLines: Range<Int>
}

struct DiffResult: Equatable {
    let rows: [DiffRow]
    let hunks: [DiffHunk]
    let truncated: Bool

    static let empty = DiffResult(rows: [], hunks: [], truncated: false)
}

// MARK: - compare

extension TextDiff {

    /// Fark sayisi bu esigi asarsa kaba geri dusus uygulanir.
    static let maxDifferences = 5000

    static func compare(left: String, right: String) -> DiffResult {
        let a = split(left).lines
        let b = split(right).lines

        // Ortak bas ve son satirlari kirp: tipik duzenlemede farkin
        // buyuk kismini eler ve Myers'i kucuk bir bolgede calistirir.
        var head = 0
        while head < a.count && head < b.count && a[head] == b[head] { head += 1 }

        var tail = 0
        while tail < a.count - head && tail < b.count - head
                && a[a.count - 1 - tail] == b[b.count - 1 - tail] { tail += 1 }

        let aMid = Array(a[head..<(a.count - tail)])
        let bMid = Array(b[head..<(b.count - tail)])

        var rows: [DiffRow] = []
        rows.reserveCapacity(a.count + b.count)

        for i in 0..<head {
            rows.append(equalRow(left: i, right: i, text: a[i]))
        }

        var truncated = false
        if let edits = myers(aMid, bMid, maxD: maxDifferences) {
            for e in edits {
                switch e {
                case .keep(let l, let r):
                    rows.append(equalRow(left: head + l, right: head + r, text: aMid[l]))
                case .delete(let l):
                    rows.append(DiffRow(left: head + l, right: nil, kind: .deleted,
                                        leftSpans: [InlineSpan(text: aMid[l], changed: true)],
                                        rightSpans: []))
                case .insert(let r):
                    rows.append(DiffRow(left: nil, right: head + r, kind: .inserted,
                                        leftSpans: [],
                                        rightSpans: [InlineSpan(text: bMid[r], changed: true)]))
                }
            }
        } else {
            // Geri dusus: orta bolgenin tamami silinmis + tamami eklenmis.
            truncated = true
            for (l, line) in aMid.enumerated() {
                rows.append(DiffRow(left: head + l, right: nil, kind: .deleted,
                                    leftSpans: [InlineSpan(text: line, changed: true)],
                                    rightSpans: []))
            }
            for (r, line) in bMid.enumerated() {
                rows.append(DiffRow(left: nil, right: head + r, kind: .inserted,
                                    leftSpans: [],
                                    rightSpans: [InlineSpan(text: line, changed: true)]))
            }
        }

        for t in 0..<tail {
            let l = a.count - tail + t
            let r = b.count - tail + t
            rows.append(equalRow(left: l, right: r, text: a[l]))
        }

        // Kaba geri dususte satirlari eslestirmek yaniltici olur; atla.
        let paired = truncated ? rows : pairChanges(rows)
        return DiffResult(rows: paired, hunks: groupHunks(paired), truncated: truncated)
    }

    private static func equalRow(left: Int, right: Int, text: String) -> DiffRow {
        let span = [InlineSpan(text: text, changed: false)]
        return DiffRow(left: left, right: right, kind: .equal,
                       leftSpans: span, rightSpans: span)
    }
}

// MARK: - Satir ici kelime farki

extension TextDiff {

    /// Satiri harf/rakam dizileri ve tek tek diger karakterler olarak boler.
    /// Bosluklar token olarak korunur; boylece token'larin birlesimi
    /// satirin birebir kendisidir.
    static func tokenize(_ line: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var currentIsWord = false

        for ch in line {
            let isWord = ch.isLetter || ch.isNumber
            if current.isEmpty {
                current = String(ch)
                currentIsWord = isWord
            } else if isWord && currentIsWord {
                current.append(ch)
            } else {
                tokens.append(current)
                current = String(ch)
                currentIsWord = isWord
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Iki satirin kelime duzeyinde farkini parcalara doker.
    static func inlineSpans(_ a: String, _ b: String) -> (left: [InlineSpan], right: [InlineSpan]) {
        let ta = tokenize(a), tb = tokenize(b)

        // Satir ici icin dusuk esik yeter; asilirsa tum satir degismis sayilir.
        guard let edits = myers(ta, tb, maxD: 400) else {
            return ([InlineSpan(text: a, changed: true)],
                    [InlineSpan(text: b, changed: true)])
        }

        var left: [InlineSpan] = [], right: [InlineSpan] = []
        for e in edits {
            switch e {
            case .keep(let l, let r):
                appendSpan(&left, ta[l], changed: false)
                appendSpan(&right, tb[r], changed: false)
            case .delete(let l):
                appendSpan(&left, ta[l], changed: true)
            case .insert(let r):
                appendSpan(&right, tb[r], changed: true)
            }
        }
        return (left, right)
    }

    /// Ayni isarete sahip ardisik parcalari birlestirir; arayuzde
    /// parca basina bir gorunum yaratmamak icin.
    private static func appendSpan(_ spans: inout [InlineSpan], _ text: String, changed: Bool) {
        if let last = spans.last, last.changed == changed {
            spans[spans.count - 1] = InlineSpan(text: last.text + text, changed: changed)
        } else {
            spans.append(InlineSpan(text: text, changed: changed))
        }
    }

    /// Bitisik silme/ekleme kosularini, sayilari esitse 1-1 eslestirip
    /// `.changed` satirlara donusturur.
    static func pairChanges(_ rows: [DiffRow]) -> [DiffRow] {
        var result: [DiffRow] = []
        result.reserveCapacity(rows.count)
        var i = 0

        while i < rows.count {
            guard rows[i].kind == .deleted else {
                result.append(rows[i]); i += 1; continue
            }

            var d = i
            while d < rows.count && rows[d].kind == .deleted { d += 1 }
            var s = d
            while s < rows.count && rows[s].kind == .inserted { s += 1 }

            let deleted = rows[i..<d], inserted = rows[d..<s]
            guard deleted.count == inserted.count, !deleted.isEmpty else {
                result.append(contentsOf: rows[i..<s]); i = s; continue
            }

            for (dRow, iRow) in zip(deleted, inserted) {
                let a = dRow.leftSpans.map(\.text).joined()
                let b = iRow.rightSpans.map(\.text).joined()
                let (ls, rs) = inlineSpans(a, b)
                result.append(DiffRow(left: dRow.left, right: iRow.right, kind: .changed,
                                      leftSpans: ls, rightSpans: rs))
            }
            i = s
        }
        return result
    }
}

// MARK: - Hunk gruplama

extension TextDiff {

    /// Bitisik farkli satirlari blok haline getirir.
    /// Aralarinda `context` satirdan az esit satir kalan iki blok birlesir.
    static func groupHunks(_ rows: [DiffRow], context: Int = 3) -> [DiffHunk] {
        // Once farkli satirlarin kosularini bul.
        var runs: [Range<Int>] = []
        var i = 0
        while i < rows.count {
            guard rows[i].kind != .equal else { i += 1; continue }
            var j = i
            while j < rows.count && rows[j].kind != .equal { j += 1 }
            runs.append(i..<j)
            i = j
        }

        // Yakin kosulari birlestir.
        var merged: [Range<Int>] = []
        for run in runs {
            if let last = merged.last, run.lowerBound - last.upperBound < context {
                merged[merged.count - 1] = last.lowerBound..<run.upperBound
            } else {
                merged.append(run)
            }
        }

        return merged.enumerated().map { index, range in
            DiffHunk(id: index,
                     rows: range,
                     leftLines: sourceRange(rows, range, side: .left),
                     rightLines: sourceRange(rows, range, side: .right))
        }
    }

    /// Bir hunk'in bir taraftaki kaynak satir araligini bulur.
    /// O tarafta hic satir yoksa (saf ekleme/silme) ekleme noktasinda
    /// bos bir aralik doner — `apply` bu noktaya yerlestirir.
    private static func sourceRange(_ rows: [DiffRow], _ range: Range<Int>, side: Side) -> Range<Int> {
        let indexOf: (DiffRow) -> Int? = { side == .left ? $0.left : $0.right }
        let inside = rows[range].compactMap(indexOf)

        if let low = inside.min(), let high = inside.max() {
            return low..<(high + 1)
        }
        // Hunk'tan onceki son satir indeksi + 1 = ekleme noktasi.
        let anchor = (rows[0..<range.lowerBound].compactMap(indexOf).max()).map { $0 + 1 } ?? 0
        return anchor..<anchor
    }
}

/// Karsilastirmanin iki tarafi.
enum Side {
    case left, right
}

// MARK: - Hunk uygulama

extension TextDiff {

    /// Bir hunk'i `source` tarafindan karsi tarafa aktarir.
    ///
    /// Saf fonksiyon: diski bilmez, iki yeni metin dondurur.
    /// Kaynak taraf hicbir zaman degismez. Hedef tarafin satir sonu bicimi
    /// ve sondaki yeni satiri korunur.
    static func apply(hunk: DiffHunk, source: Side,
                      left: String, right: String) -> (left: String, right: String) {
        let l = split(left)
        let r = split(right)

        switch source {
        case .right:
            let yeni = replacing(l.lines, hunk.leftLines, with: Array(r.lines[hunk.rightLines]))
            return (join(yeni, like: l), right)
        case .left:
            let yeni = replacing(r.lines, hunk.rightLines, with: Array(l.lines[hunk.leftLines]))
            return (left, join(yeni, like: r))
        }
    }

    private static func replacing(_ lines: [String], _ range: Range<Int>,
                                  with yeni: [String]) -> [String] {
        var result = Array(lines[0..<range.lowerBound])
        result.append(contentsOf: yeni)
        result.append(contentsOf: lines[range.upperBound...])
        return result
    }
}
