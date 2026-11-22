import Testing
import CoreGraphics
import MKArrange
import MKFoundation
import MKModel
import MKTextEngine

/// WS-04 packet §5 tasks 6-7 (D-107, ARCHITECTURE §7.3). Runs against Geeza
/// Pro (WS03-A6: the system SF font ignores a leading ZWJ) per this
/// target's own `ArrangeFixtures` convention.
@Suite struct JoinControllerTests {
    private func glyphNode(_ scalar: UInt32, in composition: ArrangedComposition) -> MKGlyphNode? {
        for child in composition.nodes {
            if case .glyph(let g) = child, g.provenance.codepoints == [scalar] { return g }
        }
        return nil
    }

    @Test func breakingMeemHahBoundaryInMuhammadSwapsToFinalAndInitialForms() async throws {
        let text = "محمد"   // م ح م د
        let style = ArrangeFixtures.geezaStyle()
        let composition = await ArrangeFixtures.derive(text, style: style, fonts: ArrangeFixtures.geezaFonts)

        guard let meem = glyphNode(0x0645, in: composition), let hah = glyphNode(0x062D, in: composition) else {
            Issue.record("expected م and ح glyph nodes in محمد")
            return
        }
        let originalMeemPosition = meem.layout.position
        let originalHahPosition = hah.layout.position

        let controller = JoinController(fonts: ArrangeFixtures.geezaFonts)
        let result = try await controller.breakJoin(meem, hah, style: style)

        // م is WORD-INITIAL in محمد (joinsPrevious is naturally false ، no
        // letter precedes it): breaking its NEXT join (to ح) yields
        // (joinsPrevious=false, joinsNext=false) → isolated, per the §7.3
        // truth table (NOT "final" ، that would require joinsPrevious to
        // ALSO be true, which it structurally cannot be for the first
        // letter of the word).
        #expect(result.updatedA.joining.form == .isolated, "word-initial م loses its only join and becomes isolated")
        #expect(result.updatedB.joining.form == .initial, "ح loses its previous-join and becomes initial")
        #expect(result.updatedA.joining.brokenByUser)
        #expect(result.updatedB.joining.brokenByUser)
        #expect(result.updatedA.layout.position == originalMeemPosition, "no reflow: position unchanged")
        #expect(result.updatedB.layout.position == originalHahPosition, "no reflow: position unchanged")
        #expect(result.updatedA.glyph.glyphID != meem.glyph.glyphID || result.updatedA.joining.form != meem.joining.form)
    }

    @Test func breakThenRestoreRoundTrips() async throws {
        let text = "محمد"
        let style = ArrangeFixtures.geezaStyle()
        let composition = await ArrangeFixtures.derive(text, style: style, fonts: ArrangeFixtures.geezaFonts)

        guard let meem = glyphNode(0x0645, in: composition), let hah = glyphNode(0x062D, in: composition) else {
            Issue.record("expected م and ح glyph nodes")
            return
        }

        let controller = JoinController(fonts: ArrangeFixtures.geezaFonts)
        let broken = try await controller.breakJoin(meem, hah, style: style)
        let restored = try await controller.restoreJoin(broken.updatedA, broken.updatedB, style: style)

        var expectedMeem = meem
        expectedMeem.joining.brokenByUser = false
        var expectedHah = hah
        expectedHah.joining.brokenByUser = false

        #expect(restored.updatedA.glyph.glyphID == expectedMeem.glyph.glyphID)
        #expect(restored.updatedA.joining.form == expectedMeem.joining.form)
        #expect(restored.updatedA.joining.brokenByUser == false)
        #expect(restored.updatedB.glyph.glyphID == expectedHah.glyph.glyphID)
        #expect(restored.updatedB.joining.form == expectedHah.joining.form)
        #expect(restored.updatedB.joining.brokenByUser == false)
    }

    @Test func defaultFormTruthTable() {
        #expect(JoinController.defaultForm(joinsPrevious: true, joinsNext: true) == .medial)
        #expect(JoinController.defaultForm(joinsPrevious: false, joinsNext: true) == .initial)
        #expect(JoinController.defaultForm(joinsPrevious: true, joinsNext: false) == .final)
        #expect(JoinController.defaultForm(joinsPrevious: false, joinsNext: false) == .isolated)
    }

    /// WS-16 follow-up (`docs/impl-log/WS-16-cursive.md` ADR WS16-A4,
    /// `CONTRACTS.md`'s "required `MKArrange` follow-up" item 2/4). Amiri's
    /// «سجا» (WS-16 Findings 3/6) is the empirically-confirmed real-font
    /// case where the ج glyph is a member of Amiri's GPOS 'curs' coverage ،
    /// breaking the س|ج join must set `cursiveFidelityNote = true`.
    @Test func breakJoinSurfacesCursiveFidelityNoteOnAmiriSeenJeem() async throws {
        let text = "سجا"
        let style = ArrangeFixtures.amiriStyle()
        let composition = await ArrangeFixtures.derive(text, style: style, fonts: ArrangeFixtures.amiriFonts)

        guard let seen = glyphNode(0x0633, in: composition), let jeem = glyphNode(0x062C, in: composition) else {
            Issue.record("expected س and ج glyph nodes in سجا")
            return
        }
        #expect(jeem.provenance.cursiveAttached, "ج in «سجا» must carry cursiveAttached ، WS-16's own empirical finding on this exact fixture/font")

        let controller = JoinController(fonts: ArrangeFixtures.amiriFonts)
        let result = try await controller.breakJoin(seen, jeem, style: style)
        #expect(result.cursiveFidelityNote, "breaking a join touching a cursive-attached glyph must surface the fidelity note")
    }

    /// Negative control: a break with NEITHER letter cursive-attached
    /// (Geeza Pro has no GPOS 'curs' surface at all, WS03-A6/WS-16) must
    /// NOT surface the note.
    @Test func breakJoinDoesNotSurfaceCursiveFidelityNoteOnNonCursiveFont() async throws {
        let text = "محمد"
        let style = ArrangeFixtures.geezaStyle()
        let composition = await ArrangeFixtures.derive(text, style: style, fonts: ArrangeFixtures.geezaFonts)

        guard let meem = glyphNode(0x0645, in: composition), let hah = glyphNode(0x062D, in: composition) else {
            Issue.record("expected م and ح glyph nodes")
            return
        }
        #expect(!meem.provenance.cursiveAttached && !hah.provenance.cursiveAttached, "Geeza Pro has no GPOS curs table ، nothing should be flagged")

        let controller = JoinController(fonts: ArrangeFixtures.geezaFonts)
        let result = try await controller.breakJoin(meem, hah, style: style)
        #expect(!result.cursiveFidelityNote, "no cursive-attached letter is involved ، the note must not fire")
    }
}
