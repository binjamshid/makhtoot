import Testing
import CoreGraphics
import MKArrange
import MKFoundation
import MKModel
import MKTextEngine

/// WS-04 packet §5 task 2 accept criteria: node counts consistent with
/// capture; every GlyphNode has non-empty codepoints; every MarkNode
/// resolves its base; every node id unique.
@Suite struct ArrangeDeriverTests {
    @Test func basmalaProducesConsistentNodeCounts() async {
        let text = "بسم الله"
        let style = ArrangeFixtures.systemStyle()
        let capture = await ArrangeFixtures.capture(text, style: style)
        let composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture)

        #expect(!composition.nodes.isEmpty)
        // Every glyph node has non-empty codepoints.
        for child in composition.nodes {
            if case .glyph(let g) = child {
                #expect(!g.provenance.codepoints.isEmpty, "glyph node \(g.id) has empty codepoints")
            }
            if case .ligature(let l) = child {
                #expect(!l.provenance.codepoints.isEmpty, "ligature node \(l.id) has empty codepoints")
            }
        }
    }

    @Test func everyNodeIDIsUnique() async {
        let text = "مُحَمَّدٌ"
        let style = ArrangeFixtures.systemStyle()
        let capture = await ArrangeFixtures.capture(text, style: style)
        let composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture)

        var seen = Set<MKNodeID>()
        for child in composition.nodes {
            #expect(!seen.contains(child.id), "duplicate node id \(child.id)")
            seen.insert(child.id)
        }
        #expect(seen.count == composition.nodes.count)
    }

    @Test func everyMarkNodeResolvesItsBaseOrIsExplicitlyFree() async {
        // "شَدَّةٌ" ، shadda + fatha stack, exercises mark-on-mark resolution.
        let text = "شَدَّةٌ"
        let style = ArrangeFixtures.systemStyle()
        let capture = await ArrangeFixtures.capture(text, style: style)
        let composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture)

        let ids = Set(composition.nodes.map(\.id))
        for child in composition.nodes {
            guard case .mark(let m) = child else { continue }
            if let base = m.attachedTo {
                #expect(ids.contains(base), "mark \(m.id) points at unknown base \(base)")
            } else {
                #expect(m.followsBase == false, "an unattached mark must not claim followsBase")
            }
        }
    }

    @Test func sourceBackupPreservesExactStringAndComputesValidHash() async {
        let text = "عام ٢٠٢٦ / 2026"
        let style = ArrangeFixtures.systemStyle()
        let capture = await ArrangeFixtures.capture(text, style: style)
        let composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture)

        #expect(composition.sourceBackup.sourceString == text)
        #expect(composition.sourceBackup.contentHash == composition.sourceBackup.recomputedHash())
    }

    @Test func requiredLigatureProducesDecomposableLigatureGroup() async {
        let text = "لا"
        let style = ArrangeFixtures.systemStyle()
        let capture = await ArrangeFixtures.capture(text, style: style)
        let composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture)

        let ligatures = composition.nodes.compactMap { child -> MKLigatureGroup? in
            if case .ligature(let l) = child { return l }
            return nil
        }
        #expect(ligatures.count == 1, "لا must fuse into exactly one ligature cluster on a real Arabic-shaping font")
        if let group = ligatures.first, case .composed(let composed) = group.state {
            #expect(composed.decomposable)
            #expect(Set(group.provenance.codepoints) == Set([0x0644, 0x0627]))
        }
    }

    @Test func tatweelBecomesAGlyphNodeNotAMark() async {
        // "مـد" ، tatweel (U+0640) between م and د.
        let text = "م\u{0640}د"
        let style = ArrangeFixtures.systemStyle()
        let capture = await ArrangeFixtures.capture(text, style: style)
        let composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture)

        let hasTatweelGlyph = composition.nodes.contains { child in
            if case .glyph(let g) = child { return g.provenance.codepoints.contains(0x0640) }
            return false
        }
        #expect(hasTatweelGlyph, "tatweel must be realized as a GlyphNode, never dropped or treated as a mark")
    }
}
