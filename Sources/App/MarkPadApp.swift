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
            Button("About ProMDEditor") { MarkPadAbout.show() }
        }

        CommandMenu("Format") {
            button("Bold", .bold, "b", [.command])
            button("Italic", .italic, "i", [.command])
            button("Strikethrough", .strikethrough, "x", [.command, .shift])
            button("Inline Code", .inlineCode, "e", [.command])
            Divider()
            button("Heading 1", .heading(1), "1", [.command, .control])
            button("Heading 2", .heading(2), "2", [.command, .control])
            button("Heading 3", .heading(3), "3", [.command, .control])
            button("Body Text", .heading(0), "0", [.command, .control])
            Divider()
            button("Bulleted List", .bulletList, "l", [.command, .shift])
            button("Numbered List", .numberedList, "n", [.command, .shift])
            button("Task List", .taskList, "t", [.command, .shift])
            button("Blockquote", .blockQuote, "'", [.command, .shift])
            button("Code Block", .codeBlock, "k", [.command, .shift])
            Divider()
            button("Add Link…", .link, "k", [.command])
            button("Horizontal Rule", .horizontalRule, "-", [.command, .shift])
            button("Insert Table", .table, "t", [.command, .control])
        }

        CommandGroup(after: .toolbar) {
            Button("Editor Only") { post(.setMode, mode: .editor) }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Split View") { post(.setMode, mode: .split) }
                .keyboardShortcut("2", modifiers: [.command])
            Button("Preview Only") { post(.setMode, mode: .preview) }
                .keyboardShortcut("3", modifiers: [.command])
            Button("Compare") { post(.setMode, mode: .compare) }
                .keyboardShortcut("4", modifiers: [.command])
        }

        CommandGroup(after: .newItem) {
            Button("Compare with File…") {
                NotificationCenter.default.post(name: .setMode, object: ViewMode.compare)
                NotificationCenter.default.post(name: .markPadChooseCompareFile, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }

    private func button(_ title: LocalizedStringKey, _ command: FormatCommand,
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
            .applicationName: "ProMDEditor"
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    private static var credits: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 3

        let result = NSMutableAttributedString()

        result.append(NSAttributedString(
            string: String(localized: "Markdown editor, viewer and Quick Look extension") + "\n\n",
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
