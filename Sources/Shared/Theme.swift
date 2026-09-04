import AppKit

struct Theme: Identifiable, Hashable {
    let id: String
    let name: String
    let isDark: Bool

    let bg: String
    let fg: String
    let muted: String
    let accent: String
    let border: String
    let codeBG: String
    let codeFG: String
    let quoteBar: String
    let selection: String

    static let githubLight = Theme(
        id: "github-light", name: "GitHub Light", isDark: false,
        bg: "#ffffff", fg: "#1f2328", muted: "#656d76", accent: "#0969da",
        border: "#d0d7de", codeBG: "#f6f8fa", codeFG: "#1f2328",
        quoteBar: "#d0d7de", selection: "#b6d7ff")

    static let githubDark = Theme(
        id: "github-dark", name: "GitHub Dark", isDark: true,
        bg: "#0d1117", fg: "#e6edf3", muted: "#8b949e", accent: "#58a6ff",
        border: "#30363d", codeBG: "#161b22", codeFG: "#e6edf3",
        quoteBar: "#30363d", selection: "#1f4b7a")

    static let sepia = Theme(
        id: "sepia", name: "Sepia", isDark: false,
        bg: "#f7f1e3", fg: "#3b332a", muted: "#776B59", accent: "#9c5a2d",
        border: "#e0d5bf", codeBG: "#efe6d2", codeFG: "#3b332a",
        quoteBar: "#d8c9ac", selection: "#e6d3a8")

    static let nord = Theme(
        id: "nord", name: "Nord", isDark: true,
        bg: "#2e3440", fg: "#eceff4", muted: "#8fa1b3", accent: "#88c0d0",
        border: "#434c5e", codeBG: "#3b4252", codeFG: "#e5e9f0",
        quoteBar: "#4c566a", selection: "#434c5e")

    static let solarizedLight = Theme(
        id: "solarized-light", name: "Solarized Light", isDark: false,
        bg: "#fdf6e3", fg: "#3E4D52", muted: "#677171", accent: "#1F72AC",
        border: "#eee8d5", codeBG: "#eee8d5", codeFG: "#3E4D52",
        quoteBar: "#d9d2c1", selection: "#e4dcc6")

    static let inkDark = Theme(
        id: "ink-dark", name: "Ink", isDark: true,
        bg: "#141414", fg: "#e8e6e3", muted: "#8f8b85", accent: "#d7a86e",
        border: "#2b2b2b", codeBG: "#1d1d1d", codeFG: "#e8e6e3",
        quoteBar: "#3a3a3a", selection: "#3d3428")

    // MARK: - İstanbul (varsayilan)
    // Gunduz: Sultanahmet kirectasi + İznik cinisi mavisi + Osmanli altini.
    // Gece: Bogaz'in gece laciverdi + cini turkuazi + kandil altini.
    // Her iki tema da govde metninde 13:1 ustu kontrast hedefler.

    static let istanbulDay = Theme(
        id: "istanbul-day", name: "İstanbul Day", isDark: false,
        bg: "#FBF7F0", fg: "#1B2730", muted: "#55646F", accent: "#0A5F80",
        border: "#E2DACC", codeBG: "#F1EADC", codeFG: "#1B2730",
        quoteBar: "#C8A24A", selection: "#C9E2ED")

    static let istanbulNight = Theme(
        id: "istanbul-night", name: "İstanbul Night", isDark: true,
        bg: "#0F1922", fg: "#EAEFF4", muted: "#9AABB9", accent: "#5AC6DA",
        border: "#233240", codeBG: "#15212C", codeFG: "#EAEFF4",
        quoteBar: "#D9A441", selection: "#1E3E54")

    static let solarizedDark = Theme(
        id: "solarized-dark", name: "Solarized Dark", isDark: true,
        bg: "#002b36", fg: "#B6BFBF", muted: "#839499", accent: "#3C97D6",
        border: "#073642", codeBG: "#073541", codeFG: "#B6BFBF",
        quoteBar: "#586e75", selection: "#0d3c47")

    static let dracula = Theme(
        id: "dracula", name: "Dracula", isDark: true,
        bg: "#282a36", fg: "#f8f8f2", muted: "#8894BA", accent: "#bd93f9",
        border: "#44475a", codeBG: "#21222c", codeFG: "#f8f8f2",
        quoteBar: "#6272a4", selection: "#44475a")

