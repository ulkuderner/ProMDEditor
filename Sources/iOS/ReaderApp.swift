import SwiftUI

@main
struct ReaderApp: App {
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        DocumentGroup(viewing: MarkdownFile.self) { file in
            ReaderView(text: file.document.text, baseURL: file.fileURL)
                .environmentObject(settings)
        }
    }
}
