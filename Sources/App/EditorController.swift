import AppKit

/// SwiftUI tarafı ile NSTextView arasındaki köprü.
final class EditorController: ObservableObject {
    weak var textView: NSTextView?

    func apply(_ command: FormatCommand) {
        guard let tv = textView else { NSSound.beep(); return }
        let edit = MarkdownEditing.mutation(command, in: tv.string, selection: tv.selectedRange())
        guard edit.changesText else {
            tv.setSelectedRange(edit.selection)
            return
        }
        guard tv.shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
        tv.textStorage?.replaceCharacters(in: edit.range, with: edit.replacement)
        tv.didChangeText()
        let length = (tv.string as NSString).length
        let loc = min(max(0, edit.selection.location), length)
        let span = min(max(0, edit.selection.length), length - loc)
        tv.setSelectedRange(NSRange(location: loc, length: span))
    }
}
