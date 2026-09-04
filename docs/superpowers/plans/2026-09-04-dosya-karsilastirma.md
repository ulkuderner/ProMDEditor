# Dosya Karşılaştırma (Diff) ve Çift Yönlü Aktarma — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** MarkPad'de açık belgeyi diskteki başka bir Markdown dosyasıyla hizalı olarak karşılaştırmak ve fark bloklarını iki yönde de aktarabilmek.

**Architecture:** Saf Swift bir diff motoru (`Sources/Shared/TextDiff.swift`) Myers O(ND) algoritmasıyla satır farklarını, aynı algoritmayı kelime token'larına uygulayarak satır içi farkları üretir. `CompareController` dosya seçme/okuma/yazma ve durum yönetimini üstlenir; `CompareView` tek kaydırma alanında satır tablosu çizerek iki panelin hizasını yapısal olarak garanti eder. Karşılaştırma, mevcut `ViewMode` seçicisine eklenen 4. bir mod olarak belge penceresinde yaşar.

**Tech Stack:** Swift 5.9, SwiftUI + AppKit (macOS 13+), XcodeGen (`project.yml`), XCTest. Harici diff kütüphanesi **yok** — motor elle yazılır.

**Spec:** `docs/superpowers/specs/2026-09-04-dosya-karsilastirma-design.md`

## Global Constraints

- Deployment target macOS 13.0; Swift 5.9. `project.yml`'deki `settingGroups.common` her yeni hedefe uygulanır.
- Proje dosyası elle düzenlenmez. `project.yml` değişince **`xcodegen generate`** çalıştırılır.
- `Sources/Shared/` hem `MarkPad` hem `MarkPadQuickLook` hedeflerince derlenir. Buraya konan kod SwiftUI'ye bağımlı **olmamalıdır** (AppKit serbest).
- Entitlement dosyaları değiştirilmez. Gereken haklar (`files.user-selected.read-write`, `files.bookmarks.app-scope`) zaten `Sources/App/MarkPad.entitlements` içinde.
- Kullanıcıya görünen tüm metinler **Türkçe**dir. Kod içi yorumlar mevcut kodun tarzını izler: Türkçe, ASCII harflerle (`gorunum`, `karsilastirma` gibi), `///` ile belge yorumu.
- Yeni harici bağımlılık eklenmez. `project.yml`'deki `packages` bloğu değişmez.
- Commit mesajları Türkçe, AI atıf satırı **içermez** (kullanıcı tercihi).
- Diff motorunun kamuya açık API'si: `TextDiff.compare(left:right:)` ve `TextDiff.apply(hunk:source:left:right:)`. Görünüm katmanı bunların dışında bir şey çağırmaz.

## Doğrulama komutları

Bu plan boyunca kullanılan iki komut. Her ikisi de proje kökünden çalışır.

Derleme + test:

```bash
xcodegen generate && xcodebuild -project MarkPad.xcodeproj -scheme MarkPad \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath .build \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" test 2>&1 | tail -30
```

Tek bir test sınıfını çalıştırmak için yukarıdaki komuta şunu ekle:

```
-only-testing:MarkPadTests/TextDiffTests
```

---

### Task 1: Test hedefi kurulumu

Projede hiç test hedefi yok. Motoru TDD ile yazabilmek için önce çalışan bir test altyapısı gerekiyor.

**Files:**
- Modify: `project.yml` (targets bloğunun sonu ve schemes bloğu)
- Create: `Tests/MarkPadTests/SmokeTests.swift`

**Interfaces:**
- Consumes: yok (ilk görev)
- Produces: `MarkPadTests` XCTest hedefi. Sonraki tüm test dosyaları `Tests/MarkPadTests/` altına konur ve `@testable import MarkPad` kullanır.

- [ ] **Step 1: Test hedefini `project.yml`'ye ekle**

`targets:` bloğunun sonuna, `MarkPadQuickLook` hedefinden **sonra** ekle:

```yaml
  MarkPadTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests/MarkPadTests
    dependencies:
      - target: MarkPad
    settings:
      groups: [common]
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.caglar.MarkPad.Tests
        GENERATE_INFOPLIST_FILE: YES
```

- [ ] **Step 2: Şemaya test adımını ekle**

Dosyanın sonundaki `schemes:` bloğunu tamamen şununla değiştir:

```yaml
schemes:
  MarkPad:
    build:
      targets:
        MarkPad: all
        MarkPadTests: [test]
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - MarkPadTests
    archive:
      config: Release
```

- [ ] **Step 3: Başarısız olacak testi yaz**

`Tests/MarkPadTests/SmokeTests.swift`:

```swift
import XCTest
@testable import MarkPad

/// Test altyapisinin ayakta oldugunu dogrular.
final class SmokeTests: XCTestCase {

    func testTestHedefiCalisiyor() {
        XCTAssertEqual(2 + 2, 4)
    }

    /// Uygulama hedefinin sembollerine erisebildigimizi dogrular.
    func testUygulamaSembolleriGorunuyor() {
        XCTAssertFalse(MarkdownDocument.starterText.isEmpty)
    }
}
```

- [ ] **Step 4: Testi çalıştır**

```bash
xcodegen generate && xcodebuild -project MarkPad.xcodeproj -scheme MarkPad \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath .build \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" test 2>&1 | tail -30
```

Beklenen: `** TEST SUCCEEDED **`, 2 test geçti.

Hata alırsan: `bundle.unit-test` hedefi uygulama içinde barındığı için imzalama sorunu çıkabilir. `TEST_HOST` ve `BUNDLE_LOADER` ayarlarını XcodeGen otomatik kurar; sorun sürerse hedefe `settings.base.TEST_HOST` eklemek yerine önce `xcodegen generate` çıktısını oku.

- [ ] **Step 5: Commit**

```bash
git add project.yml Tests/MarkPadTests/SmokeTests.swift
git commit -m "Test hedefi ekle: MarkPadTests"
```

---

### Task 2: Satır bölme ve birleştirme

Diff motorunun temeli. Satır sonu biçimini (LF/CRLF) ve sondaki yeni satırı koruyacak şekilde metni satırlara böler.

**Files:**
- Create: `Sources/Shared/TextDiff.swift`
- Create: `Tests/MarkPadTests/TextDiffTests.swift`

**Interfaces:**
- Consumes: Task 1'in `MarkPadTests` hedefi
- Produces:
  - `enum TextDiff` (namespace)
  - `struct TextDiff.Lines: Equatable { var lines: [String]; var ending: String; var hasTrailingNewline: Bool }`
  - `static func TextDiff.split(_ text: String) -> Lines`
  - `static func TextDiff.join(_ lines: [String], like model: Lines) -> String`

- [ ] **Step 1: Başarısız olacak testleri yaz**

`Tests/MarkPadTests/TextDiffTests.swift`:

```swift
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
        let r = TextDiff.split("bir\r\niki\r\n")
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
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Komutu `-only-testing:MarkPadTests/TextDiffTests` ile çalıştır.
Beklenen: derleme hatası, `cannot find 'TextDiff' in scope`.

- [ ] **Step 3: `TextDiff.split` / `join` yaz**

`Sources/Shared/TextDiff.swift`:

```swift
import Foundation

/// İki metin arasindaki farki hesaplayan saf motor.
/// Dosya sistemi, tema ve arayuz bilmez; girdisi ve ciktisi degerdir.
enum TextDiff {

    /// Bir metnin satirlari ve bicim bilgisi.
    /// `lines` satir sonu karakterlerini icermez; bicim `ending` ve
    /// `hasTrailingNewline` ile ayrica tasinir, boylece `join` orijinali
    /// birebir geri kurabilir.
    struct Lines: Equatable {
        var lines: [String]
        var ending: String
        var hasTrailingNewline: Bool
    }

    /// Metni LF, CRLF ve CR ayraclarinda satirlara boler.
    static func split(_ text: String) -> Lines {
        if text.isEmpty {
            return Lines(lines: [], ending: "\n", hasTrailingNewline: false)
        }

        let ending = text.contains("\r\n") ? "\r\n" : "\n"
        let hasTrailing = text.hasSuffix("\n") || text.hasSuffix("\r")

        var lines: [String] = []
        var current = ""
        var i = text.startIndex

        while i < text.endIndex {
            let c = text[i]
            if c == "\r" {
                lines.append(current)
                current = ""
                let next = text.index(after: i)
                // CRLF tek ayrac sayilir
                i = (next < text.endIndex && text[next] == "\n") ? text.index(after: next) : next
            } else if c == "\n" {
                lines.append(current)
                current = ""
                i = text.index(after: i)
            } else {
                current.append(c)
                i = text.index(after: i)
            }
        }

        // Son satir ayracla bitmediyse henuz eklenmemistir.
        if !hasTrailing { lines.append(current) }
        return Lines(lines: lines, ending: ending, hasTrailingNewline: hasTrailing)
    }

