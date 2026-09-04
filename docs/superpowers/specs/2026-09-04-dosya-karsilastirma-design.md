# Dosya Karşılaştırma (Diff) ve Çift Yönlü Aktarma — Tasarım

Tarih: 2026-09-04
Durum: Onaylandı, uygulanmayı bekliyor

## 1. Amaç

MarkPad'de açık olan belgeyi diskteki başka bir Markdown dosyasıyla
karşılaştırmak ve farklı bölümleri iki yönde de aktarabilmek.

Başarı ölçütleri:

- Kullanıcı açık belgeyi seçtiği ikinci dosyayla yan yana, hizalı olarak görür.
- Farklar satır düzeyinde renklenir; değişen satırların içinde değişen
  kelimeler ayrıca vurgulanır.
- Her fark bloğu (hunk) tek tıkla karşı tarafa aktarılabilir; aktarma iki
  yönde de çalışır.
- Açık belgeye yapılan aktarma mevcut belge kaydetme akışına (⌘S, undo,
  değiştirildi rozeti) katılır.
- Karşı dosyaya yazma yalnızca kullanıcının açık isteğiyle olur.

## 2. Kapsam dışı

- Üç yollu birleştirme (three-way merge), git entegrasyonu, çakışma çözümü.
- İkiden fazla dosyanın karşılaştırılması.
- Karşılaştırma sonucunun dışa aktarılması (HTML/PDF diff çıktısı).
- Markdown AST (blok) düzeyinde anlamsal karşılaştırma. Satır + kelime
  düzeyi yeterli bulundu; AST eşleştirmesi karmaşık ve öngörülemez.
- Karşı dosya için sözdizimi renklendirmesi (yalnız diff renkleri).

## 3. Mimari

Yeni dosyalar:

| Dosya | Sorumluluk | Bağımlılık |
|---|---|---|
| `Sources/Shared/TextDiff.swift` | Saf algoritma: Myers satır diff'i, kelime bazlı satır içi diff, hunk gruplama, `apply`. | Foundation |
| `Sources/Shared/DiffPalette.swift` | Ekleme/silme renkleri (açık ve koyu varyant). | AppKit |
| `Sources/App/CompareController.swift` | Durum: karşı dosyayı açma, bookmark, diff hesabı, hunk uygulama, kaydetme. | AppKit, Combine, TextDiff |
| `Sources/App/CompareView.swift` | Görüntü: hizalı satır tablosu, hunk aktarma oluğu. | SwiftUI |
| `Tests/MarkPadTests/TextDiffTests.swift` | `TextDiff` birim testleri. | XCTest |

Değişen dosyalar:

| Dosya | Değişiklik |
|---|---|
| `Sources/App/FormatCommand.swift` | `ViewMode`'a `case compare`; `label` "Karşılaştır", `symbol` `arrow.left.arrow.right`. |
| `Sources/App/ContentView.swift` | `content` içinde `.compare` dalı; `CompareController` `@StateObject`; araç çubuğu seçicide 4. simge. |
| `Sources/App/MarkPadApp.swift` | Görünüm menüsüne ⌘4 "Karşılaştır"; Dosya menüsüne "Dosya ile Karşılaştır…". |
| `project.yml` | `MarkPadTests` hedefi ve şemaya test adımı. |

`TextDiff` ve `DiffPalette` `Sources/Shared/` altındadır; bu dizin hem
`MarkPad` hem `MarkPadQuickLook` hedeflerince derlenir. `TextDiff` saf
Swift'tir: dosya sistemi, panel ve tema bilmez. Girdisi `[String]`,
çıktısı `[DiffRow]` ve `[DiffHunk]`.

### Entitlement

Değişiklik gerekmez. `Sources/App/MarkPad.entitlements` zaten şunları içerir:

- `com.apple.security.files.user-selected.read-write` — panelden seçilen
  ikinci dosyayı okuma **ve** yazma hakkı.
- `com.apple.security.files.bookmarks.app-scope` — seçimi oturumlar arası
  saklamak için.

## 4. Veri modeli