    static let oneDark = Theme(
        id: "one-dark", name: "One Dark", isDark: true,
        bg: "#282c34", fg: "#BFC4CE", muted: "#90959E", accent: "#61afef",
        border: "#3e4451", codeBG: "#21252b", codeFG: "#BFC4CE",
        quoteBar: "#4b5263", selection: "#3e4451")

    static let tokyoNight = Theme(
        id: "tokyo-night", name: "Tokyo Night", isDark: true,
        bg: "#1a1b26", fg: "#c0caf5", muted: "#7F85A5", accent: "#7aa2f7",
        border: "#292e42", codeBG: "#16161e", codeFG: "#c0caf5",
        quoteBar: "#414868", selection: "#283457")

    static let catppuccinMocha = Theme(
        id: "catppuccin-mocha", name: "Catppuccin Mocha", isDark: true,
        bg: "#1e1e2e", fg: "#cdd6f4", muted: "#9399b2", accent: "#89b4fa",
        border: "#313244", codeBG: "#181825", codeFG: "#cdd6f4",
        quoteBar: "#45475a", selection: "#45475a")

    static let catppuccinLatte = Theme(
        id: "catppuccin-latte", name: "Catppuccin Latte", isDark: false,
        bg: "#eff1f5", fg: "#44475E", muted: "#686A77", accent: "#1e66d5",
        border: "#ccd0da", codeBG: "#e6e9ef", codeFG: "#44475E",
        quoteBar: "#bcc0cc", selection: "#dce0e8")

    static let gruvboxDark = Theme(
        id: "gruvbox-dark", name: "Gruvbox Dark", isDark: true,
        bg: "#282828", fg: "#ebdbb2", muted: "#a89984", accent: "#fabd2f",
        border: "#3c3836", codeBG: "#32302f", codeFG: "#ebdbb2",
        quoteBar: "#504945", selection: "#45403d")

    static let gruvboxLight = Theme(
        id: "gruvbox-light", name: "Gruvbox Light", isDark: false,
        bg: "#fbf1c7", fg: "#3c3836", muted: "#75685E", accent: "#af3a03",
        border: "#ebdbb2", codeBG: "#f2e5bc", codeFG: "#3c3836",
        quoteBar: "#d5c4a1", selection: "#ebdbb2")

    static let rosePine = Theme(
        id: "rose-pine", name: "Rosé Pine", isDark: true,
        bg: "#191724", fg: "#e0def4", muted: "#908caa", accent: "#c4a7e7",
        border: "#26233a", codeBG: "#1f1d2e", codeFG: "#e0def4",
        quoteBar: "#403d52", selection: "#312f44")

    static let rosePineDawn = Theme(
        id: "rose-pine-dawn", name: "Rosé Pine Dawn", isDark: false,
        bg: "#faf4ed", fg: "#4B4768", muted: "#706D7A", accent: "#79668E",
        border: "#dfdad9", codeBG: "#f2e9e1", codeFG: "#4B4768",
        quoteBar: "#cecacd", selection: "#dfdad9")

    static let everforest = Theme(
        id: "everforest", name: "Everforest", isDark: true,
        bg: "#2d353b", fg: "#DACFB8", muted: "#96A19A", accent: "#a7c080",
        border: "#3d484d", codeBG: "#343f44", codeFG: "#DACFB8",
        quoteBar: "#4f585e", selection: "#475258")

    static let monokai = Theme(
        id: "monokai", name: "Monokai", isDark: true,
        bg: "#272822", fg: "#f8f8f2", muted: "#939081", accent: "#a6e22e",
        border: "#3e3d32", codeBG: "#1e1f1c", codeFG: "#f8f8f2",
        quoteBar: "#49483e", selection: "#49483e")

    static let midnight = Theme(
        id: "midnight", name: "Midnight (OLED)", isDark: true,
        bg: "#000000", fg: "#e6e6e6", muted: "#7a7a7a", accent: "#4da3ff",
        border: "#1c1c1c", codeBG: "#0c0c0c", codeFG: "#e6e6e6",
        quoteBar: "#2a2a2a", selection: "#1f3a5f")

