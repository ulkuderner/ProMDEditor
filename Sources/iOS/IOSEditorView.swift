import SwiftUI
import UIKit

@MainActor
final class IOSEditorController: ObservableObject {
    weak var textView: UITextView?
    var lastSelection = NSRange(location: 0, length: 0)

    func apply(_ command: FormatCommand) {
        guard let tv = textView else { return }
        let selection = tv.isFirstResponder ? tv.selectedRange : lastSelection
        if !tv.isFirstResponder { tv.becomeFirstResponder() }
        let edit = MarkdownEditing.mutation(command, in: tv.text ?? "", selection: selection)
        guard edit.changesText else {
            tv.selectedRange = edit.selection
            lastSelection = tv.selectedRange
            return
        }
        tv.selectedRange = edit.range
        tv.insertText(edit.replacement)
        let length = (tv.text as NSString?)?.length ?? 0
        let loc = min(max(0, edit.selection.location), length)
        let span = min(max(0, edit.selection.length), length - loc)
        tv.selectedRange = NSRange(location: loc, length: span)
        lastSelection = tv.selectedRange
    }
}

struct IOSEditorView: UIViewRepresentable {
    @Binding var text: String
    let settings: AppSettings
    let theme: Theme
    let controller: IOSEditorController

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.alwaysBounceVertical = true
        view.allowsEditingTextAttributes = false
        view.dataDetectorTypes = []
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.autocorrectionType = .no
        view.spellCheckingType = .yes
        view.autocapitalizationType = .sentences
        view.textContainerInset = UIEdgeInsets(top: 18, left: 12, bottom: 24, right: 12)
        view.text = text
        controller.textView = view
        apply(theme, settings: settings, to: view)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        controller.textView = view
        if !context.coordinator.isMutating, view.markedTextRange == nil, view.text != text {
            let selection = view.selectedRange
            view.text = text
            let length = (view.text as NSString).length
            view.selectedRange = NSRange(location: min(selection.location, length), length: 0)
        }
        apply(theme, settings: settings, to: view)
    }

    private func apply(_ theme: Theme, settings: AppSettings, to view: UITextView) {
        let size = settings.editorFontSize
        let font = UIFont(name: settings.editorFontName, size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: .regular)
        view.font = font
        view.textColor = UIColor(hex: theme.fg)
        view.backgroundColor = UIColor(hex: theme.bg)
        view.tintColor = UIColor(hex: theme.accent)
        view.keyboardAppearance = theme.isDark ? .dark : .light
        view.typingAttributes = [
            .font: font,
            .foregroundColor: UIColor(hex: theme.fg)
        ]
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: IOSEditorView
        var isMutating = false

        init(_ parent: IOSEditorView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.controller.lastSelection = textView.selectedRange
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.controller.lastSelection = textView.selectedRange
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard !isMutating,
                  let edit = MarkdownEditing.listContinuation(in: textView.text ?? "", replacing: range, with: text)
            else { return true }
            isMutating = true
            textView.selectedRange = edit.range
            textView.insertText(edit.replacement)
            isMutating = false
            return false
        }
    }
}
