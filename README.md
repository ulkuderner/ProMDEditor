# ProMDEditor

macOS için Markdown düzenleyici + görüntüleyici + **Quick Look** eklentisi.
Finder'da bir `.md` dosyası seçip boşluk tuşuna bastığında render edilmiş halini gösterir;
uygulamanın kendisi ise canlı biçimlendirmeli bir editör ve yan panelde önizleme sunar.

Dosya her zaman **düz `.md`** olarak saklanır — WYSIWYG dönüşüm kaybı yok.

## Özellikler

- Canlı sözdizimi biçimlendirmesi: başlıklar gerçek boyutta, `**kalın**` kalın, `*italik*` italik,
  kod tek aralıklı ve arka planlı, bağlantılar renkli. Markdown işaretleri soluk gri.
- ⌘B / ⌘I / ⌘K / ⌘E ve tüm biçim menüsü — seçime uygulanır, ikinci basışta kaldırır (toggle).
- Return ile liste/görev listesi otomatik devam eder, boş maddede listeyi bitirir.
- Bölünmüş görünüm, kaydırma senkronizasyonu (⌘1 / ⌘2 / ⌘3).
- Dosya karşılaştırma modu (⌘4): açık belgeyi başka bir `.md`/`.txt` dosyasıyla
  yan yana karşılaştırır (⇧⌘D ile karşılaştırılacak dosyayı seç). Satır satır
  hizalanmış görünüm, kelime bazlı vurgulu farklar, değişmeyen uzun bölümler
  katlanır. Her fark bloğu çift yönlü aktarılabilir: `←` karşı dosyadaki
  bölümü açık belgeye alır, `→` bölümü karşı dosyaya yazar (bellekte kalır,
  diske yazmak için ayrı "Karşı dosyayı kaydet" adımı gerekir). Karşı dosya
  açık belgeden bağımsız kaydedilir; ProMDEditor dışında değiştiyse üzerine
  yazmadan önce onay ister.
- GFM: tablolar, görev listeleri, üstü çizili, fenced code.
- **36 tema** — İstanbul Day/Night (varsayılan), GitHub, Ayu, Night Owl, Kanagawa,
  Vitesse, Catppuccin, Gruvbox, Rosé Pine, Tokyo Night, Dracula, Monokai, Nord,
  Cobalt2, Panda, Material Ocean ve yüksek kontrast seçenekleri.
  Hepsi WCAG AAA hedefine göre ayarlandı: gövde metni ≥8:1, bağlantı ve soluk
  metin ≥4.6:1, kod bloğu ≥7:1 (bkz. `Tools/fix_contrast.py`).
- Araç çubuğundan tema seçici; açık/koyu tema ayrı seçilir, sistem görünümünü izler.
- Sistemdeki **tüm yazı tipleri** arasından gövde / başlık / tek aralıklı / editör fontu ayrı ayrı
  seçilebilir; punto, satır yüksekliği, içerik genişliği, iki yana yaslama, daktilo modu.
- HTML dışa aktarma ve Yazdır → PDF olarak kaydet.
- Quick Look önizlemesi uygulamayla aynı temayı ve fontları kullanır.

## Kullanılan açık kaynak

