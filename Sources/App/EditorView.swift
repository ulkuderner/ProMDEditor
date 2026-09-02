import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {

    @Binding var text: String
    let settings: AppSettings
    let theme: Theme
    let controller: EditorController
    var onScroll: ((Double) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.isRichText = false                 // her zaman duz markdown
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 26, height: 24)
        textView.smartInsertDeleteEnabled = false
        textView.importsGraphics = false

        textView.string = text
        controller.textView = textView
        context.coordinator.textView = textView

        applyAppearance(textView)
        MarkdownHighlighter.highlight(textView.textStorage!, settings: settings, theme: theme)

        context.coordinator.observeScroll(scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self

        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(selection.location, text.utf16.count), length: 0))
        }
        applyAppearance(textView)
        MarkdownHighlighter.highlight(textView.textStorage!, settings: settings, theme: theme)
    }

    private func applyAppearance(_ textView: NSTextView) {
        textView.backgroundColor = theme.nsBackground
        textView.insertionPointColor = theme.nsAccent
        textView.selectedTextAttributes = [.backgroundColor: theme.nsSelection]
        textView.enclosingScrollView?.backgroundColor = theme.nsBackground
        textView.appearance = NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        weak var textView: NSTextView?
        private var formatObserver: NSObjectProtocol?

        init(_ parent: EditorView) {
            self.parent = parent
            super.init()
            formatObserver = NotificationCenter.default.addObserver(
                forName: .markPadFormat, object: nil, queue: .main
            ) { [weak self] note in
                guard let self, let command = note.object as? FormatCommand,
                      self.textView?.window?.isKeyWindow == true else { return }
                self.parent.controller.apply(command)
            }
        }

        deinit {
            if let formatObserver { NotificationCenter.default.removeObserver(formatObserver) }
        }

        func observeScroll(_ scrollView: NSScrollView) {
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView, queue: .main
            ) { [weak self, weak scrollView] _ in
                guard let scrollView, let doc = scrollView.documentView else { return }
                let visible = scrollView.contentView.bounds
                let scrollable = max(1, doc.frame.height - visible.height)
                self?.parent.onScroll?(Double(min(1, max(0, visible.origin.y / scrollable))))
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView, let storage = tv.textStorage else { return }
            parent.text = tv.string
            let selection = tv.selectedRange()
            MarkdownHighlighter.highlight(storage, settings: parent.settings, theme: parent.theme)
            tv.setSelectedRange(selection)
            if parent.settings.typewriterMode { centerInsertionPoint(tv) }
        }

        /// Return tusunda liste devami.
        func textView(_ textView: NSTextView,
                      shouldChangeTextIn affectedCharRange: NSRange,
                      replacementString: String?) -> Bool {
            guard replacementString == "\n" else { return true }
            let ns = textView.string as NSString
            let lineRange = ns.lineRange(for: NSRange(location: affectedCharRange.location, length: 0))
            let line = ns.substring(with: lineRange).trimmingCharacters(in: .newlines)

            guard let re = try? NSRegularExpression(pattern: "^(\\s*)([-*+]\\s(?:\\[[ xX]\\]\\s)?|(\\d+)\\.\\s)"),
                  let m = re.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
            else { return true }

            let lineNS = line as NSString
            let content = lineNS.substring(from: m.range.length)
            let indent = lineNS.substring(with: m.range(at: 1))

            // Bos madde: listeyi bitir
            if content.trimmingCharacters(in: .whitespaces).isEmpty {
                textView.insertText("", replacementRange: lineRange)
                return false
            }

            var marker = lineNS.substring(with: m.range(at: 2))
            if m.range(at: 3).location != NSNotFound,
               let n = Int(lineNS.substring(with: m.range(at: 3))) {
                marker = "\(n + 1). "
            }
            marker = marker.replacingOccurrences(of: "[x] ", with: "[ ] ")
                           .replacingOccurrences(of: "[X] ", with: "[ ] ")
            textView.insertText("\n" + indent + marker, replacementRange: affectedCharRange)
            return false
        }

        private func centerInsertionPoint(_ tv: NSTextView) {
            guard let layout = tv.layoutManager, let container = tv.textContainer,
                  let scrollView = tv.enclosingScrollView else { return }
            let glyphRange = layout.glyphRange(forCharacterRange: tv.selectedRange(), actualCharacterRange: nil)
            let rect = layout.boundingRect(forGlyphRange: glyphRange, in: container)
            let target = rect.midY - scrollView.contentView.bounds.height / 2
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: max(0, target)))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}