    /// Satirlari `model`in bicimiyle (ayrac + sondaki yeni satir) birlestirir.
    static func join(_ lines: [String], like model: Lines) -> String {
        if lines.isEmpty { return "" }
        var s = lines.joined(separator: model.ending)
        if model.hasTrailingNewline { s += model.ending }
        return s
    }
}
```

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Komutu `-only-testing:MarkPadTests/TextDiffTests` ile çalıştır.
Beklenen: `** TEST SUCCEEDED **`, 6 test geçti.

- [ ] **Step 5: Commit**

```bash
git add Sources/Shared/TextDiff.swift Tests/MarkPadTests/TextDiffTests.swift
git commit -m "TextDiff: satir bolme ve birlestirme"
```

---

### Task 3: Myers O(ND) çekirdek algoritması

Diff'in kalbi. Genel (`Equatable`) bir dizi çifti üzerinde çalışır; hem satırlar hem kelime token'ları için kullanılır.

**Files:**
- Modify: `Sources/Shared/TextDiff.swift` (dosyanın sonuna extension)
- Modify: `Tests/MarkPadTests/TextDiffTests.swift` (yeni testler ekle)

**Interfaces:**
- Consumes: `TextDiff` namespace (Task 2)
- Produces:
  - `enum TextDiff.Edit: Equatable { case keep(left: Int, right: Int); case delete(left: Int); case insert(right: Int) }`
  - `static func TextDiff.myers<T: Equatable>(_ a: [T], _ b: [T], maxD: Int) -> [Edit]?` — `maxD` aşılırsa `nil`.

- [ ] **Step 1: Başarısız olacak testleri yaz**

`TextDiffTests.swift` içine, sınıfın sonuna ekle:

```swift
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
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Beklenen: derleme hatası, `type 'TextDiff' has no member 'myers'`.

- [ ] **Step 3: Myers'ı yaz**

`Sources/Shared/TextDiff.swift` dosyasının **sonuna** ekle:

```swift
// MARK: - Myers O(ND) diff

extension TextDiff {

    /// Tek bir duzenleme adimi. Indeksler kaynak dizilere aittir.
    enum Edit: Equatable {
        case keep(left: Int, right: Int)
        case delete(left: Int)
        case insert(right: Int)
    }

    /// Myers'in greedy O(ND) algoritmasi.
    ///
    /// Maliyet dizilerin boyutuyla degil, **fark sayisiyla** (D) orantilidir;
    /// benzer iki dosyada D kucuktur. Klasik LCS matrisi yerine bu secildi
    /// cunku LCS O(n*m) bellek ister (5.000x5.000 satir = ~25M hucre).
    ///
    /// - Parameter maxD: izin verilen en buyuk fark sayisi. Asilirsa `nil`
    ///   doner ve cagiran kaba bir geri dusus uygular.
    static func myers<T: Equatable>(_ a: [T], _ b: [T], maxD: Int) -> [Edit]? {
        let n = a.count, m = b.count
        let bound = n + m
        if bound == 0 { return [] }

        let offset = bound
        var v = [Int](repeating: 0, count: 2 * bound + 1)
        var trace: [[Int]] = []

        var d = 0
        while d <= min(bound, maxD) {
            trace.append(v)          // trace[d] = d turunun BASINDAKI durum
            var k = -d
            while k <= d {
                var x: Int
                // k == -d ve k == d kenarlarinda kisa devre sart:
                // v[k-1] / v[k+1] o durumlarda dizi disina taşar.
                if k == -d || (k != d && v[k - 1 + offset] < v[k + 1 + offset]) {
                    x = v[k + 1 + offset]
                } else {
                    x = v[k - 1 + offset] + 1
                }
                var y = x - k
                while x < n && y < m && a[x] == b[y] { x += 1; y += 1 }
                v[k + offset] = x
                if x >= n && y >= m {
                    return backtrack(trace, offset: offset, n: n, m: m)
                }
                k += 2
            }
            d += 1
        }
        return nil
    }

    /// Kaydedilmis `V` durumlarindan geriye yurüyerek edit listesini kurar.
    private static func backtrack(_ trace: [[Int]], offset: Int, n: Int, m: Int) -> [Edit] {
        var edits: [Edit] = []
        var x = n, y = m

        for d in stride(from: trace.count - 1, through: 0, by: -1) {
            let v = trace[d]
            let k = x - y
            let prevK: Int
            if k == -d || (k != d && v[k - 1 + offset] < v[k + 1 + offset]) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }
            let prevX = v[prevK + offset]
            let prevY = prevX - prevK

            while x > prevX && y > prevY {
                edits.append(.keep(left: x - 1, right: y - 1))
                x -= 1; y -= 1
            }
            if d > 0 {
                if x == prevX {
                    edits.append(.insert(right: y - 1))
                } else {
                    edits.append(.delete(left: x - 1))
                }
            }
            x = prevX; y = prevY
        }
        return edits.reversed()
    }
}
```

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Beklenen: `** TEST SUCCEEDED **`, 13 test geçti.

- [ ] **Step 5: Commit**

```bash
git add Sources/Shared/TextDiff.swift Tests/MarkPadTests/TextDiffTests.swift
git commit -m "TextDiff: Myers O(ND) cekirdek algoritmasi"
```

---

### Task 4: Satır tablosu üretimi (`compare`)

Edit listesini ekranda çizilecek hizalı satır tablosuna dönüştürür. Ortak baş/son kırpma ve D-limiti geri düşüşü burada.

**Files:**
- Modify: `Sources/Shared/TextDiff.swift`
- Modify: `Tests/MarkPadTests/TextDiffTests.swift`

**Interfaces:**
- Consumes: `TextDiff.split`, `TextDiff.myers` (Task 2, 3)
- Produces:
  - `enum DiffLineKind { case equal, inserted, deleted, changed }`
  - `struct InlineSpan: Equatable { let text: String; let changed: Bool }`
  - `struct DiffRow: Equatable { let left: Int?; let right: Int?; let kind: DiffLineKind; let leftSpans: [InlineSpan]; let rightSpans: [InlineSpan] }`
  - `struct DiffHunk: Identifiable, Equatable { let id: Int; let rows: Range<Int>; let leftLines: Range<Int>; let rightLines: Range<Int> }`
  - `struct DiffResult: Equatable { let rows: [DiffRow]; let hunks: [DiffHunk]; let truncated: Bool }`
  - `static func TextDiff.compare(left: String, right: String) -> DiffResult`

Bu görevde `compare` yalnız `.equal` / `.inserted` / `.deleted` üretir ve `hunks` boş döner. `.changed` Task 5'te, `hunks` Task 6'da eklenir.

- [ ] **Step 1: Başarısız olacak testleri yaz**

`TextDiffTests.swift` sonuna ekle:

```swift
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
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Beklenen: derleme hatası, `cannot find 'InlineSpan' in scope`.

- [ ] **Step 3: Tipleri ve `compare`'i yaz**

`Sources/Shared/TextDiff.swift` sonuna ekle:

```swift
// MARK: - Sonuc tipleri

enum DiffLineKind {
    case equal, inserted, deleted, changed
}

/// Bir satirin icindeki parca. Parcalarin `text` birlesimi satirin
/// birebir kendisidir; bu degismez tum uretim yollarinda korunur.
struct InlineSpan: Equatable {
    let text: String
    let changed: Bool
}

/// Tabloda tek bir gorsel satir.
/// `left` / `right`, ilgili taraftaki 0 tabanli satir indeksidir;
/// o tarafta karsiligi yoksa nil olur ve bos dolgu cizilir.
struct DiffRow: Equatable {
    let left: Int?
    let right: Int?
    let kind: DiffLineKind
    let leftSpans: [InlineSpan]
    let rightSpans: [InlineSpan]
}

/// Bitisik farkli satirlarin olusturdugu blok.
/// `rows` satir tablosundaki aralik; `leftLines` / `rightLines` kaynak
/// metinlerdeki aralik. Saf ekleme/silmede bunlardan biri bos araliktir.
struct DiffHunk: Identifiable, Equatable {
    let id: Int
    let rows: Range<Int>
    let leftLines: Range<Int>
    let rightLines: Range<Int>
}

