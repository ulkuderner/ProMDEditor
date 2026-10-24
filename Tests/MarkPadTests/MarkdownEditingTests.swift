import XCTest
@testable import MarkPad

final class MarkdownEditingTests: XCTestCase {

    private func edit(_ command: FormatCommand, _ text: String,
                      _ range: NSRange? = nil) -> (String, NSRange) {
        let ns = text as NSString
        let selection = range ?? NSRange(location: 0, length: ns.length)
        let mutation = MarkdownEditing.mutation(command, in: text, selection: selection)
        XCTAssertLessThanOrEqual(NSMaxRange(mutation.range), ns.length)
        let out = ns.replacingCharacters(in: mutation.range, with: mutation.replacement) as String
        let outNS = out as NSString
        XCTAssertLessThanOrEqual(NSMaxRange(mutation.selection), outNS.length)
        return (out, mutation.selection)
    }

    private func selected(_ text: String, _ range: NSRange) -> String {
        (text as NSString).substring(with: range)
    }

    func testKalinSararVeGeriAlir() {
        let (wrapped, sel) = edit(.bold, "hello", NSRange(location: 0, length: 5))
        XCTAssertEqual(wrapped, "**hello**")
        XCTAssertEqual(selected(wrapped, sel), "hello")

        let (plain, _) = edit(.bold, wrapped, sel)
        XCTAssertEqual(plain, "hello")
    }

    func testBaslikAcilirVeKapanir() {
        let (headed, _) = edit(.heading(2), "Baslik", NSRange(location: 0, length: 6))
        XCTAssertEqual(headed, "## Baslik")
        let (body, _) = edit(.heading(2), headed, NSRange(location: 0, length: (headed as NSString).length))
        XCTAssertEqual(body, "Baslik")
    }

    func testBaslikAltiyaKadar() {
        let (headed, _) = edit(.heading(6), "Alt", NSRange(location: 0, length: 3))
        XCTAssertEqual(headed, "###### Alt")
    }

    func testKalınItalik() {
        let (out, sel) = edit(.boldItalic, "soz", NSRange(location: 0, length: 3))
        XCTAssertEqual(out, "***soz***")
        XCTAssertEqual(selected(out, sel), "soz")
    }

    func testListeDevamiVeBosMadde() {
        let next = MarkdownEditing.listContinuation(in: "- madde",
                                                     replacing: NSRange(location: 7, length: 0),
                                                     with: "\n")
        XCTAssertEqual(next?.replacement, "\n- ")

        let numbered = MarkdownEditing.listContinuation(in: "2. madde",
                                                         replacing: NSRange(location: 8, length: 0),
                                                         with: "\n")
        XCTAssertEqual(numbered?.replacement, "\n3. ")

        let done = MarkdownEditing.listContinuation(in: "- [x] bitti",
                                                     replacing: NSRange(location: 11, length: 0),
                                                     with: "\n")
        XCTAssertEqual(done?.replacement, "\n- [ ] ")

        let end = MarkdownEditing.listContinuation(in: "- ",
                                                    replacing: NSRange(location: 2, length: 0),
                                                    with: "\n")
        XCTAssertEqual(end?.replacement, "")
        XCTAssertEqual(end?.range.length, ("- " as NSString).length)
    }

    func testGirintiVeGorev() {
        let (indented, _) = edit(.indent, "satir", NSRange(location: 0, length: 5))
        XCTAssertEqual(indented, "  satir")
        let (outdented, _) = edit(.outdent, indented, NSRange(location: 0, length: (indented as NSString).length))
        XCTAssertEqual(outdented, "satir")

        let (task, _) = edit(.toggleTask, "is", NSRange(location: 0, length: 2))
        XCTAssertEqual(task, "- [ ] is")
        let (done, _) = edit(.toggleTask, task, NSRange(location: 0, length: (task as NSString).length))
        XCTAssertEqual(done, "- [x] is")
    }

