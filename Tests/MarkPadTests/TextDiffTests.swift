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

    // MARK: - Myers

    func testMyersAyniDizilerTumunuKorur() {
        let e = TextDiff.myers(["a", "b", "c"], ["a", "b", "c"], maxD: 100)
        XCTAssertEqual(e, [.keep(left: 0, right: 0),
                           .keep(left: 1, right: 1),
                           .keep(left: 2, right: 2)])
    }

    func testMyersBosDizilerBosSonuc() {
        XCTAssertEqual(TextDiff.myers([String](), [String](), maxD: 100), [])
    }

    func testMyersSadeceEkleme() {
        let e = TextDiff.myers(["a"], ["a", "b"], maxD: 100)
        XCTAssertEqual(e, [.keep(left: 0, right: 0), .insert(right: 1)])
    }

    func testMyersSadeceSilme() {
        let e = TextDiff.myers(["a", "b"], ["a"], maxD: 100)
        XCTAssertEqual(e, [.keep(left: 0, right: 0), .delete(left: 1)])
    }

    func testMyersOrtadanDegisim() {
        let e = TextDiff.myers(["a", "x", "c"], ["a", "y", "c"], maxD: 100)
        // Indeksler dogru olmali; sira silme/ekleme ya da ekleme/silme olabilir.
        XCTAssertEqual(e?.first, .keep(left: 0, right: 0))
        XCTAssertEqual(e?.last, .keep(left: 2, right: 2))
        XCTAssertTrue(e?.contains(.delete(left: 1)) == true)
        XCTAssertTrue(e?.contains(.insert(right: 1)) == true)
    }

    /// Edit listesi her iki diziyi de bastan sona, atlamadan kapsamali.
    func testMyersEditListesiTutarli() {
        let a = ["1", "2", "3", "4", "5"]
        let b = ["2", "3", "9", "5", "6"]
        guard let edits = TextDiff.myers(a, b, maxD: 100) else {
            return XCTFail("myers nil dondu")
        }
        var solIndeksler: [Int] = [], sagIndeksler: [Int] = []
        for e in edits {
            switch e {
            case .keep(let l, let r): solIndeksler.append(l); sagIndeksler.append(r)
            case .delete(let l): solIndeksler.append(l)
            case .insert(let r): sagIndeksler.append(r)
            }
        }
        XCTAssertEqual(solIndeksler, Array(0..<a.count))
        XCTAssertEqual(sagIndeksler, Array(0..<b.count))
    }

    func testMyersMaxDAsilirsaNil() {
        let a = (0..<200).map { "sol-\($0)" }
        let b = (0..<200).map { "sag-\($0)" }
        XCTAssertNil(TextDiff.myers(a, b, maxD: 10))
    }
}