struct DiffResult: Equatable {
    let rows: [DiffRow]
    let hunks: [DiffHunk]
    let truncated: Bool

    static let empty = DiffResult(rows: [], hunks: [], truncated: false)
}

// MARK: - compare

extension TextDiff {

    /// Fark sayisi bu esigi asarsa kaba geri dusus uygulanir.
    static let maxDifferences = 5000

    static func compare(left: String, right: String) -> DiffResult {
        let a = split(left).lines
        let b = split(right).lines

        // Ortak bas ve son satirlari kirp: tipik duzenlemede farkin
        // buyuk kismini eler ve Myers'i kucuk bir bolgede calistirir.
        var head = 0
        while head < a.count && head < b.count && a[head] == b[head] { head += 1 }

        var tail = 0
        while tail < a.count - head && tail < b.count - head
                && a[a.count - 1 - tail] == b[b.count - 1 - tail] { tail += 1 }

        let aMid = Array(a[head..<(a.count - tail)])
        let bMid = Array(b[head..<(b.count - tail)])

        var rows: [DiffRow] = []
        rows.reserveCapacity(a.count + b.count)

        for i in 0..<head {
            rows.append(equalRow(left: i, right: i, text: a[i]))
        }

        var truncated = false
        if let edits = myers(aMid, bMid, maxD: maxDifferences) {
            for e in edits {
                switch e {
                case .keep(let l, let r):
                    rows.append(equalRow(left: head + l, right: head + r, text: aMid[l]))
                case .delete(let l):
                    rows.append(DiffRow(left: head + l, right: nil, kind: .deleted,
                                        leftSpans: [InlineSpan(text: aMid[l], changed: true)],
                                        rightSpans: []))
                case .insert(let r):
                    rows.append(DiffRow(left: nil, right: head + r, kind: .inserted,
                                        leftSpans: [],
                                        rightSpans: [InlineSpan(text: bMid[r], changed: true)]))
                }
            }
        } else {
            // Geri dusus: orta bolgenin tamami silinmis + tamami eklenmis.
            truncated = true
            for (l, line) in aMid.enumerated() {
                rows.append(DiffRow(left: head + l, right: nil, kind: .deleted,
                                    leftSpans: [InlineSpan(text: line, changed: true)],
                                    rightSpans: []))
            }
            for (r, line) in bMid.enumerated() {
                rows.append(DiffRow(left: nil, right: head + r, kind: .inserted,
                                    leftSpans: [],
                                    rightSpans: [InlineSpan(text: line, changed: true)]))
            }
        }

        for t in 0..<tail {
            let l = a.count - tail + t
            let r = b.count - tail + t
            rows.append(equalRow(left: l, right: r, text: a[l]))
        }

        return DiffResult(rows: rows, hunks: [], truncated: truncated)
    }

    private static func equalRow(left: Int, right: Int, text: String) -> DiffRow {
        let span = [InlineSpan(text: text, changed: false)]
        return DiffRow(left: left, right: right, kind: .equal,
                       leftSpans: span, rightSpans: span)
    }
}
```

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Beklenen: `** TEST SUCCEEDED **`, 21 test geçti.

- [ ] **Step 5: Commit**

```bash
git add Sources/Shared/TextDiff.swift Tests/MarkPadTests/TextDiffTests.swift
git commit -m "TextDiff: satir tablosu uretimi ve kirpma"
```

---

### Task 5: Satır içi kelime farkı

Silinen ve eklenen satır sayısı eşit olan bloklarda satırları eşler, `.changed` yapar ve değişen kelimeleri işaretler.

**Files:**
- Modify: `Sources/Shared/TextDiff.swift`
- Modify: `Tests/MarkPadTests/TextDiffTests.swift`

**Interfaces:**
- Consumes: `TextDiff.myers`, `DiffRow`, `InlineSpan` (Task 3, 4)
- Produces:
  - `static func TextDiff.tokenize(_ line: String) -> [String]`
  - `static func TextDiff.inlineSpans(_ a: String, _ b: String) -> (left: [InlineSpan], right: [InlineSpan])`
  - `compare` artık `.changed` satırlar üretir.

- [ ] **Step 1: Başarısız olacak testleri yaz**

`TextDiffTests.swift` sonuna ekle:

```swift
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
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Beklenen: derleme hatası, `type 'TextDiff' has no member 'tokenize'`.

- [ ] **Step 3: Token'lama ve eşleştirmeyi yaz**

`Sources/Shared/TextDiff.swift` sonuna ekle:

```swift
// MARK: - Satir ici kelime farki

extension TextDiff {

    /// Satiri harf/rakam dizileri ve tek tek diger karakterler olarak boler.
    /// Bosluklar token olarak korunur; boylece token'larin birlesimi
    /// satirin birebir kendisidir.
    static func tokenize(_ line: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var currentIsWord = false

        for ch in line {
            let isWord = ch.isLetter || ch.isNumber
            if current.isEmpty {
                current = String(ch)
                currentIsWord = isWord
            } else if isWord && currentIsWord {
                current.append(ch)
            } else {
                tokens.append(current)
                current = String(ch)
                currentIsWord = isWord
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Iki satirin kelime duzeyinde farkini parcalara doker.
    static func inlineSpans(_ a: String, _ b: String) -> (left: [InlineSpan], right: [InlineSpan]) {
        let ta = tokenize(a), tb = tokenize(b)

        // Satir ici icin dusuk esik yeter; asilirsa tum satir degismis sayilir.
        guard let edits = myers(ta, tb, maxD: 400) else {
            return ([InlineSpan(text: a, changed: true)],
                    [InlineSpan(text: b, changed: true)])
        }

        var left: [InlineSpan] = [], right: [InlineSpan] = []
        for e in edits {
            switch e {
            case .keep(let l, let r):
                appendSpan(&left, ta[l], changed: false)
                appendSpan(&right, tb[r], changed: false)
            case .delete(let l):
                appendSpan(&left, ta[l], changed: true)
            case .insert(let r):
                appendSpan(&right, tb[r], changed: true)
            }
        }
        return (left, right)
    }

    /// Ayni isarete sahip ardisik parcalari birlestirir; arayuzde
    /// parca basina bir gorunum yaratmamak icin.
    private static func appendSpan(_ spans: inout [InlineSpan], _ text: String, changed: Bool) {
        if let last = spans.last, last.changed == changed {
            spans[spans.count - 1] = InlineSpan(text: last.text + text, changed: changed)
        } else {
            spans.append(InlineSpan(text: text, changed: changed))
        }
    }

    /// Bitisik silme/ekleme kosularini, sayilari esitse 1-1 eslestirip
    /// `.changed` satirlara donusturur.
    static func pairChanges(_ rows: [DiffRow]) -> [DiffRow] {
        var result: [DiffRow] = []
        result.reserveCapacity(rows.count)
        var i = 0

        while i < rows.count {
            guard rows[i].kind == .deleted else {
                result.append(rows[i]); i += 1; continue
            }

            var d = i
            while d < rows.count && rows[d].kind == .deleted { d += 1 }
            var s = d
            while s < rows.count && rows[s].kind == .inserted { s += 1 }

            let deleted = rows[i..<d], inserted = rows[d..<s]
            guard deleted.count == inserted.count, !deleted.isEmpty else {
                result.append(contentsOf: rows[i..<s]); i = s; continue
            }

            for (dRow, iRow) in zip(deleted, inserted) {
                let a = dRow.leftSpans.map(\.text).joined()
                let b = iRow.rightSpans.map(\.text).joined()
                let (ls, rs) = inlineSpans(a, b)
                result.append(DiffRow(left: dRow.left, right: iRow.right, kind: .changed,
                                      leftSpans: ls, rightSpans: rs))
            }
            i = s
        }
        return result
    }
}
```

- [ ] **Step 4: `compare`'i `pairChanges` kullanacak şekilde bağla**

`compare` içindeki son satırı değiştir. Şu satırı bul:

```swift
        return DiffResult(rows: rows, hunks: [], truncated: truncated)
```

Şununla değiştir:

```swift
        // Kaba geri dususte satirlari eslestirmek yaniltici olur; atla.
        let paired = truncated ? rows : pairChanges(rows)
        return DiffResult(rows: paired, hunks: [], truncated: truncated)
```

- [ ] **Step 5: Testlerin geçtiğini doğrula**

