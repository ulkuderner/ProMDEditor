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
