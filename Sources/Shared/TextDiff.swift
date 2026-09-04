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
