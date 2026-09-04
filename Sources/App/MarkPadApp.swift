import SwiftUI
import AppKit

@main
struct MarkPadApp: App {

    @NSApplicationDelegateAdaptor(MarkPadAppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(text: file.$document.text, fileURL: file.fileURL)
                .environmentObject(settings)
                .frame(minWidth: 640, minHeight: 420)
        }
        .commands {
            MarkPadCommands()
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .frame(width: 520, height: 520)
        }
    }
}

/// Uygulama dosya acmadan baslatildiginda bos bir belge acar.
final class MarkPadAppDelegate: NSObject, NSApplicationDelegate {

    /// macOS 12'den beri belge tabanli uygulamalar acilista dosya secme
    /// panelini gosteriyor. Bu davranisi yoneten anahtar bir **kullanici
    /// varsayilani**dir, Info.plist anahtari degil — `NSUserDefaults`
    /// Info.plist'i okumadigi icin oraya yazmak hicbir sey yapmaz.
    ///
    /// Kayit alanina (registration domain) yaziyoruz: bu en dusuk oncelikli
    /// katman, yani kullanici sistem ayarindan paneli acikca istediyse
    /// onun tercihi gecerli kalir.
    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "NSShowAppCentricOpenPanelInsteadOfUntitledFile": false
        ])
    }

    /// Panel gosterilmediginde bunun yerine adsiz bir belge acilsin.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }
}

/// Menu cubugu komutlari. Aktif editore NotificationCenter uzerinden gider.
struct MarkPadCommands: Commands {

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("MarkPad Hakkında") { MarkPadAbout.show() }
        }

        CommandMenu("Biçim") {
            button("Kalın", .bold, "b", [.command])
            button("İtalik", .italic, "i", [.command])
            button("Üstü Çizili", .strikethrough, "x", [.command, .shift])
            button("Satır İçi Kod", .inlineCode, "e", [.command])
            Divider()
            button("Başlık 1", .heading(1), "1", [.command, .control])
            button("Başlık 2", .heading(2), "2", [.command, .control])
            button("Başlık 3", .heading(3), "3", [.command, .control])
            button("Normal Paragraf", .heading(0), "0", [.command, .control])
            Divider()
            button("Madde İşaretli Liste", .bulletList, "l", [.command, .shift])
            button("Numaralı Liste", .numberedList, "n", [.command, .shift])
            button("Görev Listesi", .taskList, "t", [.command, .shift])
            button("Alıntı", .blockQuote, "'", [.command, .shift])
            button("Kod Bloğu", .codeBlock, "k", [.command, .shift])
            Divider()
            button("Bağlantı Ekle…", .link, "k", [.command])
            button("Yatay Çizgi", .horizontalRule, "-", [.command, .shift])
            button("Tablo Ekle", .table, "t", [.command, .control])
        }

        CommandGroup(after: .toolbar) {
            Button("Yalnızca Düzenleyici") { post(.setMode, mode: .editor) }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Bölünmüş Görünüm") { post(.setMode, mode: .split) }
                .keyboardShortcut("2", modifiers: [.command])
            Button("Yalnızca Önizleme") { post(.setMode, mode: .preview) }
                .keyboardShortcut("3", modifiers: [.command])
            Button("Karşılaştır") { post(.setMode, mode: .compare) }
                .keyboardShortcut("4", modifiers: [.command])
        }

        CommandGroup(after: .newItem) {
            Button("Dosya ile Karşılaştır…") {
                NotificationCenter.default.post(name: .setMode, object: ViewMode.compare)
                NotificationCenter.default.post(name: .markPadChooseCompareFile, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }

    private func button(_ title: String, _ command: FormatCommand,
                        _ key: KeyEquivalent, _ mods: EventModifiers) -> some View {
        Button(title) {
            NotificationCenter.default.post(name: .markPadFormat, object: command)
        }
        .keyboardShortcut(key, modifiers: mods)
    }

    private func post(_ name: Notification.Name, mode: ViewMode) {
        NotificationCenter.default.post(name: name, object: mode)
    }
}

extension Notification.Name {
    static let markPadFormat = Notification.Name("markPadFormat")
    static let setMode = Notification.Name("markPadSetMode")
    static let markPadChooseCompareFile = Notification.Name("markPadChooseCompareFile")
}

/// Standart "Hakkında" panelini yazar bilgisiyle gosterir.
enum MarkPadAbout {

    static let authorName = "Çağlar Ülküderner"
    static let authorEmail = "caglar@profelis.com.tr"

    static func show() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            .applicationName: "MarkPad"
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    private static var credits: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 3

        let result = NSMutableAttributedString()

        result.append(NSAttributedString(
            string: "Markdown düzenleyici, görüntüleyici ve Quick Look eklentisi\n\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph
            ]))

        result.append(NSAttributedString(
            string: "\(authorName)\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]))

        result.append(NSAttributedString(
            string: authorEmail,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .link: URL(string: "mailto:\(authorEmail)") as Any,
                .paragraphStyle: paragraph
            ]))

        return result
    }
}
