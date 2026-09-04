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
    /// Testlerde gercek NSAlert esigini beklemeden tetiklemek icin;
    /// nil ise `largeFileBytes` kullanilir.
    var largeFileByteThresholdOverride: Int?
    private var largeFileByteThreshold: Int { largeFileByteThresholdOverride ?? Self.largeFileBytes }

    /// Buyuk dosya onayini sorar. Varsayilan gercek bir NSAlert gosterir;
    /// testler bunu gercek UI acmadan taklit etmek icin degistirebilir.
    var confirmLargeFile: (Int) -> Bool = { size in
        let a = NSAlert()
        a.messageText = "Büyük dosya"
        a.informativeText = "Bu dosya \(size / 1024 / 1024) MB. Karşılaştırma yavaş olabilir. Devam edilsin mi?"
        a.addButton(withTitle: "Devam")
        a.addButton(withTitle: "Vazgeç")
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

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.markdown, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Karşılaştırılacak dosyayı seç"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            if try load(url: url) {
                storeBookmark(url)
            }
            // Kullanici buyuk dosya uyarisinda vazgectiyse `load` false doner;
            // boyle bir dosya acilmadigi icin bookmark'a da yazilmamali.
        } catch {
            alertMessage = "Dosya açılamadı: \(error.localizedDescription)"
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
