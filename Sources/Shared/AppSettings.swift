import AppKit
import Combine

/// Uygulama + Quick Look eklentisi tarafindan paylasilan ayarlar.
/// App Group tanimliysa ayarlar eklentiye de gecer; degilse standard defaults'a duser.
final class AppSettings: ObservableObject {

    static let suiteName = "group.com.caglar.MarkPad"
    static let shared = AppSettings()

    let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: AppSettings.suiteName) ?? .standard

        themeID        = defaults.string(forKey: K.theme)      ?? Theme.istanbulDay.id
        bodyFontName   = defaults.string(forKey: K.bodyFont)   ?? "-apple-system"
        monoFontName   = defaults.string(forKey: K.monoFont)   ?? "SF Mono"
        headingFontName = defaults.string(forKey: K.headFont)  ?? "-apple-system"
        editorFontName = defaults.string(forKey: K.editorFont) ?? "SF Mono"
        bodyFontSize   = defaults.object(forKey: K.bodySize)   as? Double ?? 16
        editorFontSize = defaults.object(forKey: K.editorSize) as? Double ?? 14
        lineHeight     = defaults.object(forKey: K.lineHeight) as? Double ?? 1.65
        contentWidth   = defaults.object(forKey: K.width)      as? Double ?? 760
        justifyText    = defaults.object(forKey: K.justify)    as? Bool   ?? false
        typewriterMode = defaults.object(forKey: K.typewriter) as? Bool   ?? false
        followSystemAppearance = defaults.object(forKey: K.followSystem) as? Bool ?? true
        darkThemeID    = defaults.string(forKey: K.darkTheme)  ?? Theme.istanbulNight.id

        // Tek seferlik gecis: eski kurulumlarda kayitli olan varsayilan
        // GitHub temalarini İstanbul temalariyla degistir.
        if !defaults.bool(forKey: K.istanbulMigration) {
            if themeID == "github-light" { themeID = Theme.istanbulDay.id }
            if darkThemeID == "github-dark" { darkThemeID = Theme.istanbulNight.id }
            defaults.set(true, forKey: K.istanbulMigration)
        }
    }

    private enum K {
        static let theme = "themeID", darkTheme = "darkThemeID", followSystem = "followSystemAppearance"
        static let bodyFont = "bodyFontName", monoFont = "monoFontName"
        static let headFont = "headingFontName", editorFont = "editorFontName"
        static let bodySize = "bodyFontSize", editorSize = "editorFontSize"
        static let lineHeight = "lineHeight", width = "contentWidth"
        static let justify = "justifyText", typewriter = "typewriterMode"
        static let istanbulMigration = "didMigrateToIstanbulThemes"
    }

    @Published var themeID: String            { didSet { defaults.set(themeID, forKey: K.theme) } }
    @Published var darkThemeID: String        { didSet { defaults.set(darkThemeID, forKey: K.darkTheme) } }
    @Published var followSystemAppearance: Bool { didSet { defaults.set(followSystemAppearance, forKey: K.followSystem) } }
    @Published var bodyFontName: String       { didSet { defaults.set(bodyFontName, forKey: K.bodyFont) } }
    @Published var monoFontName: String       { didSet { defaults.set(monoFontName, forKey: K.monoFont) } }
    @Published var headingFontName: String    { didSet { defaults.set(headingFontName, forKey: K.headFont) } }
    @Published var editorFontName: String     { didSet { defaults.set(editorFontName, forKey: K.editorFont) } }
    @Published var bodyFontSize: Double       { didSet { defaults.set(bodyFontSize, forKey: K.bodySize) } }
    @Published var editorFontSize: Double     { didSet { defaults.set(editorFontSize, forKey: K.editorSize) } }
    @Published var lineHeight: Double         { didSet { defaults.set(lineHeight, forKey: K.lineHeight) } }
    @Published var contentWidth: Double       { didSet { defaults.set(contentWidth, forKey: K.width) } }
    @Published var justifyText: Bool          { didSet { defaults.set(justifyText, forKey: K.justify) } }
    @Published var typewriterMode: Bool       { didSet { defaults.set(typewriterMode, forKey: K.typewriter) } }

    // MARK: - Turetilmis degerler

    /// Sistem gorunumune gore aktif tema.
    func activeTheme(dark: Bool? = nil) -> Theme {
        let isDark = dark ?? (NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
        let id = (followSystemAppearance && isDark) ? darkThemeID : themeID
        return Theme.byID(id)
    }

    func editorFont() -> NSFont {
        NSFont(name: editorFontName, size: editorFontSize)
            ?? .monospacedSystemFont(ofSize: editorFontSize, weight: .regular)
    }

    func editorMonoFont() -> NSFont {
        NSFont(name: monoFontName, size: editorFontSize)
            ?? .monospacedSystemFont(ofSize: editorFontSize, weight: .regular)
    }

    /// CSS icin font-family zinciri uretir.
    func cssStack(_ name: String, fallback: String) -> String {
        if name == "-apple-system" {
            return "-apple-system, BlinkMacSystemFont, \(fallback)"
        }
        return "\"\(name)\", -apple-system, \(fallback)"
    }
}
