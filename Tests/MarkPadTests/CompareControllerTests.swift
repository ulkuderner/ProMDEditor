import XCTest
@testable import MarkPad

@MainActor
final class CompareControllerTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func yaz(_ ad: String, _ icerik: String) throws -> URL {
        let url = tempDir.appendingPathComponent(ad)
        try Data(icerik.utf8).write(to: url)
        return url
    }

    func testUTF8DosyaOkunur() throws {
        let url = try yaz("a.md", "# Başlık\nİçerik\n")
        XCTAssertEqual(try CompareController.readText(at: url), "# Başlık\nİçerik\n")
    }

    func testLatin1DosyayaGeriDusulur() throws {
        let url = tempDir.appendingPathComponent("latin.md")
        try "cafe\u{00E9}".data(using: .isoLatin1)!.write(to: url)
        XCTAssertNoThrow(try CompareController.readText(at: url))
    }

    func testYuklemeSonrasiDiffHesaplanir() throws {
        let url = try yaz("b.md", "a\nY\nc\n")
        let c = CompareController()
        try c.load(url: url)
        c.recompute(against: "a\nX\nc\n")
        XCTAssertEqual(c.result.hunks.count, 1)
        XCTAssertEqual(c.otherURL, url)
        XCTAssertFalse(c.otherIsDirty)
    }

    func testSagdanAlmaBelgeMetniniDondurur() throws {
        let url = try yaz("c.md", "a\nY\nc\n")
        let c = CompareController()
        try c.load(url: url)
        c.recompute(against: "a\nX\nc\n")

        let yeni = c.apply(hunk: c.result.hunks[0], source: .right, documentText: "a\nX\nc\n")
        XCTAssertEqual(yeni, "a\nY\nc\n")
        XCTAssertFalse(c.otherIsDirty, "sagdan alma karsi dosyayi kirletmemeli")
    }

    func testSolaVermeKarsiDosyayiKirletir() throws {
        let url = try yaz("d.md", "a\nY\nc\n")
        let c = CompareController()
        try c.load(url: url)
        c.recompute(against: "a\nX\nc\n")

        let yeni = c.apply(hunk: c.result.hunks[0], source: .left, documentText: "a\nX\nc\n")
        XCTAssertEqual(yeni, "a\nX\nc\n", "belge metni degismemeli")
        XCTAssertEqual(c.otherText, "a\nX\nc\n")
        XCTAssertTrue(c.otherIsDirty)
        XCTAssertTrue(c.canUndo)
    }

    func testGeriAlSonAktarmayiIptalEder() throws {
        let url = try yaz("e.md", "a\nY\nc\n")
        let c = CompareController()
        try c.load(url: url)
        c.recompute(against: "a\nX\nc\n")
        _ = c.apply(hunk: c.result.hunks[0], source: .left, documentText: "a\nX\nc\n")

        c.undoLastPush()
        XCTAssertEqual(c.otherText, "a\nY\nc\n")
        XCTAssertFalse(c.canUndo)
    }

    func testKaydetmeDiskeYazarVeRozetiTemizler() throws {
        let url = try yaz("f.md", "eski\n")
        let c = CompareController()
        try c.load(url: url)
        c.otherText = "yeni\n"
        c.markDirtyForTesting()

        c.saveOther()
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "yeni\n")
        XCTAssertFalse(c.otherIsDirty)
        XCTAssertNil(c.alertMessage)
    }

    func testDisaridanDegismisDosyaTespitEdilir() throws {
        let url = try yaz("g.md", "ilk\n")
        let c = CompareController()
        try c.load(url: url)

        // Dosyayi disaridan degistir; tarih farki olussun diye bekle.
        Thread.sleep(forTimeInterval: 1.1)
        try Data("baskasi yazdi\n".utf8).write(to: url)

        XCTAssertTrue(c.otherChangedOnDisk())
    }
}
