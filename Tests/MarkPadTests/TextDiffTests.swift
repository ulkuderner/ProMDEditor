import XCTest
@testable import MarkPad

final class TextDiffTests: XCTestCase {

    // MARK: - split / join

    func testBosMetinSifirSatir() {
        let r = TextDiff.split("")
        XCTAssertEqual(r.lines, [])
        XCTAssertFalse(r.hasTrailingNewline)
    }

    func testSondaYeniSatirYok() {
        let r = TextDiff.split("bir\niki")
        XCTAssertEqual(r.lines, ["bir", "iki"])
        XCTAssertFalse(r.hasTrailingNewline)
        XCTAssertEqual(r.ending, "\n")
    }

    func testSondaYeniSatirVar() {
        let r = TextDiff.split("bir\niki\n")
        XCTAssertEqual(r.lines, ["bir", "iki"])
        XCTAssertTrue(r.hasTrailingNewline)
    }

    func testArdisikBosSatirlarKorunur() {
        let r = TextDiff.split("bir\n\niki\n")
        XCTAssertEqual(r.lines, ["bir", "", "iki"])
    }

    func testCRLFAlgilanir() {
        let input = "bir\r\niki\r\n"
        let r = TextDiff.split(input)
        XCTAssertEqual(r.lines, ["bir", "iki"])
        XCTAssertEqual(r.ending, "\r\n")
        XCTAssertTrue(r.hasTrailingNewline)
    }

    func testJoinGidisDonusAynisiniVerir() {
        for metin in ["", "a", "a\n", "a\nb", "a\nb\n", "a\n\nb\n", "bir\r\niki\r\n"] {
            let model = TextDiff.split(metin)
            XCTAssertEqual(TextDiff.join(model.lines, like: model), metin,
                           "gidis-donus bozuldu: \(metin.debugDescription)")
        }
    }
}
