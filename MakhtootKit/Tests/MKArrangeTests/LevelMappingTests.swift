import Testing
import MKArrange
import MKFoundation
import MKModel

/// WS-04 packet §5 task 5 accept criteria.
@Suite struct LevelMappingTests {
    @Test func ligatureNodeMapsBothDirectionsToItsCodepoints() async {
        let text = "لا"
        let style = ArrangeFixtures.systemStyle()
        let composition = await ArrangeFixtures.derive(text, style: style)

        guard let ligature = composition.nodes.compactMap({ child -> MKLigatureGroup? in
            if case .ligature(let l) = child { return l }
            return nil
        }).first else {
            Issue.record("expected لا to derive a ligature group")
            return
        }

        let range = ligature.provenance.utf16Start..<(ligature.provenance.utf16Start + ligature.provenance.utf16Length)
        let nodeIDs = LevelMapping.nodeIDs(forUTF16Range: range, in: composition)
        #expect(nodeIDs == [ligature.id], "selecting the full ligature codepoint range must map back to just the ligature node")

        let ranges = LevelMapping.utf16Ranges(forNodeIDs: [ligature.id], in: composition)
        #expect(ranges == [range], "selecting the ligature node must map back to its exact codepoint range")
    }

    @Test func selectingBaseLetterIncludesMarkOnlyWhenToggled() async {
        // "بَ" ، beh + fatha.
        let text = "بَ"
        let style = ArrangeFixtures.systemStyle()
        let composition = await ArrangeFixtures.derive(text, style: style)

        guard case .glyph(let base)? = composition.nodes.first(where: {
            if case .glyph(let g) = $0 { return g.provenance.codepoints.contains(0x0628) }
            return false
        }) else {
            Issue.record("expected a beh glyph node")
            return
        }
        let baseRange = base.provenance.utf16Start..<(base.provenance.utf16Start + base.provenance.utf16Length)

        let withoutMarks = LevelMapping.nodeIDs(forUTF16Range: baseRange, in: composition, includeMarks: false)
        #expect(withoutMarks == [base.id], "selecting just the base letter's own span must not include the mark unless requested")

        let withMarks = LevelMapping.nodeIDs(forUTF16Range: baseRange, in: composition, includeMarks: true)
        #expect(withMarks.contains(base.id))
        #expect(withMarks.count == 2, "includeMarks must pull in the fatha attached to the selected base")
    }
}
