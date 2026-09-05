# App Review — Guideline 2.1 reply (ProMDEditor 1.0)

Paste the block below into the Resolution Center reply **and** into
App Store Connect → App Review Information → Notes.

---

Thank you for reviewing ProMDEditor. Answers to each point below.

**1. Screen recording**

A screen recording made on a physical Mac (Apple silicon, macOS 26) is attached.
It starts by launching the app and shows the typical flow: opening a .md file,
live formatting while typing, the split editor/preview view, the file comparison
mode, switching themes, and the Quick Look preview in Finder.

The app has no account registration, no login, no account deletion, no
user-generated content shared with other users, and no paid content or features,
so none of those flows appear in the recording.

**2. Purpose and target audience**

ProMDEditor is a Markdown editor, viewer and Quick Look extension for macOS.

The problem it solves: most Markdown editors convert the user's text into an
internal representation and write it back out in their own style, which changes
files that are usually kept under version control. ProMDEditor never converts.
The document is read and written as plain UTF-8 Markdown, byte for byte, so
diffs stay clean and the file opens identically in any other tool.

The value it adds on top of that fidelity is threefold: formatting is shown live
in the editor (real heading sizes, bold, italics, monospaced code) while the
Markdown markers remain visible; two Markdown files can be compared side by side
with differences highlighted word by word and moved between the files; and a
Quick Look extension renders .md files in Finder with the space bar.

Target audience: software developers, technical writers, and anyone who keeps
notes or documentation as plain Markdown files. General audience, rated 4+.

**3. Setting up and accessing the main features**

No login, account, credentials, subscription or configuration is required. The
app works offline immediately after installation.

- Launch the app. It opens a document window. File → Open, or drag any .md or
  .txt file onto the app. A sample file is attached; any Markdown file works,
  for example the README.md of https://github.com/ulkuderner/ProMDEditor
- Typing shows live formatting. ⌘B bold, ⌘I italic, ⌘K link, ⌘E inline code.
  The Format menu contains the full list.
- ⌘1 editor only, ⌘2 split editor and preview, ⌘3 preview only.
- ⌘4 enters file comparison. ⇧⌘D chooses the second file to compare against.
  Differences are highlighted; the ← and → buttons on each block move that block
  between the two files. Writing to the other file is explicit: the "Save other
  file" button in the header.
- The palette button in the toolbar switches themes; light and dark are chosen
  separately.
- ⌘, opens Settings for fonts, size, line height and content width.
- Quick Look: launch the app once, which registers the extension with the
  system. Then select any .md file in Finder and press the space bar to see it
  rendered. If Finder still shows raw text, ⌘I on the file → Open with →
  ProMDEditor → Change All, as macOS selects the preview provider from the
  default application for the type.

**4. External services, tools and platforms**

None. The app has no back end, no analytics, no advertising, no authentication
service, no payment processing and no AI or machine-learning service. It does
not communicate with any server operated by us or by a third party.

The only third-party code is Apple's open-source swift-markdown library
(https://github.com/apple/swift-markdown, Apache-2.0), compiled into the app and
used locally to parse Markdown. Rendering happens in a local WKWebView from HTML
generated on the device.

For completeness, since it is visible in the entitlements: the app declares
com.apple.security.network.client. This is required because a sandboxed
WKWebView cannot launch its content process without it, even when it only ever
displays locally generated HTML. The app itself issues no network requests. The
one case where traffic can occur is when a user's own Markdown document
references a remote image or stylesheet by URL, in which case the web view loads
that resource exactly as the user's document asked.

**5. Regional differences**

None. The app behaves identically in every region. There is no region-gated
content, no region-specific pricing, and no content served from a network, so
nothing varies by territory.

The user interface is localized into six languages — English, Turkish, German,
Spanish, French and Italian — and follows the system language. This changes only
the language of the interface; every feature is available in every language and
every region.

**6. Regulated industry or protected third-party material**

Neither applies. The app is a general-purpose text editor and does not operate in
a regulated industry.

All application code is our own and published under the MIT license at
https://github.com/ulkuderner/ProMDEditor. The only third-party component is
Apple's swift-markdown under the Apache-2.0 license, which permits this use; the
license is reproduced in the repository. No other protected or licensed material
is included.

---

## Reminders before replying

- Attach the screen recording and a sample `.md` file to the Resolution Center
  message.
- Copy the same text into App Review Information → Notes, so future submissions
  do not repeat this round.
