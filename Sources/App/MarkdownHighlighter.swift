import AppKit

/// Editordeki duz markdown metnini "zengin metin" gibi gosteren canli bicimlendirici.
/// Metin her zaman duz markdown olarak saklanir; sadece gorunum degisir.
enum MarkdownHighlighter {

    private static let headingScale: [CGFloat] = [1.85, 1.55, 1.32, 1.18, 1.08, 1.0]

    private struct Rule {
        let regex: NSRegularExpression
        let apply: (NSTextStorage, NSTextCheckingResult, Context) -> Void
    }

    struct Context {
        let base: NSFont
        let mono: NSFont
        let theme: Theme
        let manager = NSFontManager.shared
    }

    private static func re(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }

    // MARK: - Ana giris

    static func highlight(_ storage: NSTextStorage, settings: AppSettings, theme: Theme) {
        let ctx = Context(base: settings.editorFont(),
                          mono: settings.editorMonoFont(),
                          theme: theme)
        let text = storage.string
        let full = NSRange(location: 0, length: (text as NSString).length)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = CGFloat(settings.lineHeight * 0.82)
        paragraph.paragraphSpacing = ctx.base.pointSize * 0.35
        paragraph.defaultTabInterval = ctx.base.pointSize * 2
        paragraph.lineBreakMode = .byWordWrapping

        storage.beginEditing()
        storage.setAttributes([
            .font: ctx.base,
            .foregroundColor: theme.nsForeground,
            .paragraphStyle: paragraph
        ], range: full)

        for rule in rules {
            rule.regex.enumerateMatches(in: text, range: full) { match, _, _ in
                guard let match else { return }
                rule.apply(storage, match, ctx)
            }
        }
        storage.endEditing()
    }

    // MARK: - Kurallar

    private static let rules: [Rule] = [

        // Cit kod bloklari
        Rule(regex: re("^```[\\s\\S]*?^```"), apply: { st, m, c in
            st.addAttributes([.font: c.mono,
                              .foregroundColor: c.theme.nsForeground,
                              .backgroundColor: c.theme.nsCodeBG], range: m.range)
        }),

        // ATX basliklari:  ## Baslik
        Rule(regex: re("^(#{1,6})[ \\t]+(.+)$"), apply: { st, m, c in
            let level = min(6, m.range(at: 1).length)
            let size = c.base.pointSize * headingScale[level - 1]
            let font = c.manager.convert(NSFont(name: c.base.fontName, size: size) ?? c.base,
                                         toHaveTrait: .boldFontMask)
            st.addAttributes([.font: font], range: m.range)
            st.addAttributes([.foregroundColor: c.theme.nsMuted.withAlphaComponent(0.4)],
                             range: m.range(at: 1))
        }),

        // Setext benzeri yatay cizgi
        Rule(regex: re("^([-*_])\\s*\\1\\s*\\1[-*_\\s]*$"), apply: { st, m, c in
            st.addAttributes([.foregroundColor: c.theme.nsMuted], range: m.range)
        }),

        // Alinti
        Rule(regex: re("^>[ \\t]?.*$"), apply: { st, m, c in
            let italic = c.manager.convert(c.base, toHaveTrait: .italicFontMask)
            st.addAttributes([.font: italic, .foregroundColor: c.theme.nsMuted], range: m.range)
        }),

        // Liste isaretleri (gorev kutulari dahil)
        Rule(regex: re("^\\s*([-*+]|\\d+\\.)[ \\t]+(\\[[ xX]\\][ \\t]+)?"), apply: { st, m, c in
            let bold = c.manager.convert(c.base, toHaveTrait: .boldFontMask)
            st.addAttributes([.font: bold, .foregroundColor: c.theme.nsAccent], range: m.range)
        }),

        // **kalin**
        Rule(regex: re("(\\*\\*|__)(?=\\S)(.+?[*_]*)(?<=\\S)\\1"), apply: { st, m, c in
            let bold = c.manager.convert(c.base, toHaveTrait: .boldFontMask)
            st.addAttributes([.font: bold], range: m.range)
            dim(st, m.range(at: 1), c)
            dimTail(st, m, c, markerLength: 2)
        }),

        // *italik*
        Rule(regex: re("(?<![*\\w])(\\*)(?=\\S)([^*\\n]+?)(?<=\\S)\\*(?![*\\w])"), apply: { st, m, c in
            let italic = c.manager.convert(c.base, toHaveTrait: .italicFontMask)
            st.addAttributes([.font: italic], range: m.range)
            dim(st, m.range(at: 1), c)
            dimTail(st, m, c, markerLength: 1)
        }),

        // ~~ustu cizili~~
        Rule(regex: re("~~(?=\\S)(.+?)(?<=\\S)~~"), apply: { st, m, c in
            st.addAttributes([.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                              .foregroundColor: c.theme.nsMuted], range: m.range)
        }),

        // `satir ici kod`
        Rule(regex: re("`[^`\\n]+`"), apply: { st, m, c in
            st.addAttributes([.font: c.mono,
                              .backgroundColor: c.theme.nsCodeBG,
                              .foregroundColor: c.theme.nsForeground], range: m.range)
        }),

        // [etiket](hedef)  ve  ![etiket](hedef)
        Rule(regex: re("(!?\\[)([^\\]\\n]*)(\\]\\()([^)\\n]*)(\\))"), apply: { st, m, c in
            st.addAttributes([.foregroundColor: c.theme.nsAccent,
                              .underlineStyle: NSUnderlineStyle.single.rawValue],
                             range: m.range(at: 2))
            for i in [1, 3, 5] { dim(st, m.range(at: i), c) }
            st.addAttributes([.font: c.mono,
                              .foregroundColor: c.theme.nsMuted], range: m.range(at: 4))
        }),

        // Tablo satirlari
        Rule(regex: re("^\\|.*\\|\\s*$"), apply: { st, m, c in
            st.addAttributes([.font: c.mono], range: m.range)
        })
    ]

    // MARK: - Yardimcilar

    private static func dim(_ st: NSTextStorage, _ range: NSRange, _ c: Context) {
        guard range.location != NSNotFound, range.length > 0 else { return }
        st.addAttributes([.foregroundColor: c.theme.nsMuted.withAlphaComponent(0.35)], range: range)
    }

    /// Kapanis isaretleyicisini de soluklastirir.
    private static func dimTail(_ st: NSTextStorage, _ m: NSTextCheckingResult,
                                _ c: Context, markerLength: Int) {
        let end = NSMaxRange(m.range)
        let tail = NSRange(location: end - markerLength, length: markerLength)
        guard tail.location >= 0, NSMaxRange(tail) <= st.length else { return }
        dim(st, tail, c)
    }
}
