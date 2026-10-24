import SwiftUI

struct FormatShortcut {
    var key: KeyEquivalent
    var modifiers: EventModifiers = .command
}

struct FormatEntry: Identifiable {
    enum Kind {
        case command(FormatCommand, FormatShortcut?)
        case submenu([FormatEntry])
        case divider
    }

    var id: String
    var title: LocalizedStringKey
    var kind: Kind

    static func command(_ id: String, _ title: LocalizedStringKey, _ command: FormatCommand,
                        _ shortcut: FormatShortcut? = nil) -> FormatEntry {
        FormatEntry(id: id, title: title, kind: .command(command, shortcut))
    }

    static func submenu(_ id: String, _ title: LocalizedStringKey, _ children: [FormatEntry]) -> FormatEntry {
        FormatEntry(id: id, title: title, kind: .submenu(children))
    }

    static func divider(_ id: String) -> FormatEntry {
        FormatEntry(id: id, title: "", kind: .divider)
    }
}

enum FormatCatalog {

    static func shortcut(_ key: Character, _ modifiers: EventModifiers = .command) -> FormatShortcut {
        FormatShortcut(key: KeyEquivalent(key), modifiers: modifiers)
    }

    static var headings: [FormatEntry] {
        [
            .command("h1", "Heading 1", .heading(1), shortcut("1", [.command, .control])),
            .command("h2", "Heading 2", .heading(2), shortcut("2", [.command, .control])),
            .command("h3", "Heading 3", .heading(3), shortcut("3", [.command, .control])),
            .command("h4", "Heading 4", .heading(4), shortcut("4", [.command, .control])),
            .command("h5", "Heading 5", .heading(5), shortcut("5", [.command, .control])),
            .command("h6", "Heading 6", .heading(6), shortcut("6", [.command, .control])),
            .command("body", "Body Text", .heading(0), shortcut("0", [.command, .control]))
        ]
    }

    static var languages: [FormatEntry] {
        let named: [(String?, String)] = [
            (nil, "Plain"),
            ("swift", "Swift"), ("python", "Python"), ("javascript", "JavaScript"),
            ("typescript", "TypeScript"), ("json", "JSON"), ("html", "HTML"), ("css", "CSS"),
            ("bash", "Shell"), ("sql", "SQL"), ("go", "Go"), ("rust", "Rust"),
            ("java", "Java"), ("kotlin", "Kotlin"), ("c", "C"), ("cpp", "C++"),
            ("ruby", "Ruby"), ("php", "PHP"), ("yaml", "YAML"), ("xml", "XML"),
            ("diff", "Diff"), ("math", "Math")
        ]
        return named.map { lang, title in
            let shortcut: FormatShortcut? = lang == nil ? shortcut("k", [.command, .shift]) : nil
            return .command("lang-\(lang ?? "plain")", LocalizedStringKey(stringLiteral: title),
                            .codeBlock(lang), shortcut)
        }
    }

    static var alerts: [FormatEntry] {
        [
            .command("alert-note", "Note", .alert(.note)),
            .command("alert-tip", "Tip", .alert(.tip)),
            .command("alert-important", "Important", .alert(.important)),
            .command("alert-warning", "Warning", .alert(.warning)),
            .command("alert-caution", "Caution", .alert(.caution))
        ]
    }

    static var tables: [FormatEntry] {
        [
            .command("table-plain", "Insert Table", .table(.plain), shortcut("t", [.command, .control])),
            .command("table-left", "Left-Aligned Table", .table(.left)),
            .command("table-center", "Centered Table", .table(.center)),
            .command("table-right", "Right-Aligned Table", .table(.right))
        ]
    }

    static var math: [FormatEntry] {
        [
            .command("math-inline", "Inline Formula", .inlineMath, shortcut("m", [.command, .control])),
            .command("math-display", "Display Formula", .formula(.display), shortcut("m", [.command, .option])),
            .divider("math-d1"),
            .command("math-frac", "Fraction", .formula(.fraction)),
            .command("math-sqrt", "Square Root", .formula(.squareRoot)),
            .command("math-pow", "Power", .formula(.power)),
            .command("math-idx", "Index", .formula(.index)),
            .command("math-sum", "Sum", .formula(.sum)),
            .command("math-int", "Integral", .formula(.integral)),
            .command("math-prod", "Product", .formula(.product)),
            .command("math-lim", "Limit", .formula(.limit)),
            .command("math-matrix", "Matrix", .formula(.matrix)),
            .command("math-cases", "Piecewise", .formula(.cases)),
            .command("math-align", "Aligned Equations", .formula(.aligned)),
            .divider("math-d2"),
            .submenu("math-greek", "Greek", greek),
            .submenu("math-sym", "Symbols", symbols)
        ]
    }

    static var greek: [FormatEntry] {
        symbolEntries([
            ("α", "alpha"), ("β", "beta"), ("γ", "gamma"), ("δ", "delta"),
            ("ε", "epsilon"), ("θ", "theta"), ("λ", "lambda"), ("μ", "mu"),
            ("π", "pi"), ("σ", "sigma"), ("φ", "phi"), ("ω", "omega")
        ], prefix: "gr")
    }

    static var symbols: [FormatEntry] {
        symbolEntries([
            ("×", "times"), ("·", "cdot"), ("±", "pm"), ("≤", "leq"), ("≥", "geq"),
            ("≠", "neq"), ("≈", "approx"), ("∞", "infty"), ("→", "to"),
            ("∂", "partial"), ("∇", "nabla"), ("∈", "in"), ("⊂", "subset"),
            ("∪", "cup"), ("∩", "cap"), ("∀", "forall"), ("∃", "exists")
        ], prefix: "sy")
    }

