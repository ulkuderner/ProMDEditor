import SwiftUI

@main
struct ScreenshotApp: App {
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ReaderView(text: ScreenshotApp.sample, baseURL: nil)
                    .navigationTitle("Notes.md")
                    .navigationBarTitleDisplayMode(.inline)
                    .environmentObject(settings)
            }
        }
    }

    static let sample = """
    # Notes

    Formatting stays. The character you type is the character on disk.

    ## Live preview

    **Bold**, *italic* and `code` sit on the same line. Markdown markers stay muted.

    - Tables
    - Task lists
    - Headings

    | Format | Result |
    | --- | --- |
    | Bold | Emphasis |
    | Code | Monospace |

    > A quote is set off by the bar on the left.

    ```swift
    func hello() {
        print("Markdown")
    }
    ```
    """
}