Beklenen: `** TEST SUCCEEDED **`, 27 test geçti.

- [ ] **Step 6: Commit**

```bash
git add Sources/Shared/TextDiff.swift Tests/MarkPadTests/TextDiffTests.swift
git commit -m "TextDiff: satir ici kelime farki ve satir eslestirme"
```

---

### Task 6: Hunk gruplama

Bitişik farkları aktarılabilir bloklara toplar. Aktarma düğmelerinin dayandığı yapı.

**Files:**
- Modify: `Sources/Shared/TextDiff.swift`
- Modify: `Tests/MarkPadTests/TextDiffTests.swift`

**Interfaces:**
- Consumes: `DiffRow`, `DiffHunk` (Task 4)
- Produces:
  - `static func TextDiff.groupHunks(_ rows: [DiffRow], context: Int = 3) -> [DiffHunk]`
  - `compare` artık dolu `hunks` döner.

- [ ] **Step 1: Başarısız olacak testleri yaz**

`TextDiffTests.swift` sonuna ekle:

```swift
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
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Beklenen: `testTekHunk` dahil hunk testleri FAIL — `hunks` hâlâ boş.

- [ ] **Step 3: `groupHunks`'ı yaz**

`Sources/Shared/TextDiff.swift` sonuna ekle:

```swift
// MARK: - Hunk gruplama

extension TextDiff {

    /// Bitisik farkli satirlari blok haline getirir.
    /// Aralarinda `context` satirdan az esit satir kalan iki blok birlesir.
    static func groupHunks(_ rows: [DiffRow], context: Int = 3) -> [DiffHunk] {
        // Once farkli satirlarin kosularini bul.
        var runs: [Range<Int>] = []
        var i = 0
        while i < rows.count {
            guard rows[i].kind != .equal else { i += 1; continue }
            var j = i
            while j < rows.count && rows[j].kind != .equal { j += 1 }
            runs.append(i..<j)
            i = j
        }

        // Yakin kosulari birlestir.
        var merged: [Range<Int>] = []
        for run in runs {
            if let last = merged.last, run.lowerBound - last.upperBound < context {
                merged[merged.count - 1] = last.lowerBound..<run.upperBound
            } else {
                merged.append(run)
            }
        }

        return merged.enumerated().map { index, range in
            DiffHunk(id: index,
                     rows: range,
                     leftLines: sourceRange(rows, range, side: .left),
                     rightLines: sourceRange(rows, range, side: .right))
        }
    }

    /// Bir hunk'in bir taraftaki kaynak satir araligini bulur.
    /// O tarafta hic satir yoksa (saf ekleme/silme) ekleme noktasinda
    /// bos bir aralik doner — `apply` bu noktaya yerlestirir.
    private static func sourceRange(_ rows: [DiffRow], _ range: Range<Int>, side: Side) -> Range<Int> {
        let indexOf: (DiffRow) -> Int? = { side == .left ? $0.left : $0.right }
        let inside = rows[range].compactMap(indexOf)

        if let low = inside.min(), let high = inside.max() {
            return low..<(high + 1)
        }
        // Hunk'tan onceki son satir indeksi + 1 = ekleme noktasi.
        let anchor = (rows[0..<range.lowerBound].compactMap(indexOf).max()).map { $0 + 1 } ?? 0
        return anchor..<anchor
    }
}

/// Karsilastirmanin iki tarafi.
enum Side {
    case left, right
}
```

- [ ] **Step 4: `compare`'i `groupHunks` kullanacak şekilde bağla**

`compare` içinde Task 5'te yazdığın son bloğu bul:

```swift
        let paired = truncated ? rows : pairChanges(rows)
        return DiffResult(rows: paired, hunks: [], truncated: truncated)
```

Şununla değiştir:

```swift
        let paired = truncated ? rows : pairChanges(rows)
        return DiffResult(rows: paired, hunks: groupHunks(paired), truncated: truncated)
```

- [ ] **Step 5: Testlerin geçtiğini doğrula**

Beklenen: `** TEST SUCCEEDED **`, 35 test geçti.

- [ ] **Step 6: Commit**

```bash
git add Sources/Shared/TextDiff.swift Tests/MarkPadTests/TextDiffTests.swift
git commit -m "TextDiff: hunk gruplama"
```

---

### Task 7: Hunk uygulama (`apply`)

Çift yönlü aktarmanın motoru. Saf fonksiyon: iki metin girer, iki metin çıkar.

**Files:**
- Modify: `Sources/Shared/TextDiff.swift`
- Modify: `Tests/MarkPadTests/TextDiffTests.swift`

**Interfaces:**
- Consumes: `TextDiff.split`, `TextDiff.join`, `DiffHunk`, `Side` (Task 2, 4, 6)
- Produces: `static func TextDiff.apply(hunk: DiffHunk, source: Side, left: String, right: String) -> (left: String, right: String)`
  - `source: .right` → sağdaki içerik sola yazılır (arayüzdeki **`←`** düğmesi)
  - `source: .left` → soldaki içerik sağa yazılır (arayüzdeki **`→`** düğmesi)

- [ ] **Step 1: Başarısız olacak testleri yaz**

`TextDiffTests.swift` sonuna ekle:

```swift
    // MARK: - apply

    func testApplySagdanSolaDegisenSatir() {
        let sol = "a\nX\nc\n", sag = "a\nY\nc\n"
        let h = TextDiff.compare(left: sol, right: sag).hunks[0]
        let (yeniSol, yeniSag) = TextDiff.apply(hunk: h, source: .right, left: sol, right: sag)
        XCTAssertEqual(yeniSol, "a\nY\nc\n")
        XCTAssertEqual(yeniSag, sag, "kaynak taraf degismemeli")
    }

    func testApplySoldanSagaDegisenSatir() {
        let sol = "a\nX\nc\n", sag = "a\nY\nc\n"
        let h = TextDiff.compare(left: sol, right: sag).hunks[0]
        let (yeniSol, yeniSag) = TextDiff.apply(hunk: h, source: .left, left: sol, right: sag)
        XCTAssertEqual(yeniSag, "a\nX\nc\n")
        XCTAssertEqual(yeniSol, sol, "kaynak taraf degismemeli")
    }

    func testApplySafEklemeyiAlir() {
        let sol = "a\nc\n", sag = "a\nb\nc\n"
        let h = TextDiff.compare(left: sol, right: sag).hunks[0]
        let (yeniSol, _) = TextDiff.apply(hunk: h, source: .right, left: sol, right: sag)
        XCTAssertEqual(yeniSol, "a\nb\nc\n")
    }

    func testApplySafSilmeyiAlir() {
        let sol = "a\nb\nc\n", sag = "a\nc\n"
        let h = TextDiff.compare(left: sol, right: sag).hunks[0]
        let (yeniSol, _) = TextDiff.apply(hunk: h, source: .right, left: sol, right: sag)
        XCTAssertEqual(yeniSol, "a\nc\n")
    }

    /// Ana degismez: uygulanan hunk bir sonraki hesapta artik yoktur.
    func testApplySonrasiHunkKaybolur() {
        let sol = "a\nX\nc\nd\ne\nf\ng\nY\ni\n"
        let sag = "a\n1\nc\nd\ne\nf\ng\n2\ni\n"
        let once = TextDiff.compare(left: sol, right: sag)
        XCTAssertEqual(once.hunks.count, 2)

        let (yeniSol, yeniSag) = TextDiff.apply(hunk: once.hunks[0], source: .right,
                                                left: sol, right: sag)
        XCTAssertEqual(TextDiff.compare(left: yeniSol, right: yeniSag).hunks.count, 1)
    }

    /// Tum hunk'lar sagdan alininca sol metin sag metne esitlenmeli.
    func testTumHunklarSagdanAlinincaEsitlenir() {
        var sol = "bas\nA\nB\nortak\nC\nson\n"
        let sag = "bas\nX\nortak\nY\nZ\nson\n"
        var guvenlik = 0
        while true {
            let r = TextDiff.compare(left: sol, right: sag)
            guard let h = r.hunks.first else { break }
            sol = TextDiff.apply(hunk: h, source: .right, left: sol, right: sag).left
            guvenlik += 1
            XCTAssertLessThan(guvenlik, 20, "yakinsamadi")
        }
        XCTAssertEqual(sol, sag)
    }

    /// Ayni sey ters yonde: sag metin sol metne esitlenmeli.
    func testTumHunklarSoldanVerilinceEsitlenir() {
        let sol = "bas\nA\nB\nortak\nC\nson\n"
        var sag = "bas\nX\nortak\nY\nZ\nson\n"
        var guvenlik = 0
        while true {
            let r = TextDiff.compare(left: sol, right: sag)
            guard let h = r.hunks.first else { break }
            sag = TextDiff.apply(hunk: h, source: .left, left: sol, right: sag).right
            guvenlik += 1
            XCTAssertLessThan(guvenlik, 20, "yakinsamadi")
        }
        XCTAssertEqual(sag, sol)
    }

    /// Hedef taraf CRLF ise, LF kaynaktan alinan satirlar da CRLF olmali.
    func testApplyHedefinSatirSonunuKorur() {
        let sol = "a\r\nX\r\nc\r\n"      // CRLF
        let sag = "a\nY\nc\n"            // LF
        let h = TextDiff.compare(left: sol, right: sag).hunks[0]
        let (yeniSol, _) = TextDiff.apply(hunk: h, source: .right, left: sol, right: sag)
        XCTAssertEqual(yeniSol, "a\r\nY\r\nc\r\n")
    }

    func testApplySondakiYeniSatiriKorur() {
        let sol = "a\nX"                 // sonda yeni satir YOK
        let sag = "a\nY\n"               // sonda yeni satir VAR
        let h = TextDiff.compare(left: sol, right: sag).hunks[0]
        let (yeniSol, _) = TextDiff.apply(hunk: h, source: .right, left: sol, right: sag)
        XCTAssertEqual(yeniSol, "a\nY")
    }
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Beklenen: derleme hatası, `type 'TextDiff' has no member 'apply'`.

