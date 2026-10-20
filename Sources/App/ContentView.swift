import SwiftUI
import AppKit
import WebKit
import UniformTypeIdentifiers

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
    @State private var exportError: String?
    @StateObject private var printSession = PreviewPrintSession()

    private var theme: Theme {
        settings.activeTheme(dark: colorScheme == .dark)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsFormatBar { formatBar }
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
        .alert("Export Failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .markPadExport)) { note in
            guard controlActiveState == .key else { return }
            guard let command = note.object as? DocumentExportCommand else { return }
            performExport(command)
        }
    }

    /// Bicim cubugu yalnizca editor gorunurken durur. Onizleme ve
    /// karsilastirmada kaynak secimi olmadigi icin yer kaplamaz.
    private var showsFormatBar: Bool {
        mode == .editor || mode == .split
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
        HStack(spacing: 8) {
            if mode == .compare {
                Text("\(compare.result.hunks.count) diff blocks")
                if compare.otherIsDirty {
                    Text("·")
                    Text("other file not saved")
                }
            } else {
                Text("\(wordCount) words")
                Text("·")
                Text("\(text.count) characters")
                Text("·")
                Text("\(text.components(separatedBy: .newlines).count) lines")
            }
            Spacer()
            Text("~\(max(1, wordCount / 200)) min read")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    // MARK: - Arac cubugu

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            themeMenu
            exportMenu

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

    /// Pencere arac cubugundan ayri, opak bicim seridi. Cam yalnizca
    /// sistem arac cubugunda kalir; bu serit icerik katmanidir.
    private var formatBar: some View {
        HStack(spacing: 2) {
            formatButton("bold", "Bold (⌘B)", .bold)
            formatButton("italic", "Italic (⌘I)", .italic)
            formatButton("strikethrough", "Strikethrough", .strikethrough)
            formatButton("chevron.left.forwardslash.chevron.right", "Inline code (⌘E)", .inlineCode)

            formatDivider

            Menu {
                Button("Heading 1") { controller.apply(.heading(1)) }
                Button("Heading 2") { controller.apply(.heading(2)) }
                Button("Heading 3") { controller.apply(.heading(3)) }
                Button("Heading 4") { controller.apply(.heading(4)) }
                Divider()
                Button("Body text") { controller.apply(.heading(0)) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "textformat.size")
                    Text("Heading")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .font(.body)
                .padding(.horizontal, 6)
                .frame(minHeight: 28)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            formatDivider

            formatButton("list.bullet", "Bulleted list", .bulletList)
            formatButton("list.number", "Numbered list", .numberedList)
            formatButton("checklist", "Task list", .taskList)
            formatButton("text.quote", "Blockquote", .blockQuote)
            formatButton("curlybraces", "Code block", .codeBlock)

            formatDivider

            formatButton("link", "Link (⌘K)", .link)
            formatButton("tablecells", "Table", .table)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var formatDivider: some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 6)
    }

    private func formatButton(_ symbol: String, _ help: LocalizedStringKey, _ command: FormatCommand) -> some View {
        Button { controller.apply(command) } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .regular))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private var exportMenu: some View {
        Menu {
            Button("Export as HTML…") { performExport(.html) }
            Button("Export as PDF…") { performExport(.pdf) }
            Button("Export as Word…") { performExport(.docx) }
            Button("Export as Rich Text…") { performExport(.rtf) }
            Divider()
            Button("Copy as Rich Text") { performExport(.copyRichText) }
            Button("Copy as HTML") { performExport(.copyHTML) }
            Divider()
            Button("Print…") { performExport(.print) }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
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

    private var exportBaseName: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? String(localized: "document")
    }

    /// RTF ve Word beyaz sayfada acilir. Koyu temanin acik yazisi orada kaybolur,
    /// bu yuzden kullanicinin acik temasini kullaniriz.
    private var readableTheme: Theme {
        if !theme.isDark { return theme }
        let light = Theme.byID(settings.themeID)
        return light.isDark ? .istanbulDay : light
    }

    private func exportHTMLString(forPrint: Bool) -> String {
        let body = MarkdownHTMLRenderer.render(text)
        return StyleSheet.document(bodyHTML: body, theme: theme, settings: settings,
                                   includeScrollBridge: false, forPrint: forPrint)
    }

    private func richText() -> NSAttributedString {
        MarkdownRichText.render(text, settings: settings, theme: readableTheme,
                                baseURL: fileURL?.deletingLastPathComponent())
    }

    private func performExport(_ command: DocumentExportCommand) {
        switch command {
        case .html:
            save(type: .html, extension: "html") { url in
                try exportHTMLString(forPrint: false).write(to: url, atomically: true, encoding: .utf8)
            }
        case .rtf:
            save(type: .rtf, extension: "rtf") { url in
                try MarkdownRichText.rtfData(richText()).write(to: url, options: .atomic)
            }
        case .docx:
            save(type: DocumentFileTypes.docx, extension: "docx") { url in
                try MarkdownRichText.docxData(richText()).write(to: url, options: .atomic)
            }
        case .pdf:
            guard let url = chooseURL(type: .pdf, extension: "pdf") else { return }
            let html = exportHTMLString(forPrint: true)
            let base = fileURL?.deletingLastPathComponent()
            Task { @MainActor in
                do {
                    try await PreviewPDFWriter().write(html: html, baseURL: base, to: url)
                } catch {
                    exportError = error.localizedDescription
                }
            }
        case .copyRichText:
            do { try DocumentClipboard.copyRichText(richText()) }
            catch { exportError = error.localizedDescription }
        case .copyHTML:
            DocumentClipboard.copyHTML(exportHTMLString(forPrint: false))
        case .print:
            printSession.print(html: exportHTMLString(forPrint: true),
                               baseURL: fileURL?.deletingLastPathComponent())
        }
    }

    private func chooseURL(type: UTType, extension ext: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = exportBaseName + "." + ext
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private func save(type: UTType, extension ext: String, writer: (URL) throws -> Void) {
        guard let url = chooseURL(type: type, extension: ext) else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            try writer(url)
        } catch {
            exportError = error.localizedDescription
        }
    }
}
