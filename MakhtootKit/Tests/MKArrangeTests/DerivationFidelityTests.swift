import Testing
import CoreGraphics
import MKArrange
import MKFoundation
import MKModel
import MKRender
import MKTextEngine

/// WS-04 packet §5 task 3 ، the fidelity invariant gate (D-106): "render
/// live text vs derived composition of the same fixtures... per-pixel diff
/// ≤ 0.5% differing pixels." Renders through the REAL `MKRender
/// .MKSnapshotRenderer` (WS-07's shipped renderer) rather than a hand-
/// rolled rasterizer ، see `Package.swift`'s `MKArrangeTests` comment for
/// why the packet's "local CG rasterizer" fallback is unnecessary here.
@Suite struct DerivationFidelityTests {
    private let tolerance = 0.005   // 0.5%, packet-normative

    /// Builds a canvas-sized scene containing exactly one live-text node
    /// with a visible fill (`MKSolidColor.defaultInk`, matching
    /// `ArrangeDeriver`'s own default `paintStyle`) and renders it; then
    /// derives an `ArrangedComposition` from the SAME capture/style/paint
    /// and renders that instead, with the arranged node sharing the exact
    /// same `MKNodeCore` (transform/z/opacity/style ، task 3's "entering
    /// Arrange Mode must be pixel-identical to the live rendering" implies
    /// same placement too, not just glyph shapes). Returns the diff
    /// fraction.
    private func fidelityDiff(_ text: String, pointSize: Double = 36, canvasSize: CGSize = CGSize(width: 400, height: 200)) async -> Double {
        let style = ArrangeFixtures.systemStyle(size: pointSize)
        let paintStyle = MKStyle(fill: .solid(.defaultInk))
        let core = MKNodeCore(name: "text", transform: MKTransform2D(position: CGPoint(x: 20, y: 60)), style: paintStyle)

        let liveNode = MKLiveTextNode(core: core, text: MKSourceText(string: text), style: style)
        let liveScene = MKScene(
            canvas: MKCanvasSpec(size: canvasSize),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: [.liveText(liveNode)])

        let capture = await ArrangeFixtures.capture(text, style: style)
        let composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture, paintStyle: paintStyle)
        let arrangedNode = MKArrangedTextNode(core: core, composition: composition, derivedFrom: .liveText)
        let arrangedScene = MKScene(
            canvas: MKCanvasSpec(size: canvasSize),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: [.arranged(arrangedNode)])

        let renderer = MKSnapshotRenderer()
        let scale: CGFloat = 3   // packet task 3: "at 3× scale"
        guard let liveImage = renderer.renderFullCanvas(liveScene, scale: scale, quality: .exportQuality),
              let arrangedImage = renderer.renderFullCanvas(arrangedScene, scale: scale, quality: .exportQuality)
        else {
            Issue.record("failed to render one of the two scenes for '\(text)'")
            return 1.0
        }
        return PixelDiff.differingFraction(liveImage, arrangedImage)
    }

    @Test func laaFidelity() async {
        let diff = await fidelityDiff("لا")
        #expect(diff <= tolerance, "لا derivation-vs-live diff \(diff) exceeds \(tolerance)")
    }

    @Test func muhammadWithFullTashkeelFidelity() async {
        let diff = await fidelityDiff("مُحَمَّدٌ")
        #expect(diff <= tolerance, "مُحَمَّدٌ derivation-vs-live diff \(diff) exceeds \(tolerance)")
    }

    @Test func mixedArabicLatinNumeralsFidelity() async {
        let diff = await fidelityDiff("عام ٢٠٢٦ / 2026")
        #expect(diff <= tolerance, "mixed bidi derivation-vs-live diff \(diff) exceeds \(tolerance)")
    }

    @Test func twoLineParagraphFidelity() async {
        let text = "التصميم Design\nعام ٢٠٢٦ ، 2026"
        let style = ArrangeFixtures.systemStyle(size: 28)
        let paintStyle = MKStyle(fill: .solid(.defaultInk))
        let core = MKNodeCore(name: "text", transform: MKTransform2D(position: CGPoint(x: 20, y: 40)), style: paintStyle)
        let canvasSize = CGSize(width: 500, height: 300)

        let liveNode = MKLiveTextNode(core: core, text: MKSourceText(string: text), style: style, frame: .widthConstrained(width: 460))
        let liveScene = MKScene(canvas: MKCanvasSpec(size: canvasSize), nodes: [.liveText(liveNode)])

        let capture = await ArrangeFixtures.captureWrapped(text, width: 460, style: style)
        let composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture, paintStyle: paintStyle)
        let arrangedNode = MKArrangedTextNode(core: core, composition: composition, derivedFrom: .liveText)
        let arrangedScene = MKScene(canvas: MKCanvasSpec(size: canvasSize), nodes: [.arranged(arrangedNode)])

        let renderer = MKSnapshotRenderer()
        guard let liveImage = renderer.renderFullCanvas(liveScene, scale: 3, quality: .exportQuality),
              let arrangedImage = renderer.renderFullCanvas(arrangedScene, scale: 3, quality: .exportQuality)
        else {
            Issue.record("failed to render two-line fixture")
            return
        }
        let diff = PixelDiff.differingFraction(liveImage, arrangedImage)
        #expect(diff <= tolerance, "two-line paragraph derivation-vs-live diff \(diff) exceeds \(tolerance)")

        #expect(composition.nodes.count > 0)
        // Every child carries a bidiLevel; Latin LETTER sub-run nodes
        // should be even, Arabic LETTER nodes odd (D-109, packet task 16
        // assertion, exercised here since this is already the two-line
        // mixed fixture). Deliberately restricted to unambiguous ALPHABETIC
        // scalars ، digits (Arabic-Indic or ASCII) and punctuation are weak/
        // neutral bidi types whose embedding level is a genuine UBA
        // decision Core Text makes contextually (e.g. a trailing "2026" can
        // legitimately attach to a preceding RTL run), not something a
        // static codepoint-range heuristic should try to out-guess.
        for child in composition.nodes {
            let provenance: MKProvenance
            switch child {
            case .glyph(let g): provenance = g.provenance
            case .mark(let m): provenance = m.provenance
            case .ligature(let l): provenance = l.provenance
            }
            guard let scalar = provenance.codepoints.first.flatMap(Unicode.Scalar.init) else { continue }
            if ("a"..."z").contains(Character(scalar)) || ("A"..."Z").contains(Character(scalar)) {
                #expect(provenance.bidiLevel % 2 == 0, "Latin letter node \(child.id) expected even bidiLevel, got \(provenance.bidiLevel)")
            } else if (0x0621...0x064A).contains(scalar.value) {
                // Basic Arabic letter block (excludes tashkeel/digits).
                #expect(provenance.bidiLevel % 2 == 1, "Arabic letter node \(child.id) expected odd bidiLevel, got \(provenance.bidiLevel)")
            }
        }
    }
}
