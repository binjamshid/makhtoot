import MKDesignSystem
import MKFonts
import MKFoundation
import MKModel
import MKTextEngine
import SwiftUI

/// DEBUG shaping harness (WS-03's own deferred deliverable ، see
/// `docs/impl-log/WS-03.md`: "DEBUG harness view
/// (`Makhtoot/App/Debug/ShapingHarnessView.swift`) ، App-dir scope fence;
/// WS-13 territory"). Drives `MKShapingService` (the actor facade WS-03
/// shipped: cached, `typingEcho`-signposted single-line shaping) directly
/// against free-typed Arabic input, so a developer can inspect cluster/
/// bidi/joining/ligature/mark output and cache behavior without a full
/// canvas round trip. DEBUG-only ، reachable from Settings' `#if DEBUG`
/// section only, never in a Release build.
///
/// **WS-09 addition (minimal, additive):** a font picker sourced from
/// `AppContainer.fontRegistry`, defaulting to Amiri, plus
/// `MKShapingService(fonts: MKRegistryFontProvider())` in place of the
/// zero-arg (system-stub) initializer ، purely so the WS-09 packet's own
/// gate ("app builds + boots with fonts registered and «مرحبا» shapes in
/// Amiri via the debug harness") is demonstrable. No other part of this
/// view was restructured.
struct ShapingHarnessView: View {
    @Environment(\.mkTheme) private var theme
    @Environment(AppContainer.self) private var container
    @State private var inputText = "مرحبا ، بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ"
    @State private var result: MKShapingCaptureResult?
    @State private var lastDuration: Duration?
    @State private var cacheCounters: (hits: Int, misses: Int) = (0, 0)
    @State private var availableFonts: [MKFontRecord] = []
    @State private var selectedFontID: MKFontID = "amiri"

    /// `@State`, not a plain `let`: SwiftUI may reconstruct this `View`
    /// struct on every re-render ، a plain stored property would silently
    /// mint a FRESH `MKShapingService` (and lose its cache) each time,
    /// defeating the entire point of this harness's cache-counter section.
    @State private var service = MKShapingService(fonts: MKRegistryFontProvider())