    func testBaglantiVeGorselSecimi() {
        let (link, linkSel) = edit(.link, "", NSRange(location: 0, length: 0))
        XCTAssertEqual(selected(link, linkSel), "https://")

        let (image, imageSel) = edit(.image, "", NSRange(location: 0, length: 0))
        XCTAssertEqual(selected(image, imageSel), "file.png")
        XCTAssertTrue(image.hasPrefix("!["))
    }

    func testOtomatikVeReferansBaglantisi() {
        let (auto, autoSel) = edit(.autolink, "ornek.com", NSRange(location: 0, length: 9))
        XCTAssertEqual(auto, "<ornek.com>")
        XCTAssertEqual(selected(auto, autoSel), "ornek.com")

        let (ref, refSel) = edit(.referenceLink, "MarkPad", NSRange(location: 0, length: 7))
        XCTAssertTrue(ref.hasPrefix("[MarkPad][markpad]"))
        XCTAssertTrue(ref.contains("[markpad]: https://"))
        XCTAssertEqual(selected(ref, refSel), "https://")
    }

    func testDipnotNumarasi() {
        let (first, firstSel) = edit(.footnote, "Metin", NSRange(location: 5, length: 0))
        XCTAssertTrue(first.contains("[^1]"))
        XCTAssertTrue(first.contains("[^1]: "))
        XCTAssertEqual(selected(first, firstSel), String(localized: "note"))

        let (second, _) = edit(.footnote, first, NSRange(location: 0, length: 0))
        XCTAssertTrue(second.contains("[^2]"))
    }

    func testUyariKutusu() {
        let (out, _) = edit(.alert(.warning), "Dikkat et", NSRange(location: 0, length: 9))
        XCTAssertEqual(out, "> [!WARNING]\n> Dikkat et")
        let (off, _) = edit(.alert(.warning), out, NSRange(location: 0, length: (out as NSString).length))
        XCTAssertEqual(off, "Dikkat et")
    }

    func testKodBloguDili() {
        let (out, sel) = edit(.codeBlock("swift"), "print(1)", NSRange(location: 0, length: 8))
        XCTAssertEqual(out, "```swift\nprint(1)\n```")
        XCTAssertEqual(selected(out, sel), "print(1)")
    }

    func testSatirIciVeBlokFormul() {
        let (inline, inlineSel) = edit(.inlineMath, "E=mc^2", NSRange(location: 0, length: 6))
        XCTAssertEqual(inline, "$E=mc^2$")
        XCTAssertEqual(selected(inline, inlineSel), "E=mc^2")

        let (block, blockSel) = edit(.formula(.fraction), "", NSRange(location: 0, length: 0))
        XCTAssertTrue(block.contains("$$"))
        XCTAssertTrue(block.contains("\\frac{a}{b}"))
        XCTAssertEqual(selected(block, blockSel), "a")
    }

    func testFormulMatematikIcindeDolarEklemez() {
        let source = "$x$"
        let (out, sel) = edit(.formula(.squareRoot), source, NSRange(location: 1, length: 0))
        XCTAssertFalse(out.contains("$$"))
        XCTAssertEqual(selected(out, sel), "x")
        XCTAssertTrue(out.contains("\\sqrt{x}"))
    }

    func testSembolSatirIcineSarilir() {
        let (out, _) = edit(.symbol("\\alpha"), "", NSRange(location: 0, length: 0))
        XCTAssertEqual(out, "$\\alpha$")
    }

    func testTabloHizasi() {
        let (out, _) = edit(.table(.center), "", NSRange(location: 0, length: 0))
        XCTAssertTrue(out.contains("|:--------:|:--------:|"))
    }

    func testSertSatirSonu() {
        let (out, _) = edit(.hardLineBreak, "satir", NSRange(location: 5, length: 0))
        XCTAssertEqual(out, "satir\\\n")
    }
}
