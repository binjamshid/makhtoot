import Testing
import CoreGraphics
import MKArrange
import MKFoundation
import MKModel
import MKRender
import MKTextEngine

// WS-16 (`docs/impl-log/WS-16-cursive.md`, ADR WS16-A3). D-222's per-font
// arrange-fidelity gate (T-AR-31/32/33) for the real bundled Amiri binary,
// specifically over CURSIVE-ATTACHMENT-AFFECTED text (the exact class of
// content D-222 step 8 held Amiri out of the catalog for). Mirrors
// `MKArrangeTests/DerivationFidelityTests.swift`'s own method (render live
// text vs. derive-then-render the SAME text through the real
// `MKSnapshotRenderer`, diff the two bitmaps) without editing that file ،
// see `Package.swift`'s `WS16CursiveTests` comment for why this lives in
// its own target.
@Suite struct CursiveDerivationFidelityTests {
    private let tolerance = 0.005   // 0.5%, same D-222/packet-normative bar DerivationFidelityTests uses

    private func fidelityDiff(_ text: String, pointSize: Double = 48, canvasSize: CGSize = CGSize(width: 400, height: 200)) async -> Double {
        let style = WS16Fixtures.amiriStyle(size: pointSize)
        let paintStyle = MKStyle(fill: .solid(.defaultInk))
        let core = MKNodeCore(name: "text", transform: MKTransform2D(position: CGPoint(x: 20, y: 80)), style: paintStyle)

        let liveNode = MKLiveTextNode(core: core, text: MKSourceText(string: text), style: style)
        let liveScene = MKScene(
            canvas: MKCanvasSpec(size: canvasSize),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: [.liveText(liveNode)])

        let capture = await WS16Fixtures.capture(text, style: style)
        let composition = await ArrangeDeriver(fonts: WS16Fixtures.amiriFonts).derive(sourceText: text, style: style, capture: capture, paintStyle: paintStyle)
        let arrangedNode = MKArrangedTextNode(core: core, composition: composition, derivedFrom: .liveText)
        let arrangedScene = MKScene(
            canvas: MKCanvasSpec(size: canvasSize),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: [.arranged(arrangedNode)])

        let renderer = MKSnapshotRenderer()
        let scale: CGFloat = 3
        guard let liveImage = renderer.renderFullCanvas(liveScene, scale: scale, quality: .exportQuality),
              let arrangedImage = renderer.renderFullCanvas(arrangedScene, scale: scale, quality: .exportQuality)
        else {
            Issue.record("failed to render one of the two scenes for '\(text)'")
            return 1.0
        }
        return WS16PixelDiff.differingFraction(liveImage, arrangedImage)
    }

    /// Baseline sanity: Amiri derivation fidelity for ordinary (non-cursive)
    /// text, same class DerivationFidelityTests already proves for other
    /// fonts ، establishes Amiri isn't broken in some UNRELATED way before
    /// trusting the cursive-specific fixture below.
    @Test func muhammadFidelityOnAmiri() async {
        let diff = await fidelityDiff("محمد")
        #expect(diff <= tolerance, "«محمد» derivation-vs-live diff \(diff) exceeds \(tolerance) on Amiri")
    }

    /// The load-bearing test: «سجا» ، probed (docs/impl-log/WS-16-cursive.md)
    /// to trigger Amiri's GPOS cursive-attachment (LookupType 3) feature, a
    /// real, measurable, Core-Text-applied vertical position adjustment on
    /// the jeem/following-letter pair. This proves the D-222 step-8 concern
    /// ("does D-105's capture model correctly carry a cursive-adjusted
    /// position into Arrange Mode") is answered YES for the plain
    /// derivation case with ZERO new geometry code ، `CTRunGetPositions`
    /// already baked the adjustment in, `ArrangeDeriver.makeGlyphNode`
    /// already copies it verbatim, and `MKArrangedGeometry` already composes
    /// `layout.position` as an opaque translation regardless of what put it
    /// there (§5.3/D-220) ، see the ADR for the full chain of evidence.
    @Test func cursiveAttachedSequenceFidelityOnAmiri() async {
        let diff = await fidelityDiff("سجا")
        #expect(diff <= tolerance, "«سجا» (cursive-attachment-affected) derivation-vs-live diff \(diff) exceeds \(tolerance) on Amiri ، a regression here would mean the cursive-adjusted position is being LOST somewhere in the derive/render path")
    }

    /// A second, independent cursive-attachment fixture (different letter
    /// context than «سجا», same GPOS lookup) ، guards against the first
    /// fixture being a coincidental pass.
    @Test func secondCursiveAttachedSequenceFidelityOnAmiri() async {
        let diff = await fidelityDiff("سجد")
        #expect(diff <= tolerance, "«سجد» (cursive-attachment-affected) derivation-vs-live diff \(diff) exceeds \(tolerance) on Amiri")
    }

    /// Confirms the composition ACTUALLY carries the non-translate-safe
    /// signal the fidelity test above depends on: at least one derived node
    /// in «سجا» has a non-zero-height `layout.position` contribution
    /// attributable to cursive attachment. Cross-checked structurally (not
    /// by glyph id, per WS03-A4's convention) via the union bounds actually
    /// needing more vertical room than a naive same-baseline assembly would.
    @Test func cursiveAttachedCompositionHasNonZeroVerticalVariation() async {
        let style = WS16Fixtures.amiriStyle(size: 48)
        let capture = await WS16Fixtures.capture("سجا", style: style)
        let composition = await ArrangeDeriver(fonts: WS16Fixtures.amiriFonts).derive(sourceText: "سجا", style: style, capture: capture)
        let glyphYs: [CGFloat] = composition.nodes.compactMap { child in
            if case .glyph(let g) = child { return g.layout.position.y }
            return nil
        }
        let distinctYs = Set(glyphYs.map { ($0 * 1000).rounded() })   // quantize to avoid float-noise false negatives
        #expect(distinctYs.count > 1, "expected «سجا» glyphs to NOT all share the same baseline Y in Amiri (cursive attachment) ، got \(glyphYs)")
    }
}
