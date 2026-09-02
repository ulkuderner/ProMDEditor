import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView {
            appearanceTab
                .tabItem { Label("Görünüm", systemImage: "paintbrush") }
            typographyTab
                .tabItem { Label("Tipografi", systemImage: "textformat") }
            editorTab
                .tabItem { Label("Düzenleyici", systemImage: "pencil") }
        }
        .padding(18)
    }

    // MARK: - Gorunum

    private var appearanceTab: some View {
        Form {
            Picker("Açık tema:", selection: $settings.themeID) {
                ForEach(Theme.all.filter { !$0.isDark }) { Text($0.name).tag($0.id) }
            }
            Picker("Koyu tema:", selection: $settings.darkThemeID) {
                ForEach(Theme.all.filter { $0.isDark }) { Text($0.name).tag($0.id) }
            }
            Toggle("Sistem görünümünü izle", isOn: $settings.followSystemAppearance)

            Divider().padding(.vertical, 6)

            themePreview
        }
        .formStyle(.grouped)
    }

    private var themePreview: some View {
        let theme = settings.activeTheme()
        return VStack(alignment: .leading, spacing: 6) {
            Text("Önizleme").font(.caption).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Başlık").font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(nsColor: theme.nsForeground))
                Text("Gövde metni örneği — okunabilirlik ve kontrast.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(nsColor: theme.nsForeground))
                Text("kod_ornegi()")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(nsColor: theme.nsAccent))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: theme.nsBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
        }
    }

    // MARK: - Tipografi

    private var typographyTab: some View {
        Form {
            FontPicker(title: "Gövde yazı tipi:", selection: $settings.bodyFontName)
            FontPicker(title: "Başlık yazı tipi:", selection: $settings.headingFontName)
            FontPicker(title: "Tek aralıklı:", selection: $settings.monoFontName, monospacedOnly: true)

            Slider(value: $settings.bodyFontSize, in: 11...28, step: 1) {
                Text("Punto: \(Int(settings.bodyFontSize))")
            }
            Slider(value: $settings.lineHeight, in: 1.2...2.4, step: 0.05) {
                Text(String(format: "Satır yüksekliği: %.2f", settings.lineHeight))
            }
            Slider(value: $settings.contentWidth, in: 520...1200, step: 20) {
                Text("İçerik genişliği: \(Int(settings.contentWidth)) px")
            }
            Toggle("İki yana yasla", isOn: $settings.justifyText)
        }
        .formStyle(.grouped)
    }

    // MARK: - Duzenleyici

    private var editorTab: some View {
        Form {
            FontPicker(title: "Düzenleyici yazı tipi:", selection: $settings.editorFontName)
            Slider(value: $settings.editorFontSize, in: 10...24, step: 1) {
                Text("Punto: \(Int(settings.editorFontSize))")
            }
            Toggle("Daktilo modu (imleci ortada tut)", isOn: $settings.typewriterMode)

            Section("Kısayollar") {
                shortcut("⌘B", "Kalın"); shortcut("⌘I", "İtalik")
                shortcut("⌘E", "Satır içi kod"); shortcut("⌘K", "Bağlantı")
                shortcut("⌃⌘1–6", "Başlık düzeyi"); shortcut("⇧⌘L", "Madde listesi")
                shortcut("⌘1/2/3", "Düzenleyici / Bölünmüş / Önizleme")
            }
        }
        .formStyle(.grouped)
    }

    private func shortcut(_ key: String, _ label: String) -> some View {
        HStack {
            Text(key).font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }
}

/// Sistemde kurulu tum yazi tiplerini listeleyen secici.
struct FontPicker: View {
    let title: String
    @Binding var selection: String
    var monospacedOnly: Bool = false

    private var families: [String] {
        var list = NSFontManager.shared.availableFontFamilies.sorted()
        if monospacedOnly {
            list = list.filter { family in
                guard let font = NSFont(name: family, size: 12) else { return false }
                return font.isFixedPitch
            }
        }
        return ["-apple-system"] + list
    }

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(families, id: \.self) { family in
                Text(family == "-apple-system" ? "Sistem Yazı Tipi" : family)
                    .font(.custom(family == "-apple-system" ? "SF Pro" : family, size: 13))
                    .tag(family)
            }
        }
    }
}
