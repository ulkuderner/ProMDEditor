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
            } else if controller.result.hunks.isEmpty {
                message("İki dosya birebir aynı.")
            } else {
                if controller.result.truncated { truncationWarning }
                table
            }
        }
        .background(Color(nsColor: theme.nsBackground))
        .onAppear {
            if controller.otherURL == nil { controller.restoreBookmark() }
            controller.recompute(against: documentText)
        }
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
                    Button("Geri al") { controller.undoLastPush(documentText: documentText) }
                        .help("Karşı dosyaya yapılan son aktarmayı geri alır (⌘Z bu belgeye aittir)")
                }
                if controller.otherIsDirty {
                    Text("●").foregroundStyle(.orange)
                        .help("Karşı dosyada kaydedilmemiş değişiklik var")
                    // Kisayol yok: ⇧⌘S `DocumentGroup`'un "Kopyasini Olustur"
                    // komutuna ait; ayni kombinasyonu paylasmak iki komutun
                    // düğmenin varligina gore yer degistirmesine yol acardi
                    // (bkz. Bulgu I1). Spec §6 bu düğme icin kisayol istemiyor.
                    Button("Karşı dosyayı kaydet") { controller.saveOther() }
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
        while i < rows.count {
            if gorunur.contains(i) {
                items.append(.row(index: i, id: i))
                i += 1
                continue
            }
            var j = i
            while j < rows.count && !gorunur.contains(j) { j += 1 }
            // Kimlik, katlanan araligin BASLANGIC satir indeksinden turetilir
            // (hesaplamadaki siradan degil). Boylece diff yeniden hesaplandiginda
            // ayni icerige (ayni baslangic satirina) sahip bir bosluk hep ayni
            // kimligi alir; expandedFolds bu kimlikle tutarli kalir.
            let id = i
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
