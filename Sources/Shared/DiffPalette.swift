import AppKit

/// Diff renkleri. Temanin 12 tanimina dokunmadan, yalnizca
/// acik/koyu ayrimina gore secilir.
///
/// Renk tek sinyal degildir: arayuz ayrica oluğa +, −, ~ isaretini
/// cizer. Renk korlugu icin bu gereklidir.
struct DiffPalette {
    let addBG: NSColor
    let addStrongBG: NSColor
    let deleteBG: NSColor
    let deleteStrongBG: NSColor
    let gutterFG: NSColor

    static func forTheme(_ theme: Theme) -> DiffPalette {
        theme.isDark ? dark : light
    }

    static let light = DiffPalette(
        addBG:          NSColor(srgbRed: 0.878, green: 0.961, blue: 0.890, alpha: 1),
        addStrongBG:    NSColor(srgbRed: 0.667, green: 0.898, blue: 0.706, alpha: 1),
        deleteBG:       NSColor(srgbRed: 1.000, green: 0.910, blue: 0.914, alpha: 1),
        deleteStrongBG: NSColor(srgbRed: 1.000, green: 0.741, blue: 0.753, alpha: 1),
        gutterFG:       NSColor(white: 0.42, alpha: 1))

    static let dark = DiffPalette(
        addBG:          NSColor(srgbRed: 0.050, green: 0.196, blue: 0.098, alpha: 1),
        addStrongBG:    NSColor(srgbRed: 0.102, green: 0.365, blue: 0.180, alpha: 1),
        deleteBG:       NSColor(srgbRed: 0.239, green: 0.075, blue: 0.086, alpha: 1),
        deleteStrongBG: NSColor(srgbRed: 0.451, green: 0.129, blue: 0.161, alpha: 1),
        gutterFG:       NSColor(white: 0.62, alpha: 1))
}
