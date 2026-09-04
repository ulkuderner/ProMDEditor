import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView {
            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            typographyTab
                .tabItem { Label("Typography", systemImage: "textformat") }
            editorTab
                .tabItem { Label("Editor", systemImage: "pencil") }
        }
        .padding(18)
    }

    // MARK: - Gorunum

    private var appearanceTab: some View {
        Form {
            Picker("Light theme:", selection: $settings.themeID) {
                ForEach(Theme.all.filter { !$0.isDark }) { Text($0.name).tag($0.id) }
            }
            Picker("Dark theme:", selection: $settings.darkThemeID) {
                ForEach(Theme.all.filter { $0.isDark }) { Text($0.name).tag($0.id) }
            }
            Toggle("Follow system appearance", isOn: $settings.followSystemAppearance)

            Divider().padding(.vertical, 6)

            themePreview
        }
        .formStyle(.grouped)
    }

    private var themePreview: some View {
        let theme = settings.activeTheme()
        return VStack(alignment: .leading, spacing: 6) {
            Text("Preview").font(.caption).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Heading").font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(nsColor: theme.nsForeground))
                Text("Body text sample — readability and contrast.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(nsColor: theme.nsForeground))
                Text("code_sample()")
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
            FontPicker(title: "Body font:", selection: $settings.bodyFontName)
            FontPicker(title: "Heading font:", selection: $settings.headingFontName)
            FontPicker(title: "Monospace:", selection: $settings.monoFontName, monospacedOnly: true)

            Slider(value: $settings.bodyFontSize, in: 11...28, step: 1) {
                Text("Size: \(Int(settings.bodyFontSize))")
            }
            Slider(value: $settings.lineHeight, in: 1.2...2.4, step: 0.05) {
                Text(String(format: String(localized: "Line height: %.2f"), settings.lineHeight))
            }
            Slider(value: $settings.contentWidth, in: 520...1200, step: 20) {
                Text("Content width: \(Int(settings.contentWidth)) px")
            }
            Toggle("Justify text", isOn: $settings.justifyText)
        }
        .formStyle(.grouped)
    }

    // MARK: - Duzenleyici

    private var editorTab: some View {
        Form {
            FontPicker(title: "Editor font:", selection: $settings.editorFontName)
            Slider(value: $settings.editorFontSize, in: 10...24, step: 1) {
                Text("Size: \(Int(settings.editorFontSize))")
            }
            Toggle("Typewriter mode (keep cursor centered)", isOn: $settings.typewriterMode)

            Section("Shortcuts") {
                shortcut("⌘B", "Bold"); shortcut("⌘I", "Italic")
                shortcut("⌘E", "Inline code"); shortcut("⌘K", "Link")
                shortcut("⌃⌘1–6", "Heading level"); shortcut("⇧⌘L", "Bulleted list")
                shortcut("⌘1/2/3", "Editor / Split / Preview")
            }
        }
        .formStyle(.grouped)
    }

    private func shortcut(_ key: String, _ label: LocalizedStringKey) -> some View {
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
    let title: LocalizedStringKey
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
                Text(family == "-apple-system" ? String(localized: "System Font") : family)
                    .font(.custom(family == "-apple-system" ? "SF Pro" : family, size: 13))
                    .tag(family)
            }
        }
    }
}
