import Testing
import CoreGraphics
import MKArrange
import MKFoundation
import MKModel
import MKTextEngine

/// WS-04 packet §5 task 16.
@Suite struct MultiLineBidiTests {
    @Test func mixedLatinArabicFixtureAssignsBidiLevelsAndDistinctLineOrigins() async {
        let text = "التصميم Design\nعام ٢٠٢٦ ، 2026"
        let style = ArrangeFixtures.systemStyle(size: 24)
        let capture = await ArrangeFixtures.captureWrapped(text, width: 460, style: style)
        #expect(capture.paragraph.lines.count == 2, "the hard newline must produce two shaped lines")

        let composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture)
        #expect(!composition.nodes.isEmpty)

        // `layout.position` bakes in each line's own origin offset ، "one
        // child group per line" is satisfied STRUCTURALLY (README.md's
        // documented deviation: no explicit grouping node exists in
        // `MKArrangedChild`'s closed D-111 set) rather than via a nested
        // group. Verify the two lines really do occupy distinct vertical
        // bands: the y-spread across all glyph positions should exceed
        // half a line height (28.8pt at this fixture's size/lineHeight),
        // which a single-line derivation could never produce.
        var glyphYPositions: [CGFloat] = []
        for child in composition.nodes {
            if case .glyph(let g) = child { glyphYPositions.append(g.layout.position.y) }
        }
        #expect(glyphYPositions.count > 1)
        if let minY = glyphYPositions.min(), let maxY = glyphYPositions.max() {
            let lineHeight = CGFloat(style.lineHeightMultiple * style.pointSize)
            #expect(maxY - minY >= lineHeight * 0.5, "glyphs across two lines must span a meaningful vertical range (spread=\(maxY - minY), lineHeight=\(lineHeight))")
        }

        // Latin run nodes carry even bidiLevel, Arabic odd (D-109).
        var sawEvenLatin = false
        var sawOddArabic = false
        for child in composition.nodes {
            let provenance: MKProvenance
            switch child {
            case .glyph(let g): provenance = g.provenance
            case .mark(let m): provenance = m.provenance
            case .ligature(let l): provenance = l.provenance
            }
            guard let scalar = provenance.codepoints.first.flatMap(Unicode.Scalar.init) else { continue }
            if scalar.value < 0x0250 {   // ASCII/Latin range in this fixture
                if provenance.bidiLevel % 2 == 0 { sawEvenLatin = true }
            } else if (0x0600...0x06FF).contains(scalar.value) {
                if provenance.bidiLevel % 2 == 1 { sawOddArabic = true }
            }
        }
        #expect(sawEvenLatin, "expected at least one Latin sub-run node with an even bidiLevel")
        #expect(sawOddArabic, "expected at least one Arabic sub-run node with an odd bidiLevel")
    }
}
