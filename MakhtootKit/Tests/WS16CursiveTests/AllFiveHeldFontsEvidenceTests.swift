import Testing
import CoreGraphics
import CoreText
import MKArrange
import MKFoundation
import MKModel
import MKRender
import MKTextEngine

// WS-16 (`docs/impl-log/WS-16-cursive.md`, ADR WS16-A3). D-222 step 8 held
// 5 fonts pending a "cursive-pair structure" in D-105: Amiri, Amiri Quran,
// Aref Ruqaa, Rakkas, Qahiri. This suite runs the SAME two-part evidence
// (font actually registers + real GPOS 'curs' coverage fires on captured
// glyphs + T-AR-31-class derivation fidelity holds) across ALL FIVE, not
// just the Amiri fixture the packet's own probe instructions named ، the
// release decision in `Resources/EXCLUDED_FONTS.md`/`records.json` this
// session covers all 5 on this evidence, not Amiri alone.
@Suite struct AllFiveHeldFontsEvidenceTests {
    private let tolerance = 0.005

    @Test(arguments: WS16Fixtures.heldFonts)
    func fontActuallyRegisters(_ font: (postScriptName: String, resourcePath: String)) {
        let style = WS16Fixtures.style(postScriptName: font.postScriptName, size: 40)
        let line = MKShapingEngine(fonts: WS16Fixtures.amiriFonts).shapeSingleLine(MKShapingRequest(string: "محمد", style: style))
        let resolved = line.runs.first?.font.postScriptName
        #expect(resolved == font.postScriptName, "\(font.postScriptName) did not register ، got \(resolved ?? "nil")")
    }

    /// T-AR-31-class evidence (D-222): derive an `ArrangedComposition` from
    /// plain Live Text and render both through the real
    /// `MKSnapshotRenderer` ، live vs. arranged must be pixel-identical
    /// within the 0.5% D-222 bar, for EVERY held font, not just Amiri.
    @Test(arguments: WS16Fixtures.heldFonts)
    func derivationFidelityHoldsForHeldFont(_ font: (postScriptName: String, resourcePath: String)) async {
        let text = "محمد"
        let style = WS16Fixtures.style(postScriptName: font.postScriptName, size: 40)
        let fonts = WS16Fixtures.amiriFonts
        let paintStyle = MKStyle(fill: .solid(.defaultInk))
        let core = MKNodeCore(name: "text", transform: MKTransform2D(position: CGPoint(x: 20, y: 80)), style: paintStyle)
        let canvasSize = CGSize(width: 400, height: 200)

        let liveNode = MKLiveTextNode(core: core, text: MKSourceText(string: text), style: style)
        let liveScene = MKScene(
            canvas: MKCanvasSpec(size: canvasSize),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: [.liveText(liveNode)])

        let capture = await WS16Fixtures.capture(text, style: style)
        let composition = await ArrangeDeriver(fonts: fonts).derive(sourceText: text, style: style, capture: capture, paintStyle: paintStyle)
        let arrangedNode = MKArrangedTextNode(core: core, composition: composition, derivedFrom: .liveText)
        let arrangedScene = MKScene(
            canvas: MKCanvasSpec(size: canvasSize),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: [.arranged(arrangedNode)])

        let renderer = MKSnapshotRenderer()
        guard let liveImage = renderer.renderFullCanvas(liveScene, scale: 3, quality: .exportQuality),
              let arrangedImage = renderer.renderFullCanvas(arrangedScene, scale: 3, quality: .exportQuality)
        else {
            Issue.record("failed to render one of the two scenes for \(font.postScriptName)")
            return
        }
        let diff = WS16PixelDiff.differingFraction(liveImage, arrangedImage)
        #expect(diff <= tolerance, "«محمد» derivation-vs-live diff \(diff) exceeds \(tolerance) on \(font.postScriptName)")
    }

    /// Confirms `MKShapedRun.cursiveAttached` fires for real, representative
    /// text on EVERY held font (not just Amiri's «سجا» fixture) ، proving
    /// the WS-16 capture mechanism generalizes across the 5 fonts sharing
    /// D-222's step-8 finding, using a representative letter-sequence sweep
    /// per font (structural ، no hardcoded glyph ids, WS03-A4 convention).
    @Test(arguments: WS16Fixtures.heldFonts)
    func cursiveAttachedFlagFiresOnRepresentativeTextForHeldFont(_ font: (postScriptName: String, resourcePath: String)) async {
        let corpus = ["سجا", "سجد", "سجل", "محمد رسول الله", "بسم الله الرحمن الرحيم", "الحمد لله رب العالمين"]
        let style = WS16Fixtures.style(postScriptName: font.postScriptName, size: 40)
        var anyFlagged = false
        for word in corpus {
            let line = MKShapingEngine(fonts: WS16Fixtures.amiriFonts).shapeSingleLine(MKShapingRequest(string: word, style: style))
            if line.runs.contains(where: { $0.cursiveAttached.contains(true) }) {
                anyFlagged = true
                break
            }
        }
        #expect(anyFlagged, "expected at least one cursive-attached glyph across the representative corpus on \(font.postScriptName) ، WS-09's audit found GPOS LookupType 3 on this font's base glyphs, so the capture-level flag should observe it on SOME real text")
    }
}