    static let paper = Theme(
        id: "paper", name: "Paper", isDark: false,
        bg: "#fffdf7", fg: "#2b2b2b", muted: "#777267", accent: "#b4531f",
        border: "#e8e2d4", codeBG: "#f6f2e8", codeFG: "#2b2b2b",
        quoteBar: "#ded7c5", selection: "#f0e6cf")

    static let highContrast = Theme(
        id: "high-contrast", name: "High Contrast", isDark: false,
        bg: "#ffffff", fg: "#000000", muted: "#3d3d3d", accent: "#0000cc",
        border: "#000000", codeBG: "#f0f0f0", codeFG: "#000000",
        quoteBar: "#000000", selection: "#ffec3d")

    static let highContrastDark = Theme(
        id: "high-contrast-dark", name: "High Contrast (Dark)", isDark: true,
        bg: "#000000", fg: "#ffffff", muted: "#c8c8c8", accent: "#4dc3ff",
        border: "#ffffff", codeBG: "#141414", codeFG: "#ffffff",
        quoteBar: "#ffffff", selection: "#0050a0")

    // MARK: - Populer editor temalari
    // Paletler upstream projelerden alindi; govde metni, soluk metin ve
    // baglanti renkleri okunabilirlik icin kontrast olcumune gore ayarlandi.

    static let ayuLight = Theme(
        id: "ayu-light", name: "Ayu Light", isDark: false,
        bg: "#FCFCFC", fg: "#33383D", muted: "#63696F", accent: "#B45A19",
        border: "#E4E6E8", codeBG: "#F2F3F4", codeFG: "#33383D",
        quoteBar: "#D8DBDE", selection: "#D6E5F0")

    static let ayuMirage = Theme(
        id: "ayu-mirage", name: "Ayu Mirage", isDark: true,
        bg: "#1F2430", fg: "#E9ECF2", muted: "#A3ABBB", accent: "#FFD173",
        border: "#2D3441", codeBG: "#1A1F29", codeFG: "#E9ECF2",
        quoteBar: "#3D4553", selection: "#33415E")

    static let nightOwl = Theme(
        id: "night-owl", name: "Night Owl", isDark: true,
        bg: "#011627", fg: "#E7EEF7", muted: "#9BAFC2", accent: "#7FDBCA",
        border: "#10293D", codeBG: "#01111F", codeFG: "#E7EEF7",
        quoteBar: "#2C4A5E", selection: "#1D3B53")

    static let lightOwl = Theme(
        id: "light-owl", name: "Light Owl", isDark: false,
        bg: "#FBFBFB", fg: "#202E3D", muted: "#566878", accent: "#0A6491",
        border: "#E1E5E9", codeBG: "#F0F2F4", codeFG: "#202E3D",
        quoteBar: "#CBD3DA", selection: "#D3E1EC")

    static let kanagawa = Theme(
        id: "kanagawa", name: "Kanagawa", isDark: true,
        bg: "#1F1F28", fg: "#E4E1D5", muted: "#A6A69C", accent: "#8FC0D9",
        border: "#2D2D3A", codeBG: "#191922", codeFG: "#E4E1D5",
        quoteBar: "#54546D", selection: "#2D4F67")

    static let vitesseLight = Theme(
        id: "vitesse-light", name: "Vitesse Light", isDark: false,
        bg: "#FFFFFF", fg: "#33342E", muted: "#61635A", accent: "#146145",
        border: "#E5E5E0", codeBG: "#F7F7F5", codeFG: "#33342E",
        quoteBar: "#DDDDD6", selection: "#D9E6DF")

    static let vitesseDark = Theme(
        id: "vitesse-dark", name: "Vitesse Dark", isDark: true,
        bg: "#121212", fg: "#DEDACD", muted: "#A0A096", accent: "#5CA684",
        border: "#2A2A2A", codeBG: "#1A1A1A", codeFG: "#DEDACD",
        quoteBar: "#3A3A3A", selection: "#2A3B33")

    static let materialOcean = Theme(
        id: "material-ocean", name: "Material Ocean", isDark: true,
        bg: "#0F111A", fg: "#E4E8F1", muted: "#99A0BC", accent: "#82AAFF",
        border: "#1F2233", codeBG: "#090B10", codeFG: "#E4E8F1",
        quoteBar: "#3A3F58", selection: "#1F2A45")