    static var entries: [FormatEntry] {
        [
            .command("bold", "Bold", .bold, shortcut("b")),
            .command("italic", "Italic", .italic, shortcut("i")),
            .command("bold-italic", "Bold Italic", .boldItalic, shortcut("b", [.command, .option])),
            .command("strike", "Strikethrough", .strikethrough, shortcut("x", [.command, .shift])),
            .command("icode", "Inline Code", .inlineCode, shortcut("e")),
            .divider("d1"),
            .submenu("headings", "Heading", headings),
            .divider("d2"),
            .command("bullet", "Bulleted List", .bulletList, shortcut("l", [.command, .shift])),
            .command("number", "Numbered List", .numberedList, shortcut("n", [.command, .shift])),
            .command("task", "Task List", .taskList, shortcut("t", [.command, .shift])),
            .command("toggle-task", "Toggle Task", .toggleTask),
            .command("indent", "Indent", .indent, shortcut("[")),
            .command("outdent", "Outdent", .outdent, shortcut("]")),
            .divider("d3"),
            .command("quote", "Blockquote", .blockQuote, shortcut("'", [.command, .shift])),
            .submenu("code", "Code Block", languages),
            .submenu("alert", "Alert", alerts),
            .command("hr", "Horizontal Rule", .horizontalRule, shortcut("-", [.command, .shift])),
            .command("br", "Hard Line Break", .hardLineBreak),
            .divider("d4"),
            .command("link", "Add Link…", .link, shortcut("k")),
            .command("image", "Image", .image, shortcut("i", [.command, .shift])),
            .command("autolink", "Autolink", .autolink),
            .command("reflink", "Reference Link", .referenceLink),
            .command("fn", "Footnote", .footnote, shortcut("f", [.command, .option])),
            .divider("d5"),
            .submenu("table", "Table", tables),
            .submenu("math", "Math", math)
        ]
    }

    private static func symbolEntries(_ pairs: [(String, String)], prefix: String) -> [FormatEntry] {
        pairs.map { glyph, name in
            .command("\(prefix)-\(name)", LocalizedStringKey(stringLiteral: glyph), .symbol("\\\(name)"))
        }
    }
}

struct FormatEntryRow: View {
    let entry: FormatEntry
    var shortcuts: Bool
    var perform: (FormatCommand) -> Void

    var body: some View {
        switch entry.kind {
        case .divider:
            Divider()
        case .command(let command, let shortcut):
            if shortcuts, let shortcut {
                Button(entry.title) { perform(command) }
                    .keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
            } else {
                Button(entry.title) { perform(command) }
            }
        case .submenu(let children):
            Menu(entry.title) {
                ForEach(children) { child in
                    FormatEntryRow(entry: child, shortcuts: shortcuts, perform: perform)
                }
            }
        }
    }
}

/// Yazı yüzeyinin üstündeki simge şeridi. Tam liste Biçim menüsündedir.
struct FormatToolbar: View {
    var perform: (FormatCommand) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 2) {
                icon("bold", "Bold", .bold)
                icon("italic", "Italic", .italic)
                icon("bold.italic", "Bold Italic", .boldItalic)
                icon("strikethrough", "Strikethrough", .strikethrough)
                icon("chevron.left.forwardslash.chevron.right", "Inline Code", .inlineCode)

                barDivider

                Menu {
                    ForEach(FormatCatalog.headings) { entry in
                        FormatEntryRow(entry: entry, shortcuts: false, perform: perform)
                    }
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
                .formatMenuStyle()

                barDivider

                icon("list.bullet", "Bulleted List", .bulletList)
                icon("list.number", "Numbered List", .numberedList)
                icon("checklist", "Task List", .taskList)
                icon("text.quote", "Blockquote", .blockQuote)
                icon("curlybraces", "Code Block", .codeBlock(nil))

                barDivider

                icon("link", "Add Link…", .link)
                icon("photo", "Image", .image)
                icon("tablecells", "Insert Table", .table(.plain))

                barDivider

                Menu {
                    ForEach(FormatCatalog.math) { entry in
                        FormatEntryRow(entry: entry, shortcuts: false, perform: perform)
                    }
                } label: {
                    Image(systemName: "function")
                        .frame(width: 28, height: 28)
                }
                .formatMenuStyle()
        .accessibilityLabel(Text("Math"))
        .formatHelp("Math")

                Menu {
                    ForEach(FormatCatalog.entries) { entry in
                        FormatEntryRow(entry: entry, shortcuts: false, perform: perform)
                    }
                } label: {
                    Image(systemName: "textformat")
                        .frame(width: 28, height: 28)
                }
                .formatMenuStyle()
        .accessibilityLabel(Text("Format"))
        .formatHelp("Format")
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
        .frame(height: 32)
    }

    private var barDivider: some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 6)
    }

    private func icon(_ symbol: String, _ title: LocalizedStringKey, _ command: FormatCommand) -> some View {
        Button { perform(command) } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .regular))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .formatButtonStyle()
        .accessibilityLabel(Text(title))
        .formatHelp(title)
    }
}

private extension View {
    @ViewBuilder
    func formatButtonStyle() -> some View {
        #if os(macOS)
        self.buttonStyle(.borderless)
        #else
        self.buttonStyle(.plain)
        #endif
    }

    @ViewBuilder
    func formatHelp(_ title: LocalizedStringKey) -> some View {
        #if os(macOS)
        self.help(title)
        #else
        self
        #endif
    }

    @ViewBuilder
    func formatMenuStyle() -> some View {
        #if os(macOS)
        self.menuStyle(.borderlessButton).fixedSize()
        #else
        self
        #endif
    }
}