    var body: some View {
        Form {
            Section(inputSectionTitle) {
                TextField(inputPlaceholder, text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .multilineTextAlignment(.trailing)
                    #if os(iOS)
                    .keyboardType(.default)
                    #endif
                if !availableFonts.isEmpty {
                    Picker(fontPickerLabel, selection: $selectedFontID) {
                        ForEach(availableFonts, id: \.fontID) { record in
                            Text(record.familyName).tag(record.fontID)
                        }
                    }
                }
                Button(shapeButtonLabel) {
                    Task { await shape() }
                }
                .disabled(inputText.isEmpty)
            }

            if let result {
                Section(resultSectionTitle) {
                    metricRow(label: lineCountLabel, value: "\(result.paragraph.lines.count)")
                    metricRow(label: glyphCountLabel, value: "\(result.paragraph.glyphCount)")
                    if let firstLine = result.paragraph.lines.first {
                        metricRow(label: runCountLabel, value: "\(firstLine.runs.count)")
                        metricRow(label: clusterCountLabel, value: "\(firstLine.clusterMap.clusters.count)")
                        metricRow(label: baseDirectionLabel, value: firstLine.bidiMap.baseDirection == .rightToLeft ? rtlLabel : ltrLabel)
                    }
                    if let analysis = result.lineAnalyses.first {
                        metricRow(label: markCountLabel, value: "\(analysis.marks.count)")
                        metricRow(label: ligatureCountLabel, value: "\(analysis.ligatures.count)")
                        metricRow(label: joiningCountLabel, value: "\(analysis.joining.count)")
                    }
                }

                Section(perfSectionTitle) {
                    if let lastDuration {
                        metricRow(label: durationLabel, value: lastDuration.formatted())
                    }
                    metricRow(label: cacheHitsLabel, value: "\(cacheCounters.hits)")
                    metricRow(label: cacheMissesLabel, value: "\(cacheCounters.misses)")
                }
            }

            Section {
                Button(invalidateCacheLabel, role: .destructive) {
                    Task {
                        await service.invalidateCache()
                        cacheCounters = await service.cacheCounters()
                    }
                }
            }
        }
        .navigationTitle(Text(navTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            // Fonts register asynchronously off the main actor at app
            // launch (`AppContainer.init` → `MKFontRegistrar`); by the time
            // this DEBUG view appears (Settings → several taps deep) it has
            // virtually always finished, but this loop tolerates the rare
            // case where the harness is opened before registration lands.
            for _ in 0..<20 {
                let records = await container.fontRegistry.records()
                if !records.isEmpty {
                    availableFonts = records
                    if !records.contains(where: { $0.fontID == selectedFontID }) {
                        selectedFontID = records.first?.fontID ?? selectedFontID
                    }
                    break
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func shape() async {
        let style: MKTextStyle
        if let face = availableFonts.first(where: { $0.fontID == selectedFontID })?.faces.first {
            style = MKTextStyle(font: MKFontRef(fontID: selectedFontID, postScriptName: face.postScriptName), pointSize: 28)
        } else {
            style = .default
        }
        let request = MKShapingRequest(string: inputText, style: style, frame: .singleLine)
        let clock = ContinuousClock()
        let start = clock.now
        let capture = await service.captureResult(request)
        lastDuration = clock.now - start
        result = capture
        cacheCounters = await service.cacheCounters()
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(theme.inkMuted)
            Spacer()
            Text(value)
                .foregroundStyle(theme.ink)
        }
    }

    private var navTitle: String {
        // Latin gloss: shaping harness
        "مختبر التشكيل النصي"
    }
    private var inputSectionTitle: String {
        // Latin gloss: input text
        "النص المُدخل"
    }
    private var inputPlaceholder: String {
        // Latin gloss: type Arabic text here
        "اكتب نصًا عربيًا هنا"
    }
    private var fontPickerLabel: String {
        // Latin gloss: font
        "الخط"
    }
    private var shapeButtonLabel: String {
        // Latin gloss: shape
        "تشكيل"
    }
    private var resultSectionTitle: String {
        // Latin gloss: shaping result
        "نتيجة التشكيل"
    }
    private var lineCountLabel: String {
        // Latin gloss: line count
        "عدد الأسطر"
    }
    private var glyphCountLabel: String {
        // Latin gloss: glyph count
        "عدد الحروف المرسومة"
    }
    private var runCountLabel: String {
        // Latin gloss: run count
        "عدد الشرائح (Runs)"
    }
    private var clusterCountLabel: String {
        // Latin gloss: cluster count
        "عدد العناقيد (Clusters)"
    }
    private var baseDirectionLabel: String {
        // Latin gloss: base direction
        "اتجاه الفقرة"
    }
    private var rtlLabel: String { "من اليمين لليسار" }
    private var ltrLabel: String { "من اليسار لليمين" }
    private var markCountLabel: String {
        // Latin gloss: tashkeel/mark count
        "عدد علامات التشكيل"
    }
    private var ligatureCountLabel: String {
        // Latin gloss: ligature count
        "عدد الرِّباطات"
    }
    private var joiningCountLabel: String {
        // Latin gloss: joining-analysis entry count
        "عدد تحليلات الاتصال"
    }
    private var perfSectionTitle: String {
        // Latin gloss: performance
        "الأداء"
    }
    private var durationLabel: String {
        // Latin gloss: last shaping duration
        "مدة آخر عملية تشكيل"
    }
    private var cacheHitsLabel: String {
        // Latin gloss: cache hits
        "إصابات الذاكرة المؤقتة"
    }
    private var cacheMissesLabel: String {
        // Latin gloss: cache misses
        "إخفاقات الذاكرة المؤقتة"
    }
    private var invalidateCacheLabel: String {
        // Latin gloss: clear cache
        "إفراغ الذاكرة المؤقتة"
    }
}

#Preview {
    NavigationStack {
        ShapingHarnessView()
    }
    .environment(\.mkTheme, HibrTheme.default)
}
