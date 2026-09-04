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

    // MARK: - compare (satir tablosu)

    private func satirMetinleri(_ spans: [InlineSpan]) -> String {
        spans.map(\.text).joined()
    }

    func testCompareAyniDosyaTumSatirlarEsit() {
        let r = TextDiff.compare(left: "bir\niki\n", right: "bir\niki\n")
        XCTAssertEqual(r.rows.count, 2)
        XCTAssertTrue(r.rows.allSatisfy { $0.kind == .equal })
        XCTAssertFalse(r.truncated)
    }

    func testCompareEklenenSatirSoldaBosluk() {
        let r = TextDiff.compare(left: "bir\n", right: "bir\niki\n")
        XCTAssertEqual(r.rows.count, 2)
        XCTAssertEqual(r.rows[1].kind, .inserted)
        XCTAssertNil(r.rows[1].left)
        XCTAssertEqual(r.rows[1].right, 1)
        XCTAssertEqual(satirMetinleri(r.rows[1].rightSpans), "iki")
    }

    func testCompareSilinenSatirSagdaBosluk() {
        let r = TextDiff.compare(left: "bir\niki\n", right: "bir\n")
        XCTAssertEqual(r.rows[1].kind, .deleted)
        XCTAssertNil(r.rows[1].right)
        XCTAssertEqual(r.rows[1].left, 1)
    }

    func testCompareBosDosyaKarsiTumuEklenmis() {
        let r = TextDiff.compare(left: "", right: "a\nb\n")
        XCTAssertEqual(r.rows.count, 2)
        XCTAssertTrue(r.rows.allSatisfy { $0.kind == .inserted })
    }

    func testCompareIkisiDeBos() {
        let r = TextDiff.compare(left: "", right: "")
        XCTAssertTrue(r.rows.isEmpty)
    }

    /// Satir indeksleri her iki tarafta da 0'dan baslayip atlamadan artmali.
    func testCompareIndekslerTutarli() {
        let r = TextDiff.compare(left: "a\nb\nc\n", right: "a\nx\nc\nd\n")
        XCTAssertEqual(r.rows.compactMap(\.left), [0, 1, 2])
        XCTAssertEqual(r.rows.compactMap(\.right), [0, 1, 2, 3])
    }

    func testCompareCokFarkliDosyalarKirpilir() {
        let sol = (0..<4000).map { "sol satir \($0)" }.joined(separator: "\n")
        let sag = (0..<4000).map { "sag satir \($0)" }.joined(separator: "\n")
        let r = TextDiff.compare(left: sol, right: sag)
        XCTAssertTrue(r.truncated)
        XCTAssertEqual(r.rows.filter { $0.kind == .deleted }.count, 4000)
        XCTAssertEqual(r.rows.filter { $0.kind == .inserted }.count, 4000)
    }

    func testCompareKirpmaOrtakBasSonuKorur() {
        // Ortak bas ve son varken geri dusus bile onlari .equal birakmali.
        let sol = (["ayni bas"] + (0..<4000).map { "sol \($0)" } + ["ayni son"]).joined(separator: "\n")
        let sag = (["ayni bas"] + (0..<4000).map { "sag \($0)" } + ["ayni son"]).joined(separator: "\n")
        let r = TextDiff.compare(left: sol, right: sag)
        XCTAssertTrue(r.truncated)
        XCTAssertEqual(r.rows.first?.kind, .equal)
        XCTAssertEqual(r.rows.last?.kind, .equal)
    }

    // MARK: - Satir ici kelime farki

    func testTokenizeKelimeVeAyraclariAyirir() {
        XCTAssertEqual(TextDiff.tokenize("ab cd"), ["ab", " ", "cd"])
        XCTAssertEqual(TextDiff.tokenize("a, b"), ["a", ",", " ", "b"])
        XCTAssertEqual(TextDiff.tokenize(""), [])
    }

    func testInlineSpansDegisenKelimeyiIsaretler() {
        let (sol, sag) = TextDiff.inlineSpans("hizli kahverengi tilki",
                                              "hizli yesil tilki")
        XCTAssertEqual(sol.map(\.text).joined(), "hizli kahverengi tilki")
        XCTAssertEqual(sag.map(\.text).joined(), "hizli yesil tilki")
        XCTAssertTrue(sol.contains { $0.changed && $0.text.contains("kahverengi") })
        XCTAssertTrue(sag.contains { $0.changed && $0.text.contains("yesil") })
        XCTAssertTrue(sol.contains { !$0.changed && $0.text.contains("hizli") })
    }

    func testInlineSpansAyniSatirdaDegisimYok() {
        let (sol, sag) = TextDiff.inlineSpans("ayni metin", "ayni metin")
        XCTAssertFalse(sol.contains { $0.changed })
        XCTAssertFalse(sag.contains { $0.changed })
    }

    func testCompareDegisenSatirChangedOlur() {
        let r = TextDiff.compare(left: "bas\nhizli tilki\nson\n",
                                 right: "bas\nyavas tilki\nson\n")
        XCTAssertEqual(r.rows.count, 3)
        XCTAssertEqual(r.rows[1].kind, .changed)
        XCTAssertEqual(r.rows[1].left, 1)
        XCTAssertEqual(r.rows[1].right, 1)
        XCTAssertEqual(r.rows[1].leftSpans.map(\.text).joined(), "hizli tilki")
        XCTAssertEqual(r.rows[1].rightSpans.map(\.text).joined(), "yavas tilki")
        XCTAssertTrue(r.rows[1].leftSpans.contains { !$0.changed })
    }

    func testCompareEsitsizSayidaSatirEslesmez() {
        // 1 silinen, 2 eklenen -> eslestirilemez, .changed olusmaz.
        let r = TextDiff.compare(left: "bas\nbir\nson\n",
                                 right: "bas\nbir-a\nbir-b\nson\n")
        XCTAssertFalse(r.rows.contains { $0.kind == .changed })
    }

    func testUnicodeSatirlarBozulmaz() {
        let sol = "merhaba 👋 dünya\n"
        let sag = "merhaba 👋 evren\n"
        let r = TextDiff.compare(left: sol, right: sag)
        XCTAssertEqual(r.rows[0].leftSpans.map(\.text).joined(), "merhaba 👋 dünya")
        XCTAssertEqual(r.rows[0].rightSpans.map(\.text).joined(), "merhaba 👋 evren")
    }

    // MARK: - Hunk gruplama

    func testHunkYokAyniDosyada() {
        XCTAssertTrue(TextDiff.compare(left: "a\nb\n", right: "a\nb\n").hunks.isEmpty)
    }

    func testTekHunk() {
        let r = TextDiff.compare(left: "a\nb\nc\n", right: "a\nX\nc\n")
        XCTAssertEqual(r.hunks.count, 1)
        XCTAssertEqual(r.hunks[0].leftLines, 1..<2)
        XCTAssertEqual(r.hunks[0].rightLines, 1..<2)
    }

    func testYakinFarklarTekHunktaBirlesir() {
        // Iki fark arasinda 2 esit satir var (< 3) -> birlesmeli.
        let sol = "a\nX\nc\nd\nY\nf\n"
        let sag = "a\n1\nc\nd\n2\nf\n"
        XCTAssertEqual(TextDiff.compare(left: sol, right: sag).hunks.count, 1)
    }

    func testUzakFarklarAyriHunk() {
        // Iki fark arasinda 5 esit satir var (>= 3) -> ayrilmali.
        let sol = "a\nX\nc\nd\ne\nf\ng\nY\ni\n"
        let sag = "a\n1\nc\nd\ne\nf\ng\n2\ni\n"
        XCTAssertEqual(TextDiff.compare(left: sol, right: sag).hunks.count, 2)
    }

    func testSafEklemeHunkuBosSolAralik() {
        let r = TextDiff.compare(left: "a\nc\n", right: "a\nb\nc\n")
        XCTAssertEqual(r.hunks.count, 1)
        XCTAssertTrue(r.hunks[0].leftLines.isEmpty)
        XCTAssertEqual(r.hunks[0].leftLines.lowerBound, 1)   // "a"dan sonra
        XCTAssertEqual(r.hunks[0].rightLines, 1..<2)
    }

    func testSafSilmeHunkuBosSagAralik() {
        let r = TextDiff.compare(left: "a\nb\nc\n", right: "a\nc\n")
        XCTAssertEqual(r.hunks.count, 1)
        XCTAssertEqual(r.hunks[0].leftLines, 1..<2)
        XCTAssertTrue(r.hunks[0].rightLines.isEmpty)
        XCTAssertEqual(r.hunks[0].rightLines.lowerBound, 1)
    }

    func testBastakiEklemeHunkuSifirdanBaslar() {
        let r = TextDiff.compare(left: "b\n", right: "a\nb\n")
        XCTAssertEqual(r.hunks[0].leftLines.lowerBound, 0)
        XCTAssertTrue(r.hunks[0].leftLines.isEmpty)
    }

    func testHunkIdleriSirali() {
        let sol = "a\nX\nc\nd\ne\nf\ng\nY\ni\n"
        let sag = "a\n1\nc\nd\ne\nf\ng\n2\ni\n"
        XCTAssertEqual(TextDiff.compare(left: sol, right: sag).hunks.map(\.id), [0, 1])
    }
}
