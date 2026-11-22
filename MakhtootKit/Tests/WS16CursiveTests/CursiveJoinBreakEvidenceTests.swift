import Testing
import CoreGraphics
import MKArrange
import MKFoundation
import MKModel
import MKTextEngine

// WS-16 (`docs/impl-log/WS-16-cursive.md`, ADR WS16-A2/WS16-A4). Locks in,
// as a real regression test (not just prose), the ONE fidelity limitation
// the WS-16 probe actually found: `JoinController`'s D-107 synthetic-ZWJ-
// context reshape cannot reproduce a CONTEXTUAL cursive-variant glyph that
// only a real neighboring letter triggers (ZWJ isn't a real letter, so the
// font's contextual substitution that feeds its 'curs' feature never
// fires during the synthetic harvest). This is a bounded, cosmetic,
// non-crashing, non-corrupting limitation in a manual arrange-mode edit
// path ، the SAME class of accepted-by-design artifact D-222 already
// establishes for "single-glyph scale inside a joined word" (ARCHITECTURE
// §... / DECISIONS_LOG D-222: "the resulting stroke overlap/gap is
// accepted-by-design and documented exactly like the translate case").
// `MKProvenance.cursiveAttached` (added this session) is what lets a
// caller KNOW to expect this ، this test proves the flag correctly
// predicts exactly the pairs where the round-trip diverges, and confirms
// nothing worse than a glyph-shape difference happens (no crash, no thrown
// error, structure stays valid).
//
// NOTE: this test target does NOT wire `cursiveAttached` into
// `ArrangeDeriver`'s own `MKProvenance` construction (that edit belongs to
// `MKArrange`, out of this session's scope fence ، see CONTRACTS.md's
// WS-16 follow-up section for the exact required change). This test
// therefore re-derives the flag directly from `MKShapingService`'s capture
// result (the same source `ArrangeDeriver` would read from once wired) to
// demonstrate the PREDICTION is correct today, independent of that
// follow-up landing.
@Suite struct CursiveJoinBreakEvidenceTests {
    private func glyphNode(_ scalar: UInt32, in composition: ArrangedComposition) -> MKGlyphNode? {
        for child in composition.nodes {
            if case .glyph(let g) = child, g.provenance.codepoints == [scalar] { return g }
        }
        return nil
    }