| Proje | Lisans | Rol |
|---|---|---|
| [apple/swift-markdown](https://github.com/apple/swift-markdown) | Apache-2.0 | cmark-gfm tabanlı GFM ayrıştırıcı |

HTML üretici (`MarkdownHTMLRenderer.swift`), editör biçimlendiricisi, temalar ve
Quick Look eklentisi bu projeye özgü.

## Derleme

```bash
brew install xcodegen          # tek seferlik
cd ~/MarkPad
xcodegen generate
open MarkPad.xcodeproj
```

Xcode'da:

1. `MarkPad` hedefi → **Signing & Capabilities** → *Team*'i seç (ücretsiz Apple ID yeterli).
   Aynısını `MarkPadQuickLook` hedefi için de yap.
2. Bundle ID'leri kendine göre değiştir (`com.caglar.MarkPad` → seninki).
3. ⌘R ile çalıştır.

### App Group hakkında

Ayarların Quick Look eklentisine geçmesi için iki hedefte de aynı App Group tanımlı olmalı
(`group.<TeamID>.com.caglar.MarkPad` biçimi macOS'ta gerekir). Team ID'n yoksa
`.entitlements` dosyalarındaki `application-groups` bloklarını sil — uygulama sorunsuz çalışır,
Quick Look yalnızca varsayılan tema/fontları kullanır.

## Quick Look'u devreye alma

Eklentiler yalnızca uygulama düzgün bir konumdayken yüklenir:

```bash
# Xcode'un ürettiği .app'i Uygulamalar'a kopyala
cp -R ~/Library/Developer/Xcode/DerivedData/MarkPad-*/Build/Products/Debug/ProMDEditor.app /Applications/

# Eklentiyi kaydet ve Quick Look'u sıfırla
pluginkit -a /Applications/ProMDEditor.app/Contents/PlugIns/MarkPadQuickLook.appex
qlmanage -r && qlmanage -r cache
killall Finder
```

Doğrulama:

```bash
pluginkit -m -p com.apple.quicklook.preview | grep -i markpad   # + ile başlamalı (etkin)
qlmanage -p ornek.md                                            # önizlemeyi ayrı pencerede aç
```

Hâlâ ham metin görünüyorsa: Finder'da bir `.md` dosyasına ⌘I → *Birlikte Aç* → **ProMDEditor** →
*Tümünü Değiştir*. macOS önizleme sağlayıcısını çoğu zaman varsayılan uygulamaya göre seçer.

## Dosya düzeni

```
Sources/
  Shared/                     # hem uygulama hem eklenti kullanır
    MarkdownHTMLRenderer.swift  Markdown -> HTML (MarkupVisitor)
    Theme.swift                 temalar + CSS üretimi
    AppSettings.swift           paylaşılan ayarlar
    TextDiff.swift               satır+kelime bazlı diff motoru
    DiffPalette.swift            karşılaştırma renkleri (tema başına)
  App/
    MarkPadApp.swift            DocumentGroup, menüler, kısayollar
    MarkdownDocument.swift      .md okuma/yazma
    ContentView.swift           pencere, araç çubuğu, dışa aktarma
    EditorView.swift            NSTextView sarmalayıcı, liste devamı
    MarkdownHighlighter.swift   canlı biçimlendirme kuralları
    FormatCommand.swift         ⌘B, liste, tablo vb. metin işlemleri
    PreviewWebView.swift        WKWebView önizleme
    SettingsView.swift          font/tema/düzen ayarları
    CompareController.swift     karşılaştırma durumu, dosya G/Ç, aktarma
    CompareView.swift           karşılaştırma görünümü (⌘4)
  QuickLook/
    PreviewViewController.swift QLPreviewingController
Tools/
  MakeIcon.swift              uygulama ikonunu Core Graphics ile üretir
  fix_contrast.py             tema paletlerini WCAG hedeflerine göre ayarlar
  make_dmg.sh                 Release derleyip dağıtıma hazır DMG üretir
```

## Paketleme

### Doğrudan dağıtım (DMG)

```bash
./Tools/make_dmg.sh                                   # ad-hoc imza (yerel kullanım)
./Tools/make_dmg.sh "Developer ID Application: Ad (TEAMID)"   # dağıtım için
```

Çıktı `dist/ProMDEditor-<sürüm>.dmg`. Ad-hoc imzalı paket Gatekeeper tarafından
reddedilir; başka makinelerde sorunsuz açılması için Developer ID imzası ve
notarization gerekir:

```bash
xcrun notarytool submit dist/ProMDEditor-1.0.dmg \
  --apple-id <apple-id> --team-id <TEAMID> --wait
xcrun stapler staple dist/ProMDEditor-1.0.dmg
```

### Mac App Store

Proje App Store gereksinimlerini karşılayacak şekilde hazırlandı:

| Gereksinim | Durum |
|---|---|
| App Sandbox | ✅ açık |
| Asset catalog ikonu (1024×1024 dahil) | ✅ `Resources/Assets.xcassets` |
| `PrivacyInfo.xcprivacy` (uygulama + eklenti) | ✅ veri toplanmıyor, `UserDefaults` için `CA92.1` |
| `LSApplicationCategoryType` | ✅ Developer Tools |
| Şifreleme beyanı | ✅ `ITSAppUsesNonExemptEncryption = false` |

Kalan adımlar hesap gerektiriyor:

1. Apple Developer Program üyeliği (yıllık 99 USD).
2. Developer portalında kimlikleri kaydet: `com.caglar.MarkPad`,
   `com.caglar.MarkPad.QuickLook` ve App Group.
3. App Group'u geri ekle — Team ID öneki zorunlu olduğu için ad
   `group.<TeamID>.com.caglar.MarkPad` olmalı. İki `.entitlements` dosyasına da
   eklenmeli; bu sayede Quick Look önizlemesi uygulamanın tema ve font
   ayarlarını kullanır.
4. Xcode → hedef → Signing & Capabilities → Team seç, otomatik imzalama açık.
5. Product → Archive → Distribute App → App Store Connect.
6. App Store Connect'te kayıt: ekran görüntüsü (2560×1600 veya 1280×800),
   açıklama, gizlilik politikası URL'si, destek URL'si.

Mac App Store için notarization gerekmez; o yalnızca Developer ID dağıtımı içindir.

## Geliştirme fikirleri

- Sol tarafta klasör gezgini (`NSOutlineView` + güvenlik kapsamlı yer imleri) — vault mantığı.
- Kod bloklarına sözdizimi renklendirmesi: `highlight.js` bundle'a gömülüp CSS'e eklenebilir.
- Mermaid diyagramları (yalnızca uygulama içinde; Quick Look'ta JS kapalı).
- `qlmanage -t` için ayrı bir **Thumbnail Extension** — Finder ikonlarında da render.
- Dipnot ve `[[wiki-link]]` desteği için `MarkdownHTMLRenderer` içine ön-işlem adımı.

## Benzer açık kaynak projeler

- [sbarex/QLMarkdown](https://github.com/sbarex/QLMarkdown) — sadece Quick Look, çok zengin
- [MacDownApp/macdown](https://github.com/MacDownApp/macdown) — klasik editör, Objective-C
- [marktext/marktext](https://github.com/marktext/marktext) — Electron, gerçek WYSIWYG
- [gonzalezreal/swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) — WebView yerine
  saf SwiftUI ile render etmek istersen

## Lisans

MIT.
> 