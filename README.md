# ProMDEditor

A Markdown editor, viewer and **Quick Look** extension for macOS.
Select a `.md` file in Finder and press space to see it rendered; open it in the
app and you get live formatting with a side-by-side preview.

Your file is always stored as **plain `.md`** — no WYSIWYG round-trip, no lost
formatting. The character you type is the character on disk.

*[Türkçe README](README.tr.md)*

## Features

- **Live formatting.** Headings render at their real size, `**bold**` is bold,
  `*italic*` is italic, code is monospaced on a tinted background, links are
  coloured. Markdown markers stay visible in muted grey — you see the formatting
  without losing the source.
- **⌘B / ⌘I / ⌘K / ⌘E** and the whole Format menu apply to the selection and
  toggle off on a second press.
- Return continues lists and task lists automatically, and ends the list on an
  empty item.
- Split view with scroll sync (⌘1 / ⌘2 / ⌘3).
- **File comparison (⌘4).** Compare the open document with another `.md` or
  `.txt` file side by side (⇧⌘D to pick the file). Lines are aligned,
  differences highlighted word by word, long unchanged stretches fold away.
  Every diff block moves in either direction: `←` pulls the other file's block
  into the open document, `→` writes your block out to the other file (kept in
  memory — saving is a separate "Save other file" step). The other file is saved
  independently, and if it changed outside ProMDEditor you are asked before
  anything is overwritten.
- GFM: tables, task lists, strikethrough, fenced code.
- **36 themes** — Istanbul Day/Night (default), GitHub, Ayu, Night Owl,
  Kanagawa, Vitesse, Catppuccin, Gruvbox, Rosé Pine, Tokyo Night, Dracula,
  Monokai, Nord, Cobalt2, Panda, Material Ocean and high-contrast variants.
  All tuned to WCAG AAA targets: body text ≥8:1, links and muted text ≥4.6:1,
  code blocks ≥7:1 (see `Tools/fix_contrast.py`).
- Theme picker in the toolbar; light and dark themes are chosen separately and
  follow the system appearance.
- Body, heading, monospace and editor fonts are each pickable from **every font
  installed on the machine**; size, line height, content width, justification
  and a typewriter mode are adjustable.
- HTML export, and Save as PDF from the Print menu.
- The Quick Look preview uses the same theme and fonts as the app.
- **Six languages**: English, Turkish, German, Spanish, French, Italian. The UI
  follows the system language.

## Open source used

