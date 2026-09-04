import SwiftUI
import AppKit
import WebKit

struct ContentView: View {

    @Binding var text: String
    let fileURL: URL?

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var controlActiveState

    @StateObject private var controller = EditorController()
    @StateObject private var compare = CompareController()
    @State private var mode: ViewMode = .split
    @State private var renderedHTML: String = ""
    @State private var editorScroll: Double = 0
    @State private var renderTask: Task<Void, Never>?

    private var theme: Theme {
        settings.activeTheme(dark: colorScheme == .dark)
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .dropDestination(for: URL.self) { urls, _ in
                    // Karsilastirma modunda birakma, sag paneldeki hedefe
                    // aittir (karsi dosyayi secer). Ayni anda iki anlami
                    // olmasin diye burada kapali.
                    mode == .compare ? false : openDroppedDocuments(urls)
                }
            Divider()
            statusBar
        }
        .background(Color(nsColor: theme.nsBackground))
        .toolbar { toolbarContent }
        .onAppear { render(immediately: true) }
        .onChange(of: text) { _ in render() }
        .onChange(of: settings.themeID) { _ in render(immediately: true) }
        .onChange(of: settings.darkThemeID) { _ in render(immediately: true) }
        .onChange(of: settings.bodyFontName) { _ in render(immediately: true) }
        .onChange(of: settings.bodyFontSize) { _ in render(immediately: true) }
        .onChange(of: settings.monoFontName) { _ in render(immediately: true) }
        .onChange(of: settings.headingFontName) { _ in render(immediately: true) }
        .onChange(of: settings.lineHeight) { _ in render(immediately: true) }
        .onChange(of: settings.contentWidth) { _ in render(immediately: true) }
        .onChange(of: settings.justifyText) { _ in render(immediately: true) }
        .onChange(of: colorScheme) { _ in render(immediately: true) }
        .onReceive(NotificationCenter.default.publisher(for: .setMode)) { note in
            if let m = note.object as? ViewMode { mode = m }
        }
        .onReceive(NotificationCenter.default.publisher(for: .markPadChooseCompareFile)) { _ in
            guard controlActiveState == .key else { return }
            compare.chooseFile()
            compare.recompute(against: text)
        }
    }

    // MARK: - Govde

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .editor:
            editor
        case .preview:
            preview
        case .split:
            HSplitView {
                editor.frame(minWidth: 280)
                preview.frame(minWidth: 280)
            }
        case .compare:
            CompareView(documentText: $text, controller: compare,
                        theme: theme, settings: settings)
        }
    }

    private var editor: some View {
        EditorView(text: $text,
                   settings: settings,
                   theme: theme,
                   controller: controller,
                   onScroll: { editorScroll = $0 })
    }

    private var preview: some View {
        PreviewWebView(html: renderedHTML,
                       baseURL: fileURL?.deletingLastPathComponent(),
                       scrollPercent: mode == .split ? editorScroll : nil)
    }

    // MARK: - Durum cubugu

    private var statusBar: some View {
        HStack(spacing: 14) {
            if mode == .compare {
                Text("\(compare.result.hunks.count) diff blocks")
                if compare.otherIsDirty { Text("other file not saved").foregroundStyle(.orange) }
            } else {
                Text("\(wordCount) words")
                Text("\(text.count) characters")
                Text("\(text.components(separatedBy: .newlines).count) lines")
            }
            Spacer()
            Text("~\(max(1, wordCount / 200)) min read")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }

    private var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    // MARK: - Arac cubugu

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            formatButton("bold", "Bold (⌘B)", .bold)
            formatButton("italic", "Italic (⌘I)", .italic)
            formatButton("strikethrough", "Strikethrough", .strikethrough)
            formatButton("chevron.left.forwardslash.chevron.right", "Inline code (⌘E)", .inlineCode)

            Divider()

            Menu {
                Button("Heading 1") { controller.apply(.heading(1)) }
                Button("Heading 2") { controller.apply(.heading(2)) }
                Button("Heading 3") { controller.apply(.heading(3)) }
                Button("Heading 4") { controller.apply(.heading(4)) }
                Divider()
                Button("Body text") { controller.apply(.heading(0)) }
            } label: {
                Label("Heading", systemImage: "textformat.size")
            }

            formatButton("list.bullet", "Bulleted list", .bulletList)
            formatButton("list.number", "Numbered list", .numberedList)
            formatButton("checklist", "Task list", .taskList)
            formatButton("text.quote", "Blockquote", .blockQuote)
            formatButton("curlybraces", "Code block", .codeBlock)
            formatButton("link", "Link (⌘K)", .link)
            formatButton("tablecells", "Table", .table)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            themeMenu

            Menu {
                Button("Export as HTML…") { exportHTML() }
                Button("Print Preview / PDF…") { printPreview() }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }

            Button {
                mode = .compare
                compare.chooseFile()
                compare.recompute(against: text)
            } label: {
                Label("Compare", systemImage: "arrow.left.arrow.right.square")
            }
            .help("Compare this document with another file (⇧⌘D)")

            Picker("View", selection: $mode) {
                ForEach(ViewMode.allCases) { m in
                    Image(systemName: m.symbol).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .help("⌘1 editor · ⌘2 split · ⌘3 preview · ⌘4 compare")
        }
    }

    private func formatButton(_ symbol: String, _ help: LocalizedStringKey, _ command: FormatCommand) -> some View {
        Button { controller.apply(command) } label: { Image(systemName: symbol) }
            .help(help)
    }

    // MARK: - Tema secici

    /// Onizleme temasini arac cubugundan degistirir.
    /// Sistem gorunumu koyuysa koyu tema listesi, degilse acik tema listesi duzenlenir.
    private var themeMenu: some View {
        Menu {
            Picker("Light theme", selection: $settings.themeID) {
                ForEach(Theme.all.filter { !$0.isDark }) { Text($0.name).tag($0.id) }
            }
            Picker("Dark theme", selection: $settings.darkThemeID) {
                ForEach(Theme.all.filter { $0.isDark }) { Text($0.name).tag($0.id) }
            }
            Divider()
            Toggle("Follow system appearance", isOn: $settings.followSystemAppearance)
            Divider()
            Text("Active: \(theme.name)")
        } label: {
            Label("Theme", systemImage: "paintpalette")
        }
        .help("Preview theme: \(theme.name)")
    }

    // MARK: - Surukle birak

    /// Pencereye birakilan metin dosyalarini yeni belge olarak acar.
    ///
    /// Birakma sandbox'in kullanici hareketi saydigi yollardan biridir, bu
    /// yuzden `NSDocumentController` dosyayi ek entitlement olmadan okuyabilir.
    /// Ikili dosyalar sessizce elenir; hicbiri kabul edilmezse false doneriz
    /// ve surukleme kaynagina "kabul edilmedi" geri bildirimi gider.
    private func openDroppedDocuments(_ urls: [URL]) -> Bool {
        let acceptable = urls.filter(CompareController.isComparableTextFile)
        guard !acceptable.isEmpty else { return false }
        for url in acceptable {
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        }
        return true
    }

    // MARK: - Isleme

    private func render(immediately: Bool = false) {
        renderTask?.cancel()
        let source = text
        let theme = self.theme
        let settings = self.settings

        renderTask = Task { @MainActor in
            if !immediately {
                try? await Task.sleep(nanoseconds: 180_000_000)
                if Task.isCancelled { return }
            }
            let body = await Task.detached(priority: .userInitiated) {
                MarkdownHTMLRenderer.render(source)
            }.value
            if Task.isCancelled { return }
            renderedHTML = StyleSheet.document(bodyHTML: body, theme: theme,
                                               settings: settings, includeScrollBridge: true)
        }
    }

    // MARK: - Disa aktarma

    private func exportHTML() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = (fileURL?.deletingPathExtension().lastPathComponent ?? String(localized: "document")) + ".html"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? renderedHTML.write(to: url, atomically: true, encoding: .utf8)
    }

    private func printPreview() {
        // WKWebView yazdirma paneli, PDF olarak kaydet secenegini de icerir.
        guard let window = NSApp.keyWindow,
              let webView = findWebView(in: window.contentView) else { return }
        let info = NSPrintInfo.shared
        info.topMargin = 36; info.bottomMargin = 36
        info.leftMargin = 36; info.rightMargin = 36
        webView.printOperation(with: info).run()
    }

    private func findWebView(in view: NSView?) -> WKWebView? {
        guard let view else { return nil }
        if let web = view as? WKWebView { return web }
        for sub in view.subviews {
            if let found = findWebView(in: sub) { return found }
        }
        return nil
    }
}