- [ ] **Step 3: `apply`'ı yaz**

`Sources/Shared/TextDiff.swift` sonuna ekle:

```swift
// MARK: - Hunk uygulama

extension TextDiff {

    /// Bir hunk'i `source` tarafindan karsi tarafa aktarir.
    ///
    /// Saf fonksiyon: diski bilmez, iki yeni metin dondurur.
    /// Kaynak taraf hicbir zaman degismez. Hedef tarafin satir sonu bicimi
    /// ve sondaki yeni satiri korunur.
    static func apply(hunk: DiffHunk, source: Side,
                      left: String, right: String) -> (left: String, right: String) {
        let l = split(left)
        let r = split(right)

        switch source {
        case .right:
            let yeni = replacing(l.lines, hunk.leftLines, with: Array(r.lines[hunk.rightLines]))
            return (join(yeni, like: l), right)
        case .left:
            let yeni = replacing(r.lines, hunk.rightLines, with: Array(l.lines[hunk.leftLines]))
            return (left, join(yeni, like: r))
        }
    }

    private static func replacing(_ lines: [String], _ range: Range<Int>,
                                  with yeni: [String]) -> [String] {
        var result = Array(lines[0..<range.lowerBound])
        result.append(contentsOf: yeni)
        result.append(contentsOf: lines[range.upperBound...])
        return result
    }
}
```

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Beklenen: `** TEST SUCCEEDED **`, 44 test geçti.

`testApplySondakiYeniSatiriKorur` başarısız olursa `join`'un `hasTrailingNewline`'ı hedef taraftan (`l`) aldığını doğrula — kaynaktan almamalı.

- [ ] **Step 5: Commit**

```bash
git add Sources/Shared/TextDiff.swift Tests/MarkPadTests/TextDiffTests.swift
git commit -m "TextDiff: cift yonlu hunk uygulama"
```

---

### Task 8: `CompareController` — dosya erişimi ve durum

Diski, paneli ve durumu yöneten katman. Motor saf kalır; yan etkiler burada.

**Files:**
- Create: `Sources/App/CompareController.swift`
- Create: `Tests/MarkPadTests/CompareControllerTests.swift`

**Interfaces:**
- Consumes: `TextDiff.compare`, `TextDiff.apply`, `DiffResult`, `DiffHunk`, `Side` (Task 4–7)
- Produces:
  - `@MainActor final class CompareController: ObservableObject`
  - `@Published private(set) var otherURL: URL?`
  - `@Published var otherText: String`
  - `@Published private(set) var result: DiffResult`
  - `@Published private(set) var otherIsDirty: Bool`
  - `@Published var alertMessage: String?`
  - `var canUndo: Bool`
  - `func chooseFile()`, `func load(url: URL) throws`, `func recompute(against documentText: String)`
  - `func apply(hunk: DiffHunk, source: Side, documentText: String) -> String` — yeni belge metnini döndürür
  - `func undoLastPush()`, `func saveOther()`, `func restoreBookmark()`
  - `static func readText(at url: URL) throws -> String`

- [ ] **Step 1: Başarısız olacak testleri yaz**

`Tests/MarkPadTests/CompareControllerTests.swift`:

```swift
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
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Beklenen: derleme hatası, `cannot find 'CompareController' in scope`.

- [ ] **Step 3: `CompareController`'ı yaz**

`Sources/App/CompareController.swift`:

```swift
import AppKit
import Combine
import UniformTypeIdentifiers

/// Karsilastirma modunun durumu: karsi dosyanin secimi, okunmasi,
/// diff hesabi, hunk aktarma ve diske yazma.
///
/// Diff motoru (`TextDiff`) saf kalir; tum yan etkiler burada toplanir.
@MainActor
final class CompareController: ObservableObject {

    @Published private(set) var otherURL: URL?
    @Published var otherText: String = ""
    @Published private(set) var result: DiffResult = .empty
    @Published private(set) var otherIsDirty = false
    @Published var alertMessage: String?

    /// Karsi dosyaya yapilan aktarmalarin geri alma yigini.
    /// Acik belgenin ⌘Z yigini ayridir; ikisi karistirilmaz.
    private var pushUndoStack: [String] = []

    /// Dosyanin acildigi/kaydedildigi andaki degisiklik tarihi.
    /// Diske yazmadan once disaridan degisip degismedigini anlamak icin.
    private var lastKnownModification: Date?

    private var recomputeTask: Task<Void, Never>?

    private static let bookmarkKey = "compareBookmark"
    /// 10 MB ustu dosyalarda kullaniciya onay sorulur.
    private static let largeFileBytes = 10 * 1024 * 1024

    var canUndo: Bool { !pushUndoStack.isEmpty }

    var otherName: String { otherURL?.lastPathComponent ?? "" }

    deinit {
        // `deinit` ana aktorde degil; URL'yi yerelde yakalayip birak.
        if let url = otherURLForCleanup { url.stopAccessingSecurityScopedResource() }
    }

    private nonisolated(unsafe) var otherURLForCleanup: URL?