| Project | License | Role |
|---|---|---|
| [apple/swift-markdown](https://github.com/apple/swift-markdown) | Apache-2.0 | cmark-gfm based GFM parser |

The HTML renderer (`MarkdownHTMLRenderer.swift`), the editor highlighter, the
themes, the diff engine and the Quick Look extension are specific to this
project.

## Building

```bash
brew install xcodegen          # one-off
git clone https://github.com/ulkuderner/ProMDEditor.git
cd ProMDEditor
xcodegen generate
open MarkPad.xcodeproj
```

> **On the naming.** The product is called ProMDEditor, but the Xcode project,
> the targets and the Swift module are still named `MarkPad` — the app was
> renamed after the name was taken on the App Store, and only the user-facing
> name changed. Bundle identifiers (`com.caglar.MarkPad`) stayed put too,
> because they are already registered with Apple.

In Xcode:

1. Select the `MarkPad` target → **Signing & Capabilities** → pick your *Team*
   (a free Apple ID is enough). Do the same for the `MarkPadQuickLook` target.
2. Change the bundle identifiers to your own (`com.caglar.MarkPad` → yours).
3. ⌘R to run.

### About the App Group

For settings to reach the Quick Look extension, both targets need the same App
Group (macOS requires the `group.<TeamID>.com.caglar.MarkPad` shape). If you
have no Team ID, delete the `application-groups` blocks from the `.entitlements`
files — the app runs fine, and Quick Look simply falls back to the default theme
and fonts.

### Running the tests

```bash
xcodebuild -project MarkPad.xcodeproj -scheme MarkPad \
  -configuration Debug -destination 'platform=macOS' test
```

69 tests, all green. `python3 Tools/fix_contrast.py --check` verifies that every
theme still meets its contrast targets.

## Enabling Quick Look

Extensions only load when the app sits in a proper location:

```bash
# copy the .app Xcode produced into Applications
cp -R ~/Library/Developer/Xcode/DerivedData/MarkPad-*/Build/Products/Debug/ProMDEditor.app /Applications/

# register the extension and reset Quick Look
pluginkit -a /Applications/ProMDEditor.app/Contents/PlugIns/MarkPadQuickLook.appex
qlmanage -r && qlmanage -r cache
killall Finder
```

Verify:

```bash
pluginkit -m -p com.apple.quicklook.preview | grep -i markpad   # should start with + (enabled)
qlmanage -p sample.md                                           # open the preview in its own window
```

If you still see raw text: in Finder, ⌘I on a `.md` file → *Open with* →
**ProMDEditor** → *Change All*. macOS usually picks the preview provider based on
the default application.

## Layout

```
Sources/
  Shared/                       # used by both the app and the extension
    MarkdownHTMLRenderer.swift    Markdown -> HTML (MarkupVisitor)
    Theme.swift                   themes + CSS generation
    AppSettings.swift             shared settings
    TextDiff.swift                line- and word-level diff engine (Myers O(ND))
    DiffPalette.swift             comparison colours (per theme)
  App/
    MarkPadApp.swift              DocumentGroup, menus, shortcuts
    MarkdownDocument.swift        .md reading/writing
    ContentView.swift             window, toolbar, export
    EditorView.swift              NSTextView wrapper, list continuation
    MarkdownHighlighter.swift     live formatting rules
    FormatCommand.swift           ⌘B, lists, tables and other text operations
    PreviewWebView.swift          WKWebView preview
    SettingsView.swift            font/theme/layout settings
    CompareController.swift       comparison state, file I/O, block transfer
    CompareView.swift             comparison view (⌘4)
  QuickLook/
    PreviewViewController.swift   QLPreviewingController
Resources/
  Localizable.xcstrings         translations for all six languages
Tools/
  MakeIcon.swift                generates the app icon with Core Graphics
  fix_contrast.py               tunes theme palettes to WCAG targets
  make_dmg.sh                   builds Release and produces a distributable DMG
  make_appstore_pkg.sh          builds the Mac App Store .pkg
```

## Packaging

### Direct distribution (DMG)

```bash
./Tools/make_dmg.sh                                            # ad-hoc signature (local use)
./Tools/make_dmg.sh "Developer ID Application: Name (TEAMID)"  # for distribution
```

Output lands in `dist/ProMDEditor-<version>.dmg`. An ad-hoc signed package is
rejected by Gatekeeper; to open cleanly on other machines it needs a Developer ID
signature and notarization:

```bash
xcrun notarytool submit dist/ProMDEditor-1.0.dmg \
  --apple-id <apple-id> --team-id <TEAMID> --wait
xcrun stapler staple dist/ProMDEditor-1.0.dmg
```

### Mac App Store

```bash
./Tools/make_appstore_pkg.sh
```

The project meets the store requirements:

| Requirement | Status |
|---|---|
| App Sandbox | ✅ on |
| Asset catalog icon (including 1024×1024) | ✅ `Resources/Assets.xcassets` |
| `PrivacyInfo.xcprivacy` (app + extension) | ✅ no data collected, `CA92.1` for `UserDefaults` |
| `LSApplicationCategoryType` | ✅ Productivity |
| `CFBundleDisplayName` (app + extension) | ✅ required by App Store validation |
| Encryption declaration | ✅ `ITSAppUsesNonExemptEncryption = false` |

Notarization is not needed for the Mac App Store — that is only for Developer ID
distribution.

## Contributing

Contributions are welcome, and the codebase is small enough to get into in an
afternoon — pure Swift, no dependency beyond `swift-markdown`, no build magic
other than XcodeGen.

Some things worth knowing before you start:

- **The project file is generated.** Edit `project.yml`, then run
  `xcodegen generate`. Do not hand-edit `MarkPad.xcodeproj`.
- **Themes have a contrast budget.** If you add or change a theme, run
  `python3 Tools/fix_contrast.py` to tune it and `--check` to verify. A theme
  that fails the targets is a failing build in CI.
- **Every user-facing string is localized.** Add English text as the literal in
  the source, then run `xcodebuild -exportLocalizations` to get the extracted
  key and add it to `Resources/Localizable.xcstrings`. Note that a string only
  gets extracted if it reaches SwiftUI as a `LocalizedStringKey` — if you write a
  helper that takes a `String`, the string silently never appears for
  translation. Outside SwiftUI, wrap text in `String(localized:)`.
- **The Shared/ folder is shared with the extension.** Anything you put there
  has to compile in an app extension context — no `NSApplication`, no
  app-only APIs.
- Tests live in `Tests/MarkPadTests`. The diff engine in particular is worth
  covering when you touch it.

Good first areas, if you are looking for one:

- Syntax highlighting inside fenced code blocks (`highlight.js` bundled and
  wired into the generated CSS).
- A folder sidebar (`NSOutlineView` plus security-scoped bookmarks) — vault-style
  navigation.
- Mermaid diagrams (app only; JavaScript is disabled in Quick Look).
- A separate **Thumbnail Extension** for `qlmanage -t`, so Finder icons render
  too.
- Footnote and `[[wiki-link]]` support via a preprocessing step in
  `MarkdownHTMLRenderer`.
- More languages in the String Catalog.

Open an issue before starting anything large, so we do not duplicate work.

## Similar open-source projects

- [sbarex/QLMarkdown](https://github.com/sbarex/QLMarkdown) — Quick Look only, very rich
- [MacDownApp/macdown](https://github.com/MacDownApp/macdown) — classic editor, Objective-C
- [marktext/marktext](https://github.com/marktext/marktext) — Electron, true WYSIWYG
- [gonzalezreal/swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) — if you
  would rather render in pure SwiftUI than in a WebView

## License

MIT.