```swift
enum DiffLineKind { case equal, inserted, deleted, changed }

/// Satır içinde değişen aralık. `text` her zaman kaynaktan alınmış
/// birebir metindir; parçaların birleşimi satırın tamamını verir.
struct InlineSpan: Equatable {
    let text: String
    let changed: Bool
}

/// Tabloda tek bir görsel satır. `left`/`right` ilgili taraftaki 0 tabanlı
/// satır indeksidir; o tarafta karşılığı yoksa nil (boş dolgu çizilir).
struct DiffRow: Equatable {
    let left: Int?
    let right: Int?
    let kind: DiffLineKind
    let leftSpans: [InlineSpan]
    let rightSpans: [InlineSpan]
}

/// Bitişik farklı satırların oluşturduğu blok.
/// `rows` satır tablosundaki aralık, `leftLines`/`rightLines` kaynak
/// metinlerdeki aralıklardır. Boş aralık (saf ekleme/silme) geçerlidir.
struct DiffHunk: Identifiable, Equatable {
    let id: Int              // tablodaki sırası; her hesapta yeniden atanır
    let rows: Range<Int>
    let leftLines: Range<Int>
    let rightLines: Range<Int>
}

struct DiffResult: Equatable {
    let rows: [DiffRow]
    let hunks: [DiffHunk]
    let truncated: Bool      // D-limiti aşıldı, kaba sonuç
}
```

### API

```swift
enum TextDiff {
    static func compare(left: String, right: String) -> DiffResult
    static func apply(hunk: DiffHunk, from: Side, left: String, right: String)
        -> (left: String, right: String)
}

enum Side { case left, right }
```

`apply` saf bir fonksiyondur: iki metni alır, hunk'ı belirtilen yönde
uygulanmış iki yeni metin döndürür. Diski bilmez.

## 5. Algoritma

### Satır bölme

Metin `\r\n`, `\n` ve `\r` ayraçlarında bölünür. Orijinal satır sonu
karakteri her taraf için ayrıca saklanır (`lineEnding: String`) ve
`apply` sırasında **hedef tarafın** ayracı kullanılır; böylece CRLF bir
dosya LF bir dosyadan hunk aldığında CRLF kalır.

Metnin sonundaki ayraç bilgisi (`hasTrailingNewline`) korunur ve
`apply` sonrası yeniden uygulanır.

### Myers O(ND)

Satır dizileri üzerinde Myers'ın greedy algoritması, her `d` adımının
`V` dizisi saklanarak (geriye izleme için) çalıştırılır. Maliyet fark
sayısı `D` ile orantılıdır; benzer dosyalarda `D` küçüktür.

Klasik LCS matrisi kullanılmaz: `O(n·m)` bellek, 5.000×5.000 satırda
~25M hücre demektir.

Ön işlem: ortak baş ve son satırlar kırpılır, Myers yalnızca ortadaki
farklı bölgede çalışır.

Güvenlik supabı: `D > 5000` olursa Myers durdurulur. Kırpılan ortak baş ve
son satırlar `.equal` olarak korunur; aradaki bölge tamamı silinmiş sol
satırlar + tamamı eklenmiş sağ satırlar olarak tek bir hunk'a konur ve
`truncated = true` işaretlenir. Arayüz bu durumda "Dosyalar çok farklı, kaba karşılaştırma
gösteriliyor" uyarısı çizer.

### Satır içi kelime diff'i

Bir hunk'ta silinen ve eklenen satır sayısı **eşitse** satırlar sırayla
1-1 eşlenir ve her çift `.changed` olarak işaretlenir; her çift için aynı
Myers, bu kez kelime token'ları üzerinde çalıştırılır.

Token'lama: metin, harf/rakam dizileri ile diğer her karakter (boşluk ve
noktalama dahil) ayrı token olacak şekilde bölünür. Boşluklar token
olarak korunur, böylece parçaların birleşimi satırın birebir aynısıdır.

Sayılar eşit değilse satırlar `.inserted` / `.deleted` kalır, satır içi
diff çalıştırılmaz.