    // MARK: - Dosya secme ve okuma

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.markdown, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Karşılaştırılacak dosyayı seç"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try load(url: url)
            storeBookmark(url)
        } catch {
            alertMessage = "Dosya açılamadı: \(error.localizedDescription)"
        }
    }

    func load(url: URL) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attrs[.size] as? Int, size > Self.largeFileBytes {
            let a = NSAlert()
            a.messageText = "Büyük dosya"
            a.informativeText = "Bu dosya \(size / 1024 / 1024) MB. Karşılaştırma yavaş olabilir. Devam edilsin mi?"
            a.addButton(withTitle: "Devam")
            a.addButton(withTitle: "Vazgeç")
            guard a.runModal() == .alertFirstButtonReturn else { return }
        }

        releaseCurrentAccess()
        _ = url.startAccessingSecurityScopedResource()

        otherText = try Self.readText(at: url)
        otherURL = url
        otherURLForCleanup = url
        lastKnownModification = attrs[.modificationDate] as? Date
        otherIsDirty = false
        pushUndoStack.removeAll()
    }

    /// `MarkdownDocument` ile ayni kodlama geri dususu.
    static func readText(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    private func releaseCurrentAccess() {
        otherURL?.stopAccessingSecurityScopedResource()
        otherURLForCleanup = nil
    }

    // MARK: - Diff hesabi

    /// Diff'i 180 ms geciktirip arka planda hesaplar.
    /// `ContentView.render()` ile ayni desen.
    func recompute(against documentText: String, immediately: Bool = true) {
        recomputeTask?.cancel()
        guard otherURL != nil else { result = .empty; return }
        let sag = otherText

        if immediately {
            result = TextDiff.compare(left: documentText, right: sag)
            return
        }

        recomputeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            if Task.isCancelled { return }
            let hesap = await Task.detached(priority: .userInitiated) {
                TextDiff.compare(left: documentText, right: sag)
            }.value
            if Task.isCancelled { return }
            self.result = hesap
        }
    }

    // MARK: - Aktarma

    /// Bir hunk'i aktarir ve **yeni belge metnini** dondurur.
    ///
    /// `source == .right` (arayuzde `←`): belge metni degisir, karsi dosya
    /// dokunulmaz. `source == .left` (`→`): karsi dosya bellekte degisir,
    /// belge metni oldugu gibi doner. Diske yazma yalnizca `saveOther()` ile.
    func apply(hunk: DiffHunk, source: Side, documentText: String) -> String {
        let (sol, sag) = TextDiff.apply(hunk: hunk, source: source,
                                        left: documentText, right: otherText)
        if source == .left {
            pushUndoStack.append(otherText)
            otherText = sag
            otherIsDirty = true
        }
        recompute(against: sol)
        return sol
    }

    func undoLastPush() {
        guard let onceki = pushUndoStack.popLast() else { return }
        otherText = onceki
        otherIsDirty = !pushUndoStack.isEmpty || otherChangedFromDisk()
    }

    private func otherChangedFromDisk() -> Bool {
        guard let url = otherURL, let disk = try? Self.readText(at: url) else { return false }
        return disk != otherText
    }

    // MARK: - Kaydetme

    /// Dosya MarkPad disinda degistiyse true.
    func otherChangedOnDisk() -> Bool {
        guard let url = otherURL, let bilinen = lastKnownModification,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let simdiki = attrs[.modificationDate] as? Date else { return false }
        return simdiki > bilinen
    }

    func saveOther() {
        guard let url = otherURL else { return }

        if otherChangedOnDisk() {
            let a = NSAlert()
            a.messageText = "Dosya MarkPad dışında değişti"
            a.informativeText = "\(url.lastPathComponent) başka bir yerde düzenlenmiş. Üzerine yazılsın mı?"
            a.addButton(withTitle: "Üzerine yaz")
            a.addButton(withTitle: "Vazgeç")
            guard a.runModal() == .alertFirstButtonReturn else { return }
        }

        do {
            try Data(otherText.utf8).write(to: url, options: [.atomic])
            lastKnownModification = (try? FileManager.default
                .attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
            otherIsDirty = false
            pushUndoStack.removeAll()
        } catch {
            // Rozet ve bellekteki metin korunur; kullanici tekrar deneyebilir.
            alertMessage = "Dosya kaydedilemedi: \(error.localizedDescription)"
        }
    }

    /// Testlerde kaydetme yolunu tetiklemek icin.
    func markDirtyForTesting() { otherIsDirty = true }

    // MARK: - Bookmark

    private func storeBookmark(_ url: URL) {
        let data = try? url.bookmarkData(options: .withSecurityScope,
                                         includingResourceValuesForKeys: nil,
                                         relativeTo: nil)
        AppSettings.shared.defaults.set(data, forKey: Self.bookmarkKey)
    }

    /// Son karsilastirilan dosyayi geri yukler. Cozulemezse sessizce
    /// bos duruma donulur — kullaniciya hata gosterilmez.
    func restoreBookmark() {
        guard let data = AppSettings.shared.defaults.data(forKey: Self.bookmarkKey) else { return }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                 relativeTo: nil, bookmarkDataIsStale: &stale),
              !stale else { return }
        try? load(url: url)
    }
}
```

- [ ] **Step 4: Testlerin geçtiğini doğrula**

```bash
xcodegen generate && xcodebuild -project MarkPad.xcodeproj -scheme MarkPad \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath .build \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" \
  -only-testing:MarkPadTests/CompareControllerTests test 2>&1 | tail -30
```

Beklenen: `** TEST SUCCEEDED **`, 8 test geçti.

`deinit` içindeki `nonisolated(unsafe)` Swift 5.9'da uyarı verirse `otherURLForCleanup` alanını kaldırıp `deinit`'i tamamen sil — sandbox erişimi süreç sonunda zaten bırakılır ve `releaseCurrentAccess()` dosya değişiminde çağrılıyor.

- [ ] **Step 5: Commit**

```bash
git add Sources/App/CompareController.swift Tests/MarkPadTests/CompareControllerTests.swift
git commit -m "CompareController: dosya erisimi, diff durumu ve aktarma"
```

---

### Task 9: `DiffPalette` ve `CompareView`

Görünüm katmanı. Tek kaydırma alanında satır tablosu; hizalama yapısal olarak garanti.

**Files:**
- Create: `Sources/Shared/DiffPalette.swift`
- Create: `Sources/App/CompareView.swift`

**Interfaces:**
- Consumes: `CompareController`, `DiffRow`, `DiffHunk`, `InlineSpan`, `Side`, `Theme`, `AppSettings`
- Produces:
  - `struct DiffPalette` + `static func forTheme(_ theme: Theme) -> DiffPalette`
  - `struct CompareView: View` — başlatıcı: `CompareView(documentText: Binding<String>, controller: CompareController, theme: Theme, settings: AppSettings)`

- [ ] **Step 1: `DiffPalette`'i yaz**

`Sources/Shared/DiffPalette.swift`:

```swift
import AppKit

/// Diff renkleri. Temanin 12 tanimina dokunmadan, yalnizca
/// acik/koyu ayrimina gore secilir.
///
/// Renk tek sinyal degildir: arayuz ayrica oluğa +, −, ~ isaretini
/// cizer. Renk korlugu icin bu gereklidir.
struct DiffPalette {
    let addBG: NSColor
    let addStrongBG: NSColor
    let deleteBG: NSColor
    let deleteStrongBG: NSColor
    let gutterFG: NSColor

    static func forTheme(_ theme: Theme) -> DiffPalette {
        theme.isDark ? dark : light
    }

    static let light = DiffPalette(
        addBG:          NSColor(srgbRed: 0.878, green: 0.961, blue: 0.890, alpha: 1),
        addStrongBG:    NSColor(srgbRed: 0.667, green: 0.898, blue: 0.706, alpha: 1),
        deleteBG:       NSColor(srgbRed: 1.000, green: 0.910, blue: 0.914, alpha: 1),
        deleteStrongBG: NSColor(srgbRed: 1.000, green: 0.741, blue: 0.753, alpha: 1),
        gutterFG:       NSColor(white: 0.42, alpha: 1))

    static let dark = DiffPalette(
        addBG:          NSColor(srgbRed: 0.050, green: 0.196, blue: 0.098, alpha: 1),
        addStrongBG:    NSColor(srgbRed: 0.102, green: 0.365, blue: 0.180, alpha: 1),
        deleteBG:       NSColor(srgbRed: 0.239, green: 0.075, blue: 0.086, alpha: 1),
        deleteStrongBG: NSColor(srgbRed: 0.451, green: 0.129, blue: 0.161, alpha: 1),
        gutterFG:       NSColor(white: 0.62, alpha: 1))
}
```

- [ ] **Step 2: `CompareView`'ı yaz**

`Sources/App/CompareView.swift`:

```swift
import SwiftUI
import AppKit

/// Karsilastirma gorunumu.
///
/// Iki ayri `ScrollView`'i senkronlamak yerine **tek kaydirma alaninda
/// satir tablosu** kurulur: her satir bir HStack'tir ve bir tarafta
/// karsiligi olmayan satir o tarafta bos dolgu olarak cizilir.
/// Boylece iki panel hicbir kosulda kayamaz.
struct CompareView: View {

    @Binding var documentText: String
    @ObservedObject var controller: CompareController
    let theme: Theme
    let settings: AppSettings

    /// Acilmis katlama seritlerinin kimlikleri.
    @State private var expandedFolds: Set<Int> = []

