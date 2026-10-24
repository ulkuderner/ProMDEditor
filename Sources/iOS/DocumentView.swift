import SwiftUI

/// iPhone ve iPad belgesi. macOS ile aynı Biçim menüsü ve biçim şeridi.
struct DocumentView: View {
    @Binding var text: String
    let fileURL: URL?

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass

    @StateObject private var controller = IOSEditorController()
    @State private var mode: ViewMode = .editor
    @State private var html = ""
    @State private var renderTask: Task<Void, Never>?

    private var theme: Theme { settings.activeTheme() }
    private var showsEditor: Bool { mode == .editor || mode == .split }
    private var showsPreview: Bool { mode == .preview || mode == .split }

    var body: some View {
        VStack(spacing: 0) {
            if showsEditor {
                FormatToolbar { controller.apply($0) }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.bar)
                Divider()
            }
            pane
            statusBar
        }
        .background(Color(hex: theme.bg))
        .toolbar { toolbar }
        .onAppear { html = makeHTML(text) }
        .onChange(of: text) { _ in render() }
        .onChange(of: mode) { _ in
            if showsPreview { render(immediately: true) }
        }
        .onChange(of: sizeClass) { _ in render(immediately: true) }
        .onChange(of: settings.themeID) { _ in render(immediately: true) }
        .onChange(of: settings.bodyFontName) { _ in render(immediately: true) }
        .onChange(of: settings.bodyFontSize) { _ in render(immediately: true) }
        .onChange(of: settings.monoFontName) { _ in render(immediately: true) }
        .onChange(of: settings.headingFontName) { _ in render(immediately: true) }
        .onChange(of: settings.lineHeight) { _ in render(immediately: true) }
        .onChange(of: settings.contentWidth) { _ in render(immediately: true) }
        .onChange(of: settings.justifyText) { _ in render(immediately: true) }
        .onReceive(NotificationCenter.default.publisher(for: .markPadFormat)) { note in
            guard scenePhase == .active,
                  controller.textView?.window?.isKeyWindow == true,
                  let command = note.object as? FormatCommand else { return }
            controller.apply(command)
        }
    }

    @ViewBuilder
    private var pane: some View {
        if sizeClass == .compact && mode == .split {
            VStack(spacing: 0) {
                editor.frame(maxHeight: .infinity)
                Divider()
                preview.frame(maxHeight: .infinity)
            }
        } else if mode == .split {
            HStack(spacing: 0) {
                editor.frame(maxWidth: .infinity)
                Divider()
                preview.frame(maxWidth: .infinity)
            }
        } else if showsPreview {
            preview
        } else {
            editor
        }
    }

    private var editor: some View {
        IOSEditorView(text: $text, settings: settings, theme: theme, controller: controller)
    }

    private var preview: some View {
        HTMLView(html: html, baseURL: fileURL, background: theme.bg)
            .background(Color(hex: theme.bg))
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Text("\(wordCount) words")
            Text("·")
            Text("\(text.count) characters")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Picker("View", selection: $mode) {
                ForEach([ViewMode.editor, .split, .preview]) { item in
                    Image(systemName: item.symbol)
                        .accessibilityLabel(Text(item.label))
                        .tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 168)

            Menu {
                Picker("Theme", selection: $settings.themeID) {
                    ForEach(Theme.all) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
            } label: {
                Label(theme.name, systemImage: "paintpalette")
            }

            Menu {
                ForEach(FormatCatalog.entries) { entry in
                    FormatEntryRow(entry: entry, shortcuts: false) { controller.apply($0) }
                }
            } label: {
                Label("Format", systemImage: "textformat")
            }
        }
    }

    private func makeHTML(_ source: String) -> String {
        let body = MarkdownHTMLRenderer.render(source)
        return StyleSheet.document(bodyHTML: body, theme: theme, settings: settings,
                                   includeScrollBridge: false, compact: sizeClass == .compact)
    }

    private func render(immediately: Bool = false) {
        renderTask?.cancel()
        let source = text
        let compact = sizeClass == .compact
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
            html = StyleSheet.document(bodyHTML: body, theme: theme, settings: settings,
                                       includeScrollBridge: false, compact: compact)
        }
    }
}