    static let githubDimmed = Theme(
        id: "github-dimmed", name: "GitHub Dimmed", isDark: true,
        bg: "#22272E", fg: "#DCE3EA", muted: "#A8B3BE", accent: "#6CB6FF",
        border: "#373E47", codeBG: "#1C2128", codeFG: "#DCE3EA",
        quoteBar: "#444C56", selection: "#2D4A6B")

    static let atomOneLight = Theme(
        id: "atom-one-light", name: "Atom One Light", isDark: false,
        bg: "#FAFAFA", fg: "#262A31", muted: "#5A616D", accent: "#0F5FC0",
        border: "#E3E4E6", codeBG: "#F0F0F1", codeFG: "#262A31",
        quoteBar: "#D3D5D8", selection: "#D7E4F5")

    static let cobalt2 = Theme(
        id: "cobalt2", name: "Cobalt2", isDark: true,
        bg: "#193549", fg: "#EBF3F9", muted: "#AEC3D2", accent: "#FFC600",
        border: "#26455C", codeBG: "#122B3C", codeFG: "#EBF3F9",
        quoteBar: "#35526B", selection: "#0D3A58")

    static let panda = Theme(
        id: "panda", name: "Panda", isDark: true,
        bg: "#292A2B", fg: "#E8E8E8", muted: "#A7A9AA", accent: "#19F9D8",
        border: "#3C3D3E", codeBG: "#212223", codeFG: "#E8E8E8",
        quoteBar: "#4A4B4C", selection: "#3A3B3C")

    static let all: [Theme] = [
        istanbulDay, istanbulNight,
        githubLight, githubDark, githubDimmed,
        atomOneLight, oneDark,
        lightOwl, nightOwl,
        ayuLight, ayuMirage,
        vitesseLight, vitesseDark,
        catppuccinLatte, catppuccinMocha,
        gruvboxLight, gruvboxDark,
        rosePineDawn, rosePine,
        solarizedLight, solarizedDark,
        sepia, paper,
        nord, tokyoNight, kanagawa, everforest,
        materialOcean, dracula, monokai, cobalt2, panda,
        inkDark, midnight,
        highContrast, highContrastDark
    ]

    static func byID(_ id: String) -> Theme {
        all.first { $0.id == id } ?? .istanbulDay
    }

    // MARK: - AppKit renkleri (editor tarafi icin)

    var nsBackground: NSColor { NSColor(hex: bg) ?? .textBackgroundColor }
    var nsForeground: NSColor { NSColor(hex: fg) ?? .textColor }
    var nsMuted: NSColor      { NSColor(hex: muted) ?? .secondaryLabelColor }
    var nsAccent: NSColor     { NSColor(hex: accent) ?? .linkColor }
    var nsCodeBG: NSColor     { NSColor(hex: codeBG) ?? .underPageBackgroundColor }
    var nsSelection: NSColor  { NSColor(hex: selection) ?? .selectedTextBackgroundColor }
}

// MARK: - CSS

enum StyleSheet {

