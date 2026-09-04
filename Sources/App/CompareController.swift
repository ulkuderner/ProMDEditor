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
    /// Karsi dosyanin bellekteki metni. Disaridan yalnizca
    /// `setOtherText(_:documentText:)` ile degistirilir; boylece her yazma
    /// tek noktadan gecer ve diff'in bayat kalmasi onlenir (bkz. Bulgu C1).
    @Published private(set) var otherText: String = ""
    @Published private(set) var result: DiffResult = .empty
    @Published private(set) var otherIsDirty = false
    @Published var alertMessage: String?

    /// Kullanici ⇧⌘D / "Karşılaştırılacak dosyayı seç…" panelinden bilincli
    /// olarak Vazgec dediyse true. Bu oturumda `restoreBookmark()`'in bayat
    /// bir dosyayi otomatik geri yuklemesini engellemek icin kullanilir.
    private(set) var didDeclineChoice = false

    /// Karsi dosyaya yapilan aktarmalarin geri alma yigini.
    /// Acik belgenin ⌘Z yigini ayridir; ikisi karistirilmaz.
    private var pushUndoStack: [String] = []

    /// Dosyanin acildigi/kaydedildigi andaki degisiklik tarihi.
    /// Diske yazmadan once disaridan degisip degismedigini anlamak icin.
    private var lastKnownModification: Date?

    private var recomputeTask: Task<Void, Never>?

    /// Bookmark'in yazildigi depo. Uretimde uygulamanin App Group
    /// `UserDefaults`'u; testler yalitilmis bir suite enjekte eder
    /// (bkz. Defter #7).
    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppSettings.shared.defaults) {
        self.defaults = defaults
    }

    private static let bookmarkKey = "compareBookmark"
    /// 10 MB ustu dosyalarda kullaniciya onay sorulur.
    private static let largeFileBytes = 10 * 1024 * 1024
    /// Testlerde gercek NSAlert esigini beklemeden tetiklemek icin;
    /// nil ise `largeFileBytes` kullanilir.
    var largeFileByteThresholdOverride: Int?
    private var largeFileByteThreshold: Int { largeFileByteThresholdOverride ?? Self.largeFileBytes }

    /// Buyuk dosya onayini sorar. Varsayilan gercek bir NSAlert gosterir;
    /// testler bunu gercek UI acmadan taklit etmek icin degistirebilir.
    var confirmLargeFile: (Int) -> Bool = { size in
        let a = NSAlert()
        a.messageText = String(localized: "Large file")
        a.informativeText = String(localized: "This file is \(size / 1024 / 1024) MB. Comparison may be slow. Continue?")
        a.addButton(withTitle: String(localized: "Continue"))
        a.addButton(withTitle: String(localized: "Cancel"))
        return a.runModal() == .alertFirstButtonReturn
    }

    var canUndo: Bool { !pushUndoStack.isEmpty }

    var otherName: String { otherURL?.lastPathComponent ?? "" }

    /// `deinit` ana aktorde calismaz; bu yuzden birakilacak URL'yi
    /// aktor-bagimsiz bir kutuda tutuyoruz.
    private final class AccessBox: @unchecked Sendable {
        var url: URL?
    }
    private let accessBox = AccessBox()

    deinit {
        accessBox.url?.stopAccessingSecurityScopedResource()
    }

    // MARK: - Dosya secme ve okuma

    /// Surukle-birak ve panel icin kabul edilen dosya turleri.
    ///
    /// Uzantiya degil, `UTType` agacina bakariz: boylece `.mdown`, `.mkd` gibi
    /// Markdown lehceleri ve `public.plain-text`'e uyan her metin turu (ornegin
    /// `.log`, `.json`) tek kuralla gecer, ikili dosyalar elenir. Uzantisi
    /// olmayan ya da sistemin tanimadigi dosyalar da elenir — karsilastirma
    /// metin uzerinde calisir, ikili icerik anlamli fark uretmez.
    nonisolated static func isComparableTextFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .plainText) || type.conforms(to: .markdown)
    }

    /// Surukle-birakla gelen dosyayi karsilastirma hedefi yapar.
    ///
    /// Birakma, sandbox'in kullanici hareketi saydigi yollardan biridir —
    /// `NSOpenPanel` gibi erisim verir, ek entitlement gerekmez.
    /// - Returns: dosya kabul edildiyse true.
    @discardableResult
    func acceptDroppedFile(_ url: URL, documentText: String) -> Bool {
        guard Self.isComparableTextFile(url) else {
            alertMessage = String(localized: "\(url.lastPathComponent) is not a text file; it cannot be compared.")
            return false
        }
        do {
            guard try load(url: url) else { return false }
            storeBookmark(url)
            recompute(against: documentText)
            return true
        } catch {
            alertMessage = String(localized: "Could not open file: \(error.localizedDescription)")
            return false
        }
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.markdown, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = String(localized: "Choose a file to compare")
        guard panel.runModal() == .OK, let url = panel.url else {
            // Kullanici paneli bilincli olarak kapatti; `restoreBookmark()`
            // bu oturumda artik otomatik devreye girmesin (bkz. Bulgu M2).
            didDeclineChoice = true
            return
        }

        do {
            if try load(url: url) {
                storeBookmark(url)
            }
            // Kullanici buyuk dosya uyarisinda vazgectiyse `load` false doner;
            // boyle bir dosya acilmadigi icin bookmark'a da yazilmamali.
        } catch {
            alertMessage = String(localized: "Could not open file: \(error.localizedDescription)")
        }
    }

    /// Dosyayi yukler. Kullanici buyuk-dosya uyarisinda vazgecerse `false`
    /// doner (hata degildir); basariyla yuklenirse `true` doner.
    @discardableResult
    func load(url: URL) throws -> Bool {
        // Erisimi ONCE aciyoruz: `restoreBookmark()`'in cozdugu security-scoped
        // URL'lerde nitelikler erisim acilmadan okunamaz (bkz. Bulgu 3).
        _ = url.startAccessingSecurityScopedResource()
        var erisimDevredildi = false
        defer {
            // Basariyla yuklendiyse erisim asagida otherURL/accessBox'a
            // devredilir; her diger cikis yolunda (hata veya vazgecme)
            // burada acilan erisimi biz birakiriz.
            if !erisimDevredildi {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)

        if let size = attrs[.size] as? Int, size > largeFileByteThreshold {
            guard confirmLargeFile(size) else { return false }
        }

        let metin = try Self.readText(at: url)

        releaseCurrentAccess()
        otherText = metin
        otherURL = url
        accessBox.url = url
        erisimDevredildi = true
        lastKnownModification = attrs[.modificationDate] as? Date
        otherIsDirty = false
        pushUndoStack.removeAll()
        didDeclineChoice = false
        return true
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
        accessBox.url = nil
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

    /// Karsi dosyaya yapilan son aktarmayi geri alir.
    ///
    /// `otherText` degistigi icin diff spec §7'nin "her aktarmadan sonra diff
    /// bastan hesaplanir" kuralina uyacak sekilde YENIDEN hesaplanir; aksi
    /// halde `result` artik var olmayan bir metne ait hunk'lar tutar ve
    /// sonraki aktarma yanlis satirlari tasir (bkz. Bulgu C1).
    func undoLastPush(documentText: String) {
        guard let onceki = pushUndoStack.popLast() else { return }
        otherText = onceki
        otherIsDirty = !pushUndoStack.isEmpty || otherChangedFromDisk()
        recompute(against: documentText)
    }

    /// `otherText`'i disaridan degistirmenin tek yolu (test ve arayuz icin).
    /// Metin degistigi icin diff de yeniden hesaplanir.
    func setOtherText(_ metin: String, documentText: String) {
        otherText = metin
        otherIsDirty = true
        recompute(against: documentText)
    }

    private func otherChangedFromDisk() -> Bool {
        guard let url = otherURL, let disk = try? Self.readText(at: url) else { return false }
        return disk != otherText
    }

    // MARK: - Kaydetme

    /// Dosya ProMDEditor disinda degistiyse true.
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
            a.messageText = String(localized: "File changed outside ProMDEditor")
            a.informativeText = String(localized: "\(url.lastPathComponent) was edited elsewhere. Overwrite it?")
            a.addButton(withTitle: String(localized: "Overwrite"))
            a.addButton(withTitle: String(localized: "Cancel"))
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
            alertMessage = String(localized: "Could not save file: \(error.localizedDescription)")
        }
    }

    /// Testlerde kaydetme yolunu tetiklemek icin.
    func markDirtyForTesting() { otherIsDirty = true }

    /// Testlerde `chooseFile()`in gercek `NSOpenPanel`ini acmadan
    /// "Vazgeç" akisini tetiklemek icin (bkz. Bulgu M2).
    func declineChoiceForTesting() { didDeclineChoice = true }

    /// Testlerde `chooseFile()`in basari yolunda yaptigi bookmark kaydini
    /// gercek panel acmadan tetiklemek icin (bkz. Bulgu M2).
    /// Bookmark gercekten uretilebildiyse true doner; testler bookmark
    /// uretilemeyen sandbox durumunda yanlis nedenle gecmesin diye.
    @discardableResult
    func storeBookmarkForTesting(_ url: URL) -> Bool { storeBookmark(url) }

    // MARK: - Bookmark

    /// Bookmark uretilemezse (ornegin security-scope izni yoksa) eski kaydi
    /// silmek yerine oldugu gibi birakiriz: `set(nil, forKey:)` anahtari
    /// tamamen kaldirir ve davranisi sandbox durumuna bagimli kilardi
    /// (bkz. Defter #7).
    @discardableResult
    private func storeBookmark(_ url: URL) -> Bool {
        guard let data = try? url.bookmarkData(options: .withSecurityScope,
                                               includingResourceValuesForKeys: nil,
                                               relativeTo: nil) else { return false }
        defaults.set(data, forKey: Self.bookmarkKey)
        return true
    }

    /// Son karsilastirilan dosyayi geri yukler. Cozulemezse sessizce
    /// bos duruma donulur — kullaniciya hata gosterilmez.
    func restoreBookmark() {
        // Kullanici bu oturumda paneli bilincli olarak Vazgec ile kapattiysa
        // bayat bir bookmark'i sessizce yuklemeyiz (bkz. Bulgu M2).
        guard !didDeclineChoice else { return }
        guard let data = defaults.data(forKey: Self.bookmarkKey) else { return }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                 relativeTo: nil, bookmarkDataIsStale: &stale),
              !stale else { return }
        try? load(url: url)
    }
}
