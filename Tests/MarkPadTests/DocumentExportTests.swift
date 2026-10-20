import XCTest
import AppKit
@testable import MarkPad

final class DocumentExportTests: XCTestCase {

    private let sample = """
    # Başlık

    **kalın** ve *italik* metin.

    - bir
    - iki

    `kod`
    """

    func testZenginMetinBaslikVeKaliniTasiyor() {
        let text = MarkdownRichText.render(sample, settings: AppSettings.shared,
                                           theme: .githubLight, baseURL: nil)
        XCTAssertTrue(text.string.contains("Başlık"))
        XCTAssertTrue(text.string.contains("kalın"))

        var bold = false
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let font = value as? NSFont else { return }
            let piece = (text.string as NSString).substring(with: range)
            guard piece.contains("kalın") else { return }
            if NSFontManager.shared.traits(of: font).contains(.boldFontMask) {
                bold = true
            }
        }
        XCTAssertTrue(bold)
    }

    func testRTFGeriOkunuyor() throws {
        let text = MarkdownRichText.render("Merhaba dünya", settings: AppSettings.shared,
                                           theme: .githubLight, baseURL: nil)
        let data = try MarkdownRichText.rtfData(text)
        XCTAssertFalse(data.isEmpty)
        let back = try NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
        XCTAssertTrue(back.string.contains("Merhaba"))
    }

    func testDocxVerisiUretiliyor() throws {
        let text = MarkdownRichText.render(sample, settings: AppSettings.shared,
                                           theme: .istanbulDay, baseURL: nil)
        let data = try MarkdownRichText.docxData(text)
        XCTAssertGreaterThan(data.count, 64)
        let header = data.prefix(2)
        let xml = String(data: data.prefix(80), encoding: .utf8) ?? ""
        let zip = header == Data([0x50, 0x4B])
        let markup = xml.contains("xml") || xml.contains("word")
        XCTAssertTrue(zip || markup)
    }

    func testHTMLDisaAktarmaKaydirmaKoprusuTasimaz() {
        let html = StyleSheet.document(bodyHTML: "<p>Hi</p>", theme: .githubLight,
                                       settings: AppSettings.shared, includeScrollBridge: false)
        XCTAssertTrue(html.contains("<p>Hi</p>"))
        XCTAssertFalse(html.contains("mpScrollTo"))
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
    }
}