    private var palette: DiffPalette { DiffPalette.forTheme(theme) }
    private var font: Font { Font(settings.editorFont() as CTFont) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if controller.otherURL == nil {
                emptyState
            } else if controller.result.rows.isEmpty {
                message("İki dosya birebir aynı.")
            } else {
                if controller.result.truncated { truncationWarning }
                table
            }
        }
        .background(Color(nsColor: theme.nsBackground))
        .onAppear { controller.recompute(against: documentText) }
        .onChange(of: documentText) { yeni in
            controller.recompute(against: yeni, immediately: false)
        }
        .alert("MarkPad", isPresented: Binding(
            get: { controller.alertMessage != nil },
            set: { if !$0 { controller.alertMessage = nil } }
        )) {
            Button("Tamam", role: .cancel) { controller.alertMessage = nil }
        } message: {
            Text(controller.alertMessage ?? "")
        }
    }

    // MARK: - Baslik cubugu

    private var header: some View {
        HStack(spacing: 10) {
            Text("Bu belge").font(.system(size: 11, weight: .semibold))
            Spacer()

            if controller.otherURL != nil {
                if controller.canUndo {
                    Button("Geri al") { controller.undoLastPush() }
                        .help("Karşı dosyaya yapılan son aktarmayı geri alır (⌘Z bu belgeye aittir)")
                }
                if controller.otherIsDirty {
                    Text("●").foregroundStyle(.orange)
                        .help("Karşı dosyada kaydedilmemiş değişiklik var")
                    Button("Karşı dosyayı kaydet") { controller.saveOther() }
                        .keyboardShortcut("s", modifiers: [.command, .shift])
                }
                Text(controller.otherName).font(.system(size: 11, weight: .semibold))
                Button("Değiştir…") { chooseAndRecompute() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 34)).foregroundStyle(.secondary)
            Text("Bu belgeyi başka bir dosyayla karşılaştır.")
                .foregroundStyle(.secondary)
            Button("Karşılaştırılacak dosyayı seç…") { chooseAndRecompute() }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func message(_ s: String) -> some View {
        VStack { Spacer(); Text(s).foregroundStyle(.secondary); Spacer() }
            .frame(maxWidth: .infinity)
    }

    private var truncationWarning: some View {
        Text("Dosyalar çok farklı — kaba karşılaştırma gösteriliyor.")
            .font(.system(size: 11))
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.18))
    }

    private func chooseAndRecompute() {
        controller.chooseFile()
        controller.recompute(against: documentText)
    }

    // MARK: - Tablo

    private var table: some View {
        ScrollView([.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(displayItems) { item in
                    switch item {
                    case .row(let index, _):
                        rowView(controller.result.rows[index], rowIndex: index)
                    case .fold(let id, let range):
                        foldStrip(id: id, range: range)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func foldStrip(id: Int, range: Range<Int>) -> some View {
        Button {
            expandedFolds.insert(id)
        } label: {
            Text("⋯ \(range.count) satır aynı")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .background(Color(nsColor: theme.nsMuted).opacity(0.15))
    }

    private func rowView(_ row: DiffRow, rowIndex: Int) -> some View {
        HStack(spacing: 0) {
            cell(number: row.left, spans: row.leftSpans,
                 bg: background(row, side: .left),
                 strong: strongBackground(row, side: .left))
            gutter(rowIndex: rowIndex, row: row)
            cell(number: row.right, spans: row.rightSpans,
                 bg: background(row, side: .right),
                 strong: strongBackground(row, side: .right))
        }
    }

    private func cell(number: Int?, spans: [InlineSpan],
                      bg: Color, strong: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number.map { String($0 + 1) } ?? "")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(nsColor: palette.gutterFG))
                .frame(width: 38, alignment: .trailing)
            Text(attributed(spans, strong: strong))
                .font(font)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
        .frame(width: 460, alignment: .leading)
        .background(bg)
    }

    /// Degisen kelimeleri koyu arka plan ve yari kalin agirlikla isaretler.
    private func attributed(_ spans: [InlineSpan], strong: Color) -> AttributedString {
        var out = AttributedString("")
        for span in spans {
            var piece = AttributedString(span.text)
            piece.foregroundColor = Color(nsColor: theme.nsForeground)
            if span.changed {
                piece.backgroundColor = strong
                piece.inlinePresentationIntent = .stronglyEmphasized
            }
            out.append(piece)
        }
        if out.characters.isEmpty { out = AttributedString(" ") }
        return out
    }

    private func background(_ row: DiffRow, side: Side) -> Color {
        switch (row.kind, side) {
        case (.equal, _):                       return .clear
        case (.deleted, .left), (.changed, .left):  return Color(nsColor: palette.deleteBG)
        case (.inserted, .right), (.changed, .right): return Color(nsColor: palette.addBG)
        default:                                return .clear
        }
    }

    private func strongBackground(_ row: DiffRow, side: Side) -> Color {
        side == .left ? Color(nsColor: palette.deleteStrongBG)
                      : Color(nsColor: palette.addStrongBG)
    }

    // MARK: - Oluk

    private func gutter(rowIndex: Int, row: DiffRow) -> some View {
        let hunk = controller.result.hunks.first { $0.rows.contains(rowIndex) }
        let isFirstRow = hunk?.rows.lowerBound == rowIndex

        return HStack(spacing: 2) {
            Text(symbol(row.kind))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(nsColor: palette.gutterFG))
                .frame(width: 12)

            if let hunk, isFirstRow {
                Button { documentText = controller.apply(hunk: hunk, source: .right,
                                                         documentText: documentText) }
                    label: { Image(systemName: "arrow.left") }
                    .buttonStyle(.borderless)
                    .help("Bu bölümü karşıdan bu belgeye al")

                Button { _ = controller.apply(hunk: hunk, source: .left,
                                              documentText: documentText) }
                    label: { Image(systemName: "arrow.right") }
                    .buttonStyle(.borderless)
                    .help("Bu bölümü karşı dosyaya yaz (kaydetmek ayrı adım)")
            } else {
                Spacer().frame(width: 40)
            }
        }
        .frame(width: 62)
    }

    /// Renk tek sinyal olmasin diye her satirin isareti.
    private func symbol(_ kind: DiffLineKind) -> String {
        switch kind {
        case .equal:    return " "
        case .inserted: return "+"
        case .deleted:  return "−"
        case .changed:  return "~"
        }
    }

    // MARK: - Katlama

    private enum DisplayItem: Identifiable {
        case row(index: Int, id: Int)
        case fold(id: Int, range: Range<Int>)

        var id: Int {
            switch self {
            case .row(_, let id): return id
            case .fold(let id, _): return -(id + 1)
            }
        }
    }

    /// Hunk'lardan 3 satirdan uzaktaki esit satirlari katlar.
    private var displayItems: [DisplayItem] {
        let rows = controller.result.rows
        let context = 3
        var gorunur = Set<Int>()
        for hunk in controller.result.hunks {
            let alt = max(0, hunk.rows.lowerBound - context)
            let ust = min(rows.count, hunk.rows.upperBound + context)
            gorunur.formUnion(alt..<ust)
        }
        // Hic hunk yoksa katlanacak bir sey de yok.
        if controller.result.hunks.isEmpty { gorunur = Set(0..<rows.count) }

        var items: [DisplayItem] = []
        var i = 0
        var foldID = 0
        while i < rows.count {
            if gorunur.contains(i) {
                items.append(.row(index: i, id: i))
                i += 1
                continue
            }
            var j = i
            while j < rows.count && !gorunur.contains(j) { j += 1 }
            let id = foldID
            foldID += 1
            // Kisa bosluklari katlamak fayda saglamaz.
            if j - i <= 2 || expandedFolds.contains(id) {
                for k in i..<j { items.append(.row(index: k, id: k)) }
            } else {
                items.append(.fold(id: id, range: i..<j))
            }
            i = j
        }
        return items
    }
}
```

- [ ] **Step 3: Derlenmesini doğrula**

Derleme + test komutunu çalıştır. Beklenen: `** TEST SUCCEEDED **` (yeni test yok, mevcut 52 test geçer, yeni dosyalar derlenir).

`Theme`'in doğrulanmış NSColor üyeleri (`Sources/Shared/Theme.swift:267-272`): `nsBackground`, `nsForeground`, `nsMuted`, `nsAccent`, `nsCodeBG`, `nsSelection`. **`nsBorder` yoktur** — kenarlık rengi gerekirse `nsMuted` düşük opaklıkla kullanılır, `Theme`'e yeni üye eklenmez.

- [ ] **Step 4: Commit**

```bash
git add Sources/Shared/DiffPalette.swift Sources/App/CompareView.swift
git commit -m "CompareView: hizali diff tablosu ve aktarma olugu"
```

---

### Task 10: Uygulamaya bağlama

Karşılaştırmayı 4. görünüm modu olarak belge penceresine, menüye ve araç çubuğuna bağlar.

**Files:**
- Modify: `Sources/App/FormatCommand.swift:11-28` (`ViewMode`)
- Modify: `Sources/App/ContentView.swift` (`content`, `@StateObject`, araç çubuğu)
- Modify: `Sources/App/MarkPadApp.swift` (menü)

**Interfaces:**
- Consumes: `CompareView`, `CompareController` (Task 8, 9)
- Produces: `ViewMode.compare`; ⌘4 kısayolu; "Dosya ile Karşılaştır…" menü öğesi.

- [ ] **Step 1: `ViewMode`'a `compare` ekle**

`Sources/App/FormatCommand.swift` içinde `enum ViewMode`'u şununla değiştir:

```swift
enum ViewMode: String, CaseIterable, Identifiable {
    case editor, split, preview, compare
    var id: String { rawValue }
    var label: String {
        switch self {
        case .editor: return "Düzenleyici"
        case .split: return "Bölünmüş"
        case .preview: return "Önizleme"
        case .compare: return "Karşılaştır"
        }
    }
    var symbol: String {
        switch self {
        case .editor: return "pencil"
        case .split: return "rectangle.split.2x1"
        case .preview: return "doc.richtext"
        case .compare: return "arrow.left.arrow.right"
        }
    }
```

(Dosyanın geri kalanı — kapanış parantezi ve varsa diğer üyeler — olduğu gibi kalır.)

- [ ] **Step 2: `ContentView`'a denetleyiciyi ve modu ekle**

`Sources/App/ContentView.swift` içinde, `@StateObject private var controller = EditorController()` satırının **hemen altına** ekle:

```swift
    @StateObject private var compare = CompareController()
```

Ardından `content` özelliğindeki `switch mode` bloğuna `.compare` dalını ekle — `case .split:` bloğundan sonra, `}` kapanışından önce:

```swift
        case .compare:
            CompareView(documentText: $text, controller: compare,
                        theme: theme, settings: settings)
```

- [ ] **Step 3: Durum çubuğunu karşılaştırma modunda uyarla**

`statusBar` özelliğinin gövdesindeki `HStack(spacing: 14) {` satırından hemen sonraki içeriği koşullu yap. `statusBar`'ı şununla değiştir:

```swift
    private var statusBar: some View {
        HStack(spacing: 14) {
            if mode == .compare {
                Text("\(compare.result.hunks.count) fark bloğu")
                if compare.otherIsDirty { Text("karşı dosya kaydedilmedi").foregroundStyle(.orange) }
            } else {
                Text("\(wordCount) kelime")
                Text("\(text.count) karakter")
                Text("\(text.components(separatedBy: .newlines).count) satır")
            }
            Spacer()
            Text("~\(max(1, wordCount / 200)) dk okuma")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }
```

- [ ] **Step 4: Menü öğelerini ekle**

`Sources/App/MarkPadApp.swift` içinde `CommandGroup(after: .toolbar)` bloğunun içine, "Yalnızca Önizleme" düğmesinden **sonra** ekle:

```swift
            Button("Karşılaştır") { post(.setMode, mode: .compare) }
                .keyboardShortcut("4", modifiers: [.command])
```

Ayrıca aynı `body` içine, `CommandGroup(after: .toolbar)` bloğundan **sonra** yeni bir grup ekle:

```swift
        CommandGroup(after: .newItem) {
            Button("Dosya ile Karşılaştır…") {
                NotificationCenter.default.post(name: .setMode, object: ViewMode.compare)
                NotificationCenter.default.post(name: .markPadChooseCompareFile, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
```

Dosyanın sonundaki `extension Notification.Name` bloğuna ekle:

```swift
    static let markPadChooseCompareFile = Notification.Name("markPadChooseCompareFile")
```

- [ ] **Step 5: `ContentView`'da bildirimi dinle**

`ContentView.body` içindeki `.onReceive(NotificationCenter.default.publisher(for: .setMode))` bloğunun **hemen altına** ekle:

```swift
        .onReceive(NotificationCenter.default.publisher(for: .markPadChooseCompareFile)) { _ in
            guard NSApp.keyWindow?.isKeyWindow == true else { return }
            compare.chooseFile()
            compare.recompute(against: text)
        }
```

- [ ] **Step 6: Derleme ve testleri doğrula**

Derleme + test komutunu çalıştır.
Beklenen: `** TEST SUCCEEDED **`, 52 test geçti, uyarı yok.

- [ ] **Step 7: Commit**

```bash
git add Sources/App/FormatCommand.swift Sources/App/ContentView.swift Sources/App/MarkPadApp.swift
git commit -m "Karsilastirma modunu arayuze bagla: 4. gorunum, menu ve kisayollar"
```

---

### Task 11: Elle doğrulama

Birim testler motoru kanıtlar; bu görev arayüzün gerçekten çalıştığını kanıtlar.

**Files:** yok (yalnız doğrulama; bulunan hatalar için ilgili dosya düzeltilir)

**Interfaces:**
- Consumes: tamamlanmış özellik (Task 1–10)
- Produces: doğrulanmış çalışan uygulama

- [ ] **Step 1: İki test dosyası hazırla**

```bash
mkdir -p /tmp/markpad-diff && cd /tmp/markpad-diff
printf '# Rapor\n\nGiris paragrafi burada.\n\n## Bulgular\n\n- Birinci madde\n- Ikinci madde\n\nSonuc cumlesi.\n' > sol.md
printf '# Rapor\n\nGiris paragrafi burada.\n\n## Bulgular\n\n- Birinci madde\n- Degistirilmis ikinci madde\n- Ucuncu madde\n\nSonuc cumlesi.\n' > sag.md
```

- [ ] **Step 2: Uygulamayı çalıştır ve `sol.md`'yi aç**

```bash
open .build/Build/Products/Debug/MarkPad.app --args /tmp/markpad-diff/sol.md
```

Açılmazsa uygulamayı başlat ve ⌘O ile `/tmp/markpad-diff/sol.md`'yi aç.

- [ ] **Step 3: Kontrol listesini yürüt**

Her maddeyi gözle doğrula. Başarısız olan varsa düzelt, testleri yeniden çalıştır, tekrar dene.

- [ ] ⌘4 karşılaştırma moduna geçiyor; boş durum ekranı görünüyor.
- [ ] "Karşılaştırılacak dosyayı seç…" `sag.md`'yi açıyor.
- [ ] Satırlar hizalı; sol ve sağ panel kaydırırken birbirinden kaymıyor.
- [ ] "Ikinci madde" satırı `~` işaretli ve **yalnız değişen kelimeler** koyu vurgulu.
- [ ] "Ucuncu madde" satırı sağda `+` işaretli, solda boş dolgu.
- [ ] Değişmeyen uzun bölüm "⋯ N satır aynı" şeridine katlanmış; şeride tıklayınca açılıyor.
- [ ] Bir hunk'ta `←` düğmesi: belgedeki metin değişiyor, o hunk listeden kayboluyor.
- [ ] ⌘Z bu değişikliği geri alıyor (belgenin kendi undo'su).
- [ ] Bir hunk'ta `→` düğmesi: başlıkta turuncu `●` ve "Karşı dosyayı kaydet" beliriyor; `sag.md` **henüz diskte değişmemiş** (`cat /tmp/markpad-diff/sag.md` ile doğrula).
- [ ] "Geri al" düğmesi `→` işlemini geri alıyor, `●` kayboluyor.
- [ ] "Karşı dosyayı kaydet" `sag.md`'yi diske yazıyor (`cat` ile doğrula).
- [ ] Karşılaştırma modundayken tema değiştirince renkler koyu/açık paletine geçiyor.
- [ ] ⌘1 / ⌘2 / ⌘3 eski modlara sorunsuz dönüyor; önizleme hâlâ çalışıyor.
- [ ] Uygulamayı kapatıp açınca son karşılaştırılan dosya hatırlanıyor.

- [ ] **Step 4: Dış değişiklik korumasını doğrula**

Karşılaştırma açıkken başka bir terminalden:

```bash
printf 'baskasi yazdi\n' >> /tmp/markpad-diff/sag.md
```

Sonra bir `→` yapıp "Karşı dosyayı kaydet"e bas. "Dosya MarkPad dışında değişti" onayı çıkmalı; "Vazgeç" dosyayı korumalı.

- [ ] **Step 5: Temizlik ve commit**

Düzeltme yaptıysan commit et. Yapmadıysan bu adım atlanır.

```bash
rm -rf /tmp/markpad-diff
git status --short
```

---

## Uygulama sonrası

Tüm görevler bittiğinde:

```bash
xcodegen generate && xcodebuild -project MarkPad.xcodeproj -scheme MarkPad \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath .build \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" test 2>&1 | tail -30
python3 Tools/fix_contrast.py --check
```

İkisi de yeşilse CI de yeşil olur. `README.md`'ye karşılaştırma özelliğini ve ⌘4 / ⇧⌘D kısayollarını eklemeyi unutma.
