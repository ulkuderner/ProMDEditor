import SwiftUI

@main
struct ReaderApp: App {
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownFile()) { file in
            DocumentView(text: file.$document.text, fileURL: file.fileURL)
                .environmentObject(settings)
        }
        .commands {
            CommandMenu("Format") {
                ForEach(FormatCatalog.entries) { entry in
                    FormatEntryRow(entry: entry, shortcuts: true) { $0.post() }
                }
            }
        }
    }
}