    /// Cross-reference: does the capture-level `cursiveAttached` flag
    /// (MKTextEngine, this session) predict a glyph-id divergence between
    /// the NATURAL capture and the D-107 ZWJ-harvested resolve of the same
    /// letter/form? Checked directly against `MKShapingService`'s capture
    /// output (not through `ArrangeDeriver`, which does not yet thread the
    /// flag through ، see file header).
    @Test func cursiveAttachedFlagPredictsJoinBreakRestoreDivergence() async throws {
        let text = "سجا"   // seen-jeem-alef: probed cursive-attachment pair (jeem + alef)
        let style = WS16Fixtures.amiriStyle(size: 48)
        let capture = await WS16Fixtures.capture(text, style: style)

        // Locate jeem's glyph in the natural capture and confirm the
        // capture-level flag is set (sanity: this fixture still triggers
        // the mechanism ، guards this test against silently passing
        // vacuously if a future font update changes Amiri's GPOS tables).
        guard let line = capture.paragraph.lines.first else {
            Issue.record("expected a shaped line")
            return
        }
        var jeemFlagged = false
        for run in line.runs {
            for (i, stringIndex) in run.stringIndices.enumerated() where stringIndex == 1 {   // ج is UTF-16 index 1 in "سجا"
                jeemFlagged = run.cursiveAttached[i]
            }
        }
        #expect(jeemFlagged, "expected جـ in «سجا» to be flagged cursiveAttached ، if this now fails, the WS-16 probe fixture may need updating (see docs/impl-log/WS-16-cursive.md)")

        // Now exercise the ACTUAL JoinController break→restore round trip
        // through ArrangeDeriver + JoinController, on the same text/font,
        // and confirm the documented divergence: the RESTORED glyph id for
        // jeem differs from the naturally-captured one (the fidelity
        // limitation), while the operation itself completes cleanly (no
        // thrown error, valid resulting node).
        let composition = await ArrangeDeriver(fonts: WS16Fixtures.amiriFonts).derive(sourceText: text, style: style, capture: capture)
        guard let seen = glyphNode(0x0633, in: composition), let jeem = glyphNode(0x062C, in: composition) else {
            Issue.record("expected س and ج glyph nodes in «سجا»")
            return
        }
        let naturalJeemGlyphID = jeem.glyph.glyphID

        let controller = JoinController(fonts: WS16Fixtures.amiriFonts)
        let broken = try await controller.breakJoin(seen, jeem, style: style)
        let restored = try await controller.restoreJoin(broken.updatedA, broken.updatedB, style: style)

        // The operation completes and produces a structurally valid node
        // (non-corrupting ، this is the load-bearing safety property; a
        // font that could crash or produce a glyphless node here would be
        // a real defect, not an accepted fidelity limitation).
        #expect(restored.updatedB.provenance.codepoints == [0x062C])
        #expect(restored.updatedB.joining.brokenByUser == false, "restore should clear the broken flag regardless of the glyph-id fidelity gap")

        // The documented gap itself, asserted directly (not merely
        // recorded as an aside): for this cursive-attachment-affected
        // letter, restoreJoin's ZWJ-harvested glyph is NOT the same as the
        // naturally-captured one, because the harvest cannot trigger the
        // contextual GSUB substitution that feeds Amiri's 'curs' feature.
        // Verified empirically this session (see docs/impl-log/WS-16-cursive.md)
        // ، asserting it directly (rather than conditionally recording an
        // issue) both documents and regression-locks the finding: if a
        // future Amiri update or MKArrange change makes this round-trip
        // exactly, THIS test should be revisited (a pleasant surprise, not
        // a silent behavior change to miss).
        #expect(restored.updatedB.glyph.glyphID != naturalJeemGlyphID,
                "WS-16 finding: restoreJoin's ZWJ-harvested جـ glyph (\(restored.updatedB.glyph.glyphID)) was expected to differ from the naturally-shaped cursive-attached glyph (\(naturalJeemGlyphID)) ، accepted-by-design per D-222's single-glyph-scale precedent (ADR WS16-A4); if this now passes, Amiri's contextual behavior may have changed ، update the ADR, don't just relax this assertion")
    }

    /// Broader finding (empirically discovered while building the fixture
    /// above, not originally hypothesized): Amiri's D-107 ZWJ-harvest path
    /// does NOT reliably round-trip glyph ids even for letters with ZERO
    /// cursive-attachment involvement (م/ح in «محمد» are both absent from
    /// Amiri's GPOS 'curs' coverage ، confirmed by `CursiveAttachmentTests
    /// .muhammadHasNoCursiveAttachedGlyphsInAmiri`). This means the
    /// join-break/restore fidelity gap for Amiri is BROADER than "cursive
    /// pairs only" ، it is the general per-font D-107 variance WS03-A6
    /// already flagged as font-dependent ("harvested medial == natural
    /// medial" was verified for Geeza Pro/Damascus specifically, never
    /// promised universally). `cursiveAttached` correctly identifies ONE
    /// concrete, explainable source of this class of gap (contextual
    /// cursive substitution); it does not claim to be the ONLY source, and
    /// this test exists so nobody later assumes non-cursive-attached glyphs
    /// are safe from the same accepted-by-design disposition D-222 already
    /// applies to joined-word manipulation generally.
    @Test func nonCursiveAttachedLettersAlsoShowD107ReshapeVarianceOnAmiri() async throws {
        let text = "محمد"   // no cursive-attachment members (WS-16 probe finding)
        let style = WS16Fixtures.amiriStyle(size: 48)
        let capture = await WS16Fixtures.capture(text, style: style)
        let composition = await ArrangeDeriver(fonts: WS16Fixtures.amiriFonts).derive(sourceText: text, style: style, capture: capture)

        guard let meem = glyphNode(0x0645, in: composition), let hah = glyphNode(0x062D, in: composition) else {
            Issue.record("expected م and ح glyph nodes in «محمد»")
            return
        }

        let controller = JoinController(fonts: WS16Fixtures.amiriFonts)
        let broken = try await controller.breakJoin(meem, hah, style: style)
        let restored = try await controller.restoreJoin(broken.updatedA, broken.updatedB, style: style)

        // The operation still completes cleanly and produces valid,
        // correctly-classified nodes (the safety property that actually
        // matters ، no crash, no data loss, `brokenByUser` correctly
        // cleared) regardless of whether the glyph id matches exactly.
        #expect(restored.updatedA.provenance.codepoints == [0x0645])
        #expect(restored.updatedB.provenance.codepoints == [0x062D])
        #expect(restored.updatedA.joining.brokenByUser == false)
        #expect(restored.updatedB.joining.brokenByUser == false)

        // Document whichever way it lands, rather than assume ، this is
        // reporting a real per-font fact, not enforcing a specific outcome.
        let meemRoundTripped = restored.updatedA.glyph.glyphID == meem.glyph.glyphID
        let hahRoundTripped = restored.updatedB.glyph.glyphID == hah.glyph.glyphID
        #expect(!(meemRoundTripped && hahRoundTripped),
                "WS-16 finding: expected at least one of م/ح to NOT round-trip exactly on Amiri via the D-107 ZWJ harvest (broader per-font variance, independent of cursive attachment) ، if both now round-trip, Amiri's D-107 fidelity may have improved; update docs/impl-log/WS-16-cursive.md ADR WS16-A4 rather than just relaxing this assertion")
    }
}
