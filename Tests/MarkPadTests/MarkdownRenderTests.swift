import XCTest
@testable import MarkPad

final class MarkdownRenderTests: XCTestCase {

    func testDuzParagrafDegismez() {
        XCTAssertEqual(MarkdownHTMLRenderer.render("Hello"), "<p>Hello</p>\n")
        XCTAssertEqual(MarkdownHTMLRenderer.render("**a**"), "<p><strong>a</strong></p>\n")
    }

    func testKodIcindekiDolarMatematikOlmaz() {
        let html = MarkdownHTMLRenderer.render("`$x$`")
        XCTAssertTrue(html.contains("<code>$x$</code>"))
        XCTAssertFalse(html.contains("mp-math"))
    }

    func testCitIcindekiDolarMatematikOlmaz() {
        let html = MarkdownHTMLRenderer.render("```\n$x$\n```\n")
        XCTAssertTrue(html.contains("$x$"))
        XCTAssertFalse(html.contains("mp-math"))
        XCTAssertTrue(html.contains("<pre>"))
    }

    func testSatirIciFormulAltCizgiyiVurguSanmaz() {
        let html = MarkdownHTMLRenderer.render("Bak $x_{i}$")
        XCTAssertTrue(html.contains("data-tex=\"x_{i}\""))
        XCTAssertFalse(html.contains("<em>"))
        XCTAssertTrue(html.contains("$x_{i}$"))
    }

    func testParaBirimiFormulSayilmaz() {
        let html = MarkdownHTMLRenderer.render("Fiyat $5 ve $10")
        XCTAssertFalse(html.contains("mp-math"))
        XCTAssertTrue(html.contains("$5"))
    }

    func testBlokFormul() {
        let html = MarkdownHTMLRenderer.render("$$\n\\frac{a}{b}\n$$")
        XCTAssertTrue(html.contains("data-display=\"true\""))
        XCTAssertTrue(html.contains("data-tex=\"\\frac{a}{b}\""))
        XCTAssertFalse(html.contains("<p>$$"))
    }

    func testMatematikCit() {
        let html = MarkdownHTMLRenderer.render("```math\nE = mc^2\n```\n")
        XCTAssertTrue(html.contains("data-display=\"true\""))
        XCTAssertTrue(html.contains("E = mc^2"))
        XCTAssertFalse(html.contains("<pre>"))
    }

    func testKoseParantezFormulu() {
        let html = MarkdownHTMLRenderer.render("\\[a+b\\]")
        XCTAssertTrue(html.contains("data-display=\"true\""))
        XCTAssertTrue(html.contains("data-tex=\"a+b\""))
    }

    func testDipnot() {
        let html = MarkdownHTMLRenderer.render("Bak [^1].\n\n[^1]: Alt not\n")
        XCTAssertTrue(html.contains("href=\"#fn-1\""))
        XCTAssertTrue(html.contains("id=\"fn-1\""))
        XCTAssertTrue(html.contains("Alt not"))
        XCTAssertTrue(html.contains("class=\"footnotes\""))
        XCTAssertFalse(html.contains("[^1]"))
    }

    func testKodIcindekiDipnotDokunulmaz() {
        let html = MarkdownHTMLRenderer.render("`[^1]`")
        XCTAssertTrue(html.contains("[^1]"))
        XCTAssertFalse(html.contains("fnref"))
    }

    func testUyariKutusu() {
        let html = MarkdownHTMLRenderer.render("> [!NOTE]\n> Merhaba\n")
        XCTAssertTrue(html.contains("mp-alert"))
        XCTAssertTrue(html.contains("mp-note"))
        XCTAssertTrue(html.contains("Merhaba"))
        XCTAssertFalse(html.contains("[!NOTE]"))
    }

    func testNormalAlintiUyariDegildir() {
        let html = MarkdownHTMLRenderer.render("> Siradan\n")
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertFalse(html.contains("mp-alert"))
    }
}