    static func css(theme: Theme, settings: AppSettings) -> String {
        let body = settings.cssStack(settings.bodyFontName, fallback: "\"Helvetica Neue\", Arial, sans-serif")
        let head = settings.cssStack(settings.headingFontName, fallback: "\"Helvetica Neue\", Arial, sans-serif")
        let mono = settings.cssStack(settings.monoFontName, fallback: "ui-monospace, Menlo, monospace")
        let size = settings.bodyFontSize
        let lh = settings.lineHeight
        let width = settings.contentWidth
        let align = settings.justifyText ? "justify" : "left"

        return """
        :root {
          --bg: \(theme.bg); --fg: \(theme.fg); --muted: \(theme.muted);
          --accent: \(theme.accent); --border: \(theme.border);
          --code-bg: \(theme.codeBG); --code-fg: \(theme.codeFG);
          --quote: \(theme.quoteBar); --sel: \(theme.selection);
        }
        * { box-sizing: border-box; }
        html, body { margin: 0; padding: 0; background: var(--bg); }
        ::selection { background: var(--sel); }
        body {
          color: var(--fg);
          font-family: \(body);
          font-size: \(size)px;
          line-height: \(lh);
          text-align: \(align);
          -webkit-font-smoothing: antialiased;
          text-rendering: optimizeLegibility;
          font-variant-ligatures: common-ligatures;
          hyphens: auto;
        }
        #content {
          max-width: \(Int(width))px;
          margin: 0 auto;
          padding: 44px 32px 120px;
        }
        h1, h2, h3, h4, h5, h6 {
          font-family: \(head);
          line-height: 1.25; font-weight: 700;
          margin: 1.6em 0 .6em; text-align: left;
          letter-spacing: -0.011em;
        }
        h1 { font-size: 2.05em; margin-top: 0; padding-bottom: .3em; border-bottom: 1px solid var(--border); }
        h2 { font-size: 1.55em; padding-bottom: .25em; border-bottom: 1px solid var(--border); }
        h3 { font-size: 1.28em; }
        h4 { font-size: 1.08em; }
        h5 { font-size: 1em; }
        h6 { font-size: .92em; color: var(--muted); }
        p { margin: 0 0 1.05em; }
        a { color: var(--accent); text-decoration: none; }
        a:hover { text-decoration: underline; }
        strong { font-weight: 700; }
        em { font-style: italic; }
        del { color: var(--muted); }
        hr { border: 0; border-top: 1px solid var(--border); margin: 2.2em 0; }
        blockquote {
          margin: 0 0 1.05em; padding: .1em 1.1em;
          border-left: 4px solid var(--quote); color: var(--muted);
        }
        blockquote > :last-child { margin-bottom: 0; }
        ul, ol { margin: 0 0 1.05em; padding-left: 1.7em; }
        li { margin: .28em 0; }
        li > ul, li > ol { margin-bottom: 0; }
        li.task { list-style: none; margin-left: -1.35em; }
        li.task input { margin-right: .5em; vertical-align: middle; }
        code {
          font-family: \(mono);
          font-size: .875em;
          background: var(--code-bg); color: var(--code-fg);
          padding: .18em .38em; border-radius: 5px;
          border: 1px solid var(--border);
        }
        pre {
          background: var(--code-bg); border: 1px solid var(--border);
          border-radius: 8px; padding: 14px 16px; overflow-x: auto;
          margin: 0 0 1.2em; line-height: 1.5; text-align: left;
        }
        pre code { background: none; border: 0; padding: 0; font-size: .86em; }
        table {
          border-collapse: collapse; margin: 0 0 1.2em;
          display: block; overflow-x: auto; max-width: 100%;
        }
        th, td { border: 1px solid var(--border); padding: 7px 13px; text-align: left; }
        th { background: var(--code-bg); font-weight: 600; }
        tr:nth-child(2n) td { background: color-mix(in srgb, var(--code-bg) 45%, transparent); }
        img { max-width: 100%; border-radius: 6px; }
        kbd {
          font-family: \(mono); font-size: .8em; padding: .15em .45em;
          border: 1px solid var(--border); border-bottom-width: 2px;
          border-radius: 5px; background: var(--code-bg);
        }
        .footnotes { font-size: .9em; color: var(--muted); border-top: 1px solid var(--border); margin-top: 2.5em; padding-top: 1em; }
        """
    }

    /// Tam HTML belgesi uretir.
    static func document(bodyHTML: String, theme: Theme, settings: AppSettings, includeScrollBridge: Bool) -> String {
        let bridge = includeScrollBridge ? """
        <script>
        window.mpScrollTo = function(p) {
          var h = document.documentElement.scrollHeight - window.innerHeight;
          window.scrollTo(0, Math.max(0, h * p));
        };
        window.mpScrollPercent = function() {
          var h = document.documentElement.scrollHeight - window.innerHeight;
          return h > 0 ? window.scrollY / h : 0;
        };
        </script>
        """ : ""

        return """
        <!DOCTYPE html>
        <html lang="tr">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(css(theme: theme, settings: settings))</style>
        </head>
        <body><div id="content">\(bodyHTML)</div>\(bridge)</body>
        </html>
        """
    }
}

// MARK: - Hex -> NSColor

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }
}
