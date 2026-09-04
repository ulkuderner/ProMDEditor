import XCTest
@testable import MarkPad

@MainActor
final class CompareControllerTests: XCTestCase {

    private var tempDir: URL!

    /// Testlere ozel, uygulamanin canli App Group deposundan tamamen ayri
    /// bir `UserDefaults` suite'i. Boylece bookmark testleri gelistiricinin
    /// ProMDEditor ayarlarini kirletmez ve testler birbirinden yalitik kalir
    /// (bkz. Defter #7).
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        suiteName = "test.MarkPadCompare.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    /// Bookmark'a dokunan testler icin: yalitilmis suite'i kullanan denetleyici.
    private func yeniDenetleyici() -> CompareController {
        CompareController(defaults: defaults)
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

        c.undoLastPush(documentText: "a\nX\nc\n")
        XCTAssertEqual(c.otherText, "a\nY\nc\n")
        XCTAssertFalse(c.canUndo)
    }

    func testKaydetmeDiskeYazarVeRozetiTemizler() throws {
        let url = try yaz("f.md", "eski\n")
        let c = CompareController()
        try c.load(url: url)
        c.setOtherText("yeni\n", documentText: "eski\n")

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

    // MARK: - Bulgu 1: hata yolunda otherURL eski degerinde kalmali

    func testHataYolundaOtherURLEskiDegerindeKalir() throws {
        let ilkURL = try yaz("h1.md", "ilk icerik\n")
        let c = CompareController()
        try c.load(url: ilkURL)
        XCTAssertEqual(c.otherURL, ilkURL)
        XCTAssertEqual(c.otherText, "ilk icerik\n")

        // Var olmayan bir dosya: attributesOfItem/readText hata firlatir.
        let yokURL = tempDir.appendingPathComponent("olmayan.md")
        XCTAssertThrowsError(try c.load(url: yokURL))

        XCTAssertEqual(c.otherURL, ilkURL,
                        "basarisiz yukleme otherURL'i degistirmemeli")
        XCTAssertEqual(c.otherText, "ilk icerik\n",
                        "basarisiz yukleme otherText'i degistirmemeli")
    }

    // MARK: - Bulgu 2: buyuk dosya uyarisinda vazgecilirse yukleme gerceklesmemeli

    func testBuyukDosyaVazgecilirseYuklenmezVeMevcutDurumKorunur() throws {
        let url = try yaz("buyuk.md", "0123456789ABCDEF\n")
        let c = CompareController()
        // Gercek NSAlert acmadan "Vazgec" senaryosunu taklit ediyoruz.
        c.largeFileByteThresholdOverride = 5
        c.confirmLargeFile = { _ in false }

        let yuklendi = try c.load(url: url)

        XCTAssertFalse(yuklendi, "vazgecilen buyuk dosya yuklenmis sayilmamali")
        XCTAssertNil(c.otherURL, "vazgecilen yukleme otherURL atamamali")
        XCTAssertEqual(c.otherText, "",
                        "vazgecilen yukleme otherText'e dokunmamali")
        // `chooseFile()` bookmark'i yalnizca `load` true donduysa kaydeder;
        // burada dogrulanan `false` sozlesmesi bunu garanti eder. NSOpenPanel
        // testte tetiklenemedigi icin chooseFile'in kendisi bu testte
        // cagrilmiyor.
    }

    func testBuyukDosyaOnaylanirsaYuklenir() throws {
        let url = try yaz("buyuk2.md", "0123456789ABCDEF\n")
        let c = CompareController()
        c.largeFileByteThresholdOverride = 5
        c.confirmLargeFile = { _ in true }

        let yuklendi = try c.load(url: url)

        XCTAssertTrue(yuklendi)
        XCTAssertEqual(c.otherURL, url)
    }

    // MARK: - Bulgu M2: Vazgec sonrasi bayat bookmark otomatik yuklenmemeli

    func testVazgecilinceBayatBookmarkOtomatikYuklenmez() throws {
        let url = try yaz("bookmark1.md", "onceki oturum\n")
        let onceki = yeniDenetleyici()
        try onceki.load(url: url)
        // `chooseFile()`in basari yolundaki bookmark kaydini gercek panel
        // acmadan taklit ediyoruz.
        try XCTSkipUnless(onceki.storeBookmarkForTesting(url),
                          "security-scoped bookmark uretilemedi; test anlamsiz")

        // Yeni bir oturumu (yeni CompareController) ve kullanicinin ⇧⌘D
        // panelinde bilincli olarak Vazgec dedigini temsil ediyoruz.
        let c = yeniDenetleyici()
        c.declineChoiceForTesting()
        c.restoreBookmark()

        XCTAssertNil(c.otherURL,
                      "kullanici Vazgec dedikten sonra bayat bookmark otomatik yuklenmemeli")
        XCTAssertEqual(c.otherText, "",
                        "Vazgec sonrasi otherText bos kalmali")
    }

    func testVazgecmedenRestoreBookmarkNormalDavranisiKorur() throws {
        let url = try yaz("bookmark2.md", "onceki oturum 2\n")
        let onceki = yeniDenetleyici()
        try onceki.load(url: url)
        try XCTSkipUnless(onceki.storeBookmarkForTesting(url),
                          "security-scoped bookmark uretilemedi; test anlamsiz")

        // Uygulama ilk acildiginda (kullanici hic Vazgec demeden) normal akis.
        let c = yeniDenetleyici()
        c.restoreBookmark()

        XCTAssertEqual(c.otherURL, url,
                        "Vazgec denilmediyse restoreBookmark eski davranisini korumali")
        XCTAssertEqual(c.otherText, "onceki oturum 2\n")
    }

    // MARK: - Bulgu C1: "Geri al" sonrasi diff bayat kalmamali

    /// Aktarma + geri alma sonrasi `result`, artik var olmayan bir metne ait
    /// satir araliklari tutuyorsa sonraki `←` aktarmasi dizi sinirlarini asar.
    func testGeriAlSonrasiDiffYenidenHesaplanir() throws {
        let belge = "I1\nI2\nI3\nc1\nc2\nc3\nc4\nL\n"
        let url = try yaz("c1.md", "c1\nc2\nc3\nc4\nR\n")
        let c = CompareController(defaults: defaults)
        try c.load(url: url)
        c.recompute(against: belge)
        XCTAssertEqual(c.result.hunks.count, 2, "senaryo iki hunk bekliyor")

        // Ilk hunk'i saga aktar: karsi dosya 8 satira cikar.
        _ = c.apply(hunk: c.result.hunks[0], source: .left, documentText: belge)
        let aktarmaSonrasi = c.result

        c.undoLastPush(documentText: belge)

        XCTAssertNotEqual(c.result.rows, aktarmaSonrasi.rows,
                          "geri alma sonrasi diff yeniden hesaplanmali")
        // Kalan hunk'larin araliklari guncel `otherText` icinde olmali.
        let sagSatirSayisi = c.otherText.split(separator: "\n", omittingEmptySubsequences: false).count
        for hunk in c.result.hunks {
            XCTAssertLessThanOrEqual(hunk.rightLines.upperBound, sagSatirSayisi,
                                     "bayat hunk arali\u{011F}i kaldi")
        }

        // Bayat hunk cokme senaryosu: son hunk'i belgeye almak cokmemeli.
        if let son = c.result.hunks.last {
            _ = c.apply(hunk: son, source: .right, documentText: belge)
        }
    }

    func testSetOtherTextDiffiYenidenHesaplar() throws {
        let url = try yaz("c1b.md", "a\nb\n")
        let c = CompareController(defaults: defaults)
        try c.load(url: url)
        c.recompute(against: "a\nb\n")
        XCTAssertTrue(c.result.hunks.isEmpty)

        c.setOtherText("a\nZ\n", documentText: "a\nb\n")
        XCTAssertFalse(c.result.hunks.isEmpty, "otherText degisince diff guncellenmeli")
        XCTAssertTrue(c.otherIsDirty)
    }
    // MARK: - Surukle birak dosya suzgeci

    func testMarkdownVeMetinUzantilariKabulEdilir() {
        for ad in ["a.md", "a.markdown", "a.txt", "a.text", "a.mdown"] {
            XCTAssertTrue(CompareController.isComparableTextFile(URL(fileURLWithPath: "/tmp/\(ad)")),
                          "\(ad) kabul edilmeliydi")
        }
    }

    func testIkiliDosyalarReddedilir() {
        for ad in ["a.png", "a.pdf", "a.zip", "a.docx", "a.mp4"] {
            XCTAssertFalse(CompareController.isComparableTextFile(URL(fileURLWithPath: "/tmp/\(ad)")),
                           "\(ad) reddedilmeliydi")
        }
    }

    func testUzantisizVeTanimsizDosyaReddedilir() {
        XCTAssertFalse(CompareController.isComparableTextFile(URL(fileURLWithPath: "/tmp/LICENSE")))
        XCTAssertFalse(CompareController.isComparableTextFile(
            URL(fileURLWithPath: "/tmp/a.zzzbilinmeyenuzanti")))
    }

    func testBirakilanMetinDosyasiKarsilastirmaHedefiOlur() throws {
        let url = try yaz("birakilan.md", "a\nY\nc\n")
        let c = yeniDenetleyici()
        XCTAssertTrue(c.acceptDroppedFile(url, documentText: "a\nX\nc\n"))
        XCTAssertEqual(c.otherURL, url)
        XCTAssertEqual(c.result.hunks.count, 1, "birakma sonrasi diff hesaplanmali")
        XCTAssertNil(c.alertMessage)
    }

    func testBirakilanIkiliDosyaReddedilirVeUyariVerir() throws {
        let url = try yaz("resim.png", "sahte")
        let c = yeniDenetleyici()
        XCTAssertFalse(c.acceptDroppedFile(url, documentText: "a\n"))
        XCTAssertNil(c.otherURL, "reddedilen dosya hedef olmamali")
        XCTAssertNotNil(c.alertMessage, "kullaniciya sebep soylenmeli")
    }

}
