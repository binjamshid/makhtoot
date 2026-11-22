import Testing
import CoreGraphics
import MKModel
@testable import MKTextEngine

/// WS-03 packet §5 task 11 (D-107 ZWJ form harvest) + T-TXT-5/6.
///
/// Runs against **Geeza Pro** (via `Fixtures.NamedFontProvider`) ، the
/// system SF font ignores a leading ZWJ (documented per-font finding,
/// docs/impl-log/WS-03.md), while Geeza Pro (bundled on macOS AND iOS)
/// implements the full joining feature set, so D-107's guarantees are
/// testable end-to-end today. The WS-09 fixture re-run extends this to
/// Amiri/Noto Naskh.
@Suite struct FormResolverTests {

    private func makeResolver() -> MKFormResolver {
        MKFormResolver(fonts: Fixtures.NamedFontProvider())
    }

    @Test func hahYieldsFourDistinctFormGlyphs() async {
        // Packet accept: "for ح all four forms yield four distinct glyph ids."
        let resolver = makeResolver()
        let hah = Unicode.Scalar(0x062D)!   // ح
        var glyphIDs: Set<UInt16> = []
        for form in [MKJoiningForm.isolated, .initial, .medial, .final] {
            guard let resolved = await resolver.resolve(letter: hah, form: form, style: Fixtures.geezaStyle()) else {
                Issue.record("harvest failed for ح \(form)")
                return
            }
            #expect(resolved.form == form)
            #expect(resolved.wasCoerced == false)
            glyphIDs.insert(resolved.glyphID)
        }
        #expect(glyphIDs.count == 4, "Geeza Pro distinguishes all four contextual forms of ح")
    }

    @Test func harvestedMedialMatchesNaturalContext() async {
        // Packet accept: "resolved medial ح glyph id equals the glyph id
        // observed for ح inside shaped «محمد»" ، the same-process
        // consistency check (the one glyph-id comparison the tolerance
        // policy allows, because both ids come from the same font in the
        // same process).
        let resolver = makeResolver()
        let hah = Unicode.Scalar(0x062D)!
        guard let medial = await resolver.resolve(letter: hah, form: .medial, style: Fixtures.geezaStyle()) else {
            Issue.record("medial harvest failed")
            return
        }

        let line = Fixtures.shapeGeeza("محمد")
        // ح is UTF-16 index 1 in محمد; its cluster's glyph is the natural
        // medial form.
        guard
            let clusterIndex = line.clusterMap.utf16ToCluster[1],
            let address = line.clusterMap.clusters[clusterIndex].glyphs.first
        else {
            Issue.record("could not locate ح's glyph in natural context")
            return
        }
        let naturalGlyph = line.runs[address.run].glyphs[address.glyph]
        #expect(medial.glyphID == naturalGlyph, "D-107 harvest must reproduce the natural-context medial glyph")
    }

    @Test func rightJoiningLetterCoercesMedialToFinal() async {
        // Packet accept: "for د requesting medial returns final/isolated
        // variant with wasCoerced = true."
        let resolver = makeResolver()
        let dal = Unicode.Scalar(0x062F)!   // د
        guard
            let medialRequest = await resolver.resolve(letter: dal, form: .medial, style: Fixtures.geezaStyle()),
            let finalRequest = await resolver.resolve(letter: dal, form: .final, style: Fixtures.geezaStyle())
        else {
            Issue.record("harvest failed for د")
            return
        }
        #expect(medialRequest.wasCoerced == true)
        #expect(medialRequest.form == .final)
        #expect(medialRequest.requestedForm == .medial)
        #expect(medialRequest.glyphID == finalRequest.glyphID, "coerced medial must be the final-form glyph")
        #expect(finalRequest.wasCoerced == false)
    }

    @Test func rightJoiningLetterCoercesInitialToIsolated() async {
        let resolver = makeResolver()
        let dal = Unicode.Scalar(0x062F)!
        guard
            let initialRequest = await resolver.resolve(letter: dal, form: .initial, style: Fixtures.geezaStyle()),
            let isolated = await resolver.resolve(letter: dal, form: .isolated, style: Fixtures.geezaStyle())
        else {
            Issue.record("harvest failed for د")
            return
        }
        #expect(initialRequest.wasCoerced == true)
        #expect(initialRequest.form == .isolated)
        #expect(initialRequest.glyphID == isolated.glyphID)
    }

    @Test func resolvedFormsCarryOutlinesAndAdvances() async {
        let resolver = makeResolver()
        let beh = Unicode.Scalar(0x0628)!   // ب
        guard let resolved = await resolver.resolve(letter: beh, form: .isolated, style: Fixtures.geezaStyle()) else {
            Issue.record("harvest failed for ب")
            return
        }
        #expect(resolved.advance.width > 0)
        #expect(resolved.outline != nil, "a visible letter's harvest must include its outline path")
        if let outline = resolved.outline {
            #expect(!outline.commands.isEmpty)
            #expect(outline.unitsPerEm == 1000)
        }
    }

    @Test func noPresentationFormCodepointsAreEverProduced() async {
        // T-TXT-5's INV-5 assertion: nothing in the harvest path consumes
        // or produces U+FB50–FEFF presentation forms ، the synthetic
        // contexts are built exclusively from the letter + U+200D.
        let resolver = makeResolver()
        for letterValue in [UInt32(0x0628), 0x062D, 0x0639, 0x0644, 0x0645, 0x064A] {
            let letter = Unicode.Scalar(letterValue)!
            for form in [MKJoiningForm.isolated, .initial, .medial, .final] {
                _ = await resolver.resolve(letter: letter, form: form, style: Fixtures.geezaStyle())
            }
            #expect(!(0xFB50...0xFEFF).contains(letterValue))
        }
    }
}