### Hunk gruplama

Bitişik `equal` olmayan satırlar tek hunk'ta toplanır. Aralarında 3
satırdan az eşit satır kalan iki hunk birleştirilir (klasik bağlam
kuralı). 3 satır bağlamın dışındaki eşit satır dizileri arayüzde
katlanır.

## 6. Görüntü

Hizalama, iki `ScrollView`'ı senkronlamak yerine **tek kaydırma alanında
satır tablosu** ile çözülür. Her `DiffRow` bir `HStack`:

```
[ sol satır no | sol içerik ] [ oluk: işaret + ← → ] [ sağ satır no | sağ içerik ]
```

Bir tarafta karşılığı olmayan satır o tarafta boş dolgu olarak çizilir.
İki panel hiçbir koşulda kayamaz.

- `LazyVStack` — 10.000 satırlık dosyada yalnız görünen satırlar çizilir.
- Yazı tipi `settings.editorFont()`; editörle aynı monospace.
- Renkler `DiffPalette`'ten, `theme.isDark`'a göre. Renk **tek sinyal
  değildir**: satır numarası oluğunda `+` (eklendi), `−` (silindi),
  `~` (değişti) işareti de vardır. Erişilebilirlik için gereklidir.
- Değişen satırlarda kelime vurgusu `AttributedString` ile; değişen
  span'lar daha koyu arka plan ve `.semibold` ağırlık alır.
- 3 satır bağlam dışındaki eşit satır dizileri "⋯ N satır aynı" şeridine
  katlanır; şeride tıklanınca açılır.
- Üstte ince bir başlık çubuğu: solda belge adı, sağda karşı dosyanın adı
  ve değiştirildiyse `●` rozeti, "Karşı dosyayı kaydet" ve "Başka dosya
  seç…" düğmeleri.
- Karşı dosya seçilmemişken orta alanda boş durum: "Karşılaştırılacak
  dosyayı seç…" düğmesi.
- Hunk yoksa: "İki dosya birebir aynı." mesajı.

## 7. Çift yönlü aktarma ve kaydetme

Her hunk'ın oluğunda iki düğme:

- **`←`** — sağdaki bölümü açık belgeye al. `text` binding'i güncellenir,
  yani mevcut belge akışı (⌘S, undo, değiştirildi rozeti) bedava gelir.
- **`→`** — soldaki bölümü karşı dosyaya yaz. Yalnızca
  `controller.otherText` güncellenir; **disk yazımı olmaz**. Başlık
  çubuğunda `●` rozeti ve "Karşı dosyayı kaydet" düğmesi etkinleşir.

Karşı dosyaya sessizce yazılmamasının nedeni: ikinci dosyanın `DocumentGroup`
kaydetme akışı, otomatik kaydı ve undo yığını yoktur; sessiz yazma veri
kaybı riskidir.

- Karşı dosya için bellek içi geri alma yığını tutulur. Geri alma **⌘Z ile
  değil**, başlık çubuğundaki "Geri al" düğmesiyle yapılır: ⌘Z açık belgenin
  `NSTextView` undo yığınına aittir ve onu ele geçirmek `←` ile yapılan
  aktarmaların geri alınmasını bozar. İki yığın ayrı kalır — `←` belgenin
  kendi undo'suyla, `→` bu düğmeyle geri alınır.
- Her aktarmadan sonra diff **baştan hesaplanır**. Kısmi güncelleme yerine
  yeniden hesap; Myers ucuzdur ve durum tutarsızlığını tamamen kaldırır.
- Diske yazmadan önce dosyanın değişiklik tarihi, açılış anında kaydedilen
  değerle karşılaştırılır. Farklıysa "Dosya MarkPad dışında değişti.
  Üzerine yazılsın mı?" onayı sorulur.
- Yazma `Data.write(to:options:[.atomic])` ile yapılır; hata olursa uyarı
  gösterilir ve `●` rozeti kalır (bellekteki metin korunur).

### Diff'in yeniden hesaplanması

`text` veya `otherText` değiştiğinde diff 180 ms debounce ile arka planda
(`Task.detached`) hesaplanır ve sonuç ana aktöre yazılır. Bu, `ContentView`
içindeki mevcut `render()` deseninin birebir aynısıdır.

## 8. Dosya seçme ve erişim

- `NSOpenPanel`, izin verilen tipler: `.markdown`, `.plainText`.
- Seçim sonrası `url.startAccessingSecurityScopedResource()` çağrılır;
  `CompareController.deinit`'te ve yeni dosya seçildiğinde
  `stopAccessing...` ile bırakılır.
- Uygulama kapanıp açıldığında son karşılaştırılan dosyayı hatırlamak için
  app-scope bookmark `UserDefaults`'a yazılır. Bookmark çözülemezse sessizce
  boş duruma dönülür.
- Okuma `MarkdownDocument` ile aynı kodlama geri düşüşünü kullanır:
  önce UTF-8, olmazsa ISO Latin-1, o da olmazsa hata uyarısı.

## 9. Hata durumları

| Durum | Davranış |
|---|---|
| Dosya okunamıyor (izin/silinmiş) | Uyarı paneli, boş duruma dön. |
| Kodlama çözülemiyor | "Dosya metin olarak okunamadı" uyarısı. |
| Dosya çok büyük (> 10 MB) | Onay sor: "Büyük dosya, karşılaştırma yavaş olabilir." |
| `D > 5000` | Kaba karşılaştırma + arayüzde uyarı şeridi. |
| Karşı dosya dışarıdan değişmiş | Yazmadan önce üzerine yazma onayı. |
| Disk yazımı başarısız | Uyarı, `●` rozeti korunur, bellekteki metin kaybolmaz. |
| Bookmark çözülemiyor | Sessizce boş duruma dön, hata gösterme. |

## 10. Test

Projede şu an test hedefi yoktur. `project.yml`'ye `MarkPadTests`
(type: bundle.unit-test, platform: macOS) eklenir ve `MarkPad` şemasının
`test` adımına bağlanır. TDD uygulanır: önce test, sonra motor.

`TextDiffTests` kapsamı:

- Boş ↔ boş, boş ↔ dolu, dolu ↔ boş.
- Birebir aynı dosya → 0 hunk, tüm satırlar `.equal`.
- Yalnız ekleme; yalnız silme; ortadan silme.
- Değişen satırda kelime vurgusu: span'ların birleşimi satırın birebir aynısı.
- Hunk gruplama: 2 satır arayla iki fark → tek hunk; 5 satır arayla → iki hunk.
- `apply` değişmezi: uygulanan hunk sonraki hesapta artık yok.
- Tüm hunk'lar `←` yönünde uygulanınca sol metin sağ metne eşit olur;
  aynısı `→` için sağ metin sol metne.
- CRLF/LF karışımı: hedef tarafın satır sonu korunur.
- Sondaki yeni satırın korunması.
- `D` limiti aşımında `truncated == true` ve tek hunk.
- Unicode: emoji ve birleşik karakter içeren satırlar bozulmadan taşınır.

`CompareController`'ın dosya G/Ç'si geçici dizinde test edilir: okuma,
yazma, dışarıdan değişmiş dosya tespiti.

SwiftUI görünümü (`CompareView`) birim testsiz kalır; doğrulama uygulamayı
çalıştırarak yapılır.

## 11. Uygulama sırası

1. `project.yml` test hedefi + boş test dosyası; `xcodebuild test` yeşil.
2. `TextDiff` — satır bölme, Myers, testlerle birlikte.
3. `TextDiff` — hunk gruplama, testlerle.
4. `TextDiff` — satır içi kelime diff'i, testlerle.
5. `TextDiff.apply` — testlerle.
6. `DiffPalette`.
7. `CompareController` — dosya açma, bookmark, diff hesabı, G/Ç testleri.
8. `CompareView` — tablo, katlama, oluk düğmeleri.
9. `ViewMode.compare` + `ContentView` + `MarkPadApp` menü bağlantıları.
10. Uygulamayı çalıştırarak elle doğrulama.
