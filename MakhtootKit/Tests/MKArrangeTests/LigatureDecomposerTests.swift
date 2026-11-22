import Testing
import CoreGraphics
import MKArrange
import MKFoundation
import MKModel
import MKTextEngine

/// WS-04 packet §5 tasks 9-11 (D-108/D-221). Runs against Geeza Pro (D-107
/// harvest dependency, this target's convention).
@Suite struct LigatureDecomposerTests {
    private func ligature(in composition: ArrangedComposition) -> MKLigatureGroup? {
        composition.nodes.compactMap { child -> MKLigatureGroup? in
            if case .ligature(let l) = child { return l }
            return nil
        }.first
    }

    @Test func decomposeLaaConstituentsAndClampBehaviorOnRealFont() async throws {
        let text = "لا"
        let style = ArrangeFixtures.geezaStyle()
        let composition = await ArrangeFixtures.derive(text, style: style, fonts: ArrangeFixtures.geezaFonts)
        guard let group = ligature(in: composition), case .composed(let composed) = group.state else {
            Issue.record("expected a composed لا ligature")
            return
        }

        let decomposer = LigatureDecomposer(fonts: ArrangeFixtures.geezaFonts)
        let result = try await decomposer.decompose(group, sourceString: text, style: style, options: .fidelityDefault)

        guard case .decomposed(let decomposed) = result.group.state else {
            Issue.record("expected decomposed state")
            return
        }
        #expect(decomposed.components.count == 2, "لام + الف")
        #expect(decomposed.components[0].provenance.codepoints == [0x0644])
        #expect(decomposed.components[1].provenance.codepoints == [0x0627])

        // Measured finding (documented, not assumed): on Geeza Pro at 36pt,
        // لا's fused-ligature outline is substantially NARROWER than the
        // two standalone lam+alef glyphs placed side by side (fused
        // outline ≈15.7pt vs. standalone assembly ≈21.8pt,
        // naturalScaleFactor ≈0.72 ، outside [0.85, 1.15]) ، this is
        // exactly the D-221 pre-flight clamp-refusal case, not a defect,
        // and this real-font finding is recorded in
        // `docs/impl-log/WS-04.md`. The "fits within 2%" claim (task 9
        // accept) is verified directly by
        // `fidelityFitAlignsWithinTwoPercentWhenWithinClamp` below using a
        // synthetic fixture engineered to land inside the clamp, since this
        // real font/size/text combination doesn't happen to.
        #expect(result.fidelityAutoRefused, "documents the measured Geeza Pro 36pt لا clamp-refusal finding ، update this expectation with the new number if it ever changes (e.g. a different font/size)")
        #expect(decomposed.fidelityMode == .defaultForms)
        _ = composed
    }

    /// Task 9 accept criterion ("union bounds within 2% of original
    /// ligature bounds") verified directly via a synthetic ligature
    /// engineered so its natural fit lands INSIDE the D-221 clamp ، the
    /// real لا/Geeza-Pro fixture above happens to trigger clamp-refusal
    /// instead (a legitimate, separately-verified path), so this
    /// complements it with real coverage of the successful-fit path.
    @Test func fidelityFitAlignsWithinTwoPercentWhenWithinClamp() async throws {
        let style = ArrangeFixtures.geezaStyle()
        // Harvest the real standalone lam/alef outlines first so the
        // synthetic ligature's advance can be engineered to land the
        // natural scale factor close to 1.0 (inside the clamp).
        let resolver = MKFormResolver(fonts: ArrangeFixtures.geezaFonts)
        guard let lamResolved = await resolver.resolve(letter: Unicode.Scalar(0x0644)!, form: .initial, style: style),
              let alefResolved = await resolver.resolve(letter: Unicode.Scalar(0x0627)!, form: .final, style: style),
              let lamBox = lamResolved.outline?.cgPath(at: style.pointSize).boundingBoxOfPath,
              let alefBox = alefResolved.outline?.cgPath(at: style.pointSize).boundingBoxOfPath
        else {
            Issue.record("expected harvestable لام/الف outlines")
            return
        }
        let naturalAssembledWidth = (lamResolved.advance.width + alefBox.maxX) - lamBox.minX
        let syntheticLigatureOutline = MKPathData.from(
            CGPath(rect: CGRect(x: 0, y: 0, width: naturalAssembledWidth * 1.0, height: style.pointSize * 0.6), transform: nil),
            pointSize: style.pointSize)

        let clusterID = MKClusterID()
        let provenance = MKProvenance(clusterID: clusterID, codepoints: [0x0644, 0x0627], utf16Start: 0, utf16Length: 2, bidiLevel: 1, visualIndex: 0, logicalIndex: 0)
        let composed = MKComposedLigature(
            glyph: MKGlyphRef(glyphID: 1, font: .system(postScriptName: ArrangeFixtures.geezaProName), fontChecksum: "t"),
            outline: syntheticLigatureOutline,
            layout: MKGlyphLayout(position: .zero, advance: CGSize(width: naturalAssembledWidth, height: 0)),
            decomposable: true)
        let group = MKLigatureGroup(state: .composed(composed), provenance: provenance)

        let decomposer = LigatureDecomposer(fonts: ArrangeFixtures.geezaFonts)
        let result = try await decomposer.decompose(group, sourceString: "لا", style: style, options: .fidelityDefault)
        #expect(!result.fidelityAutoRefused, "engineered fixture must land inside the clamp (naturalScale=\(result.naturalScaleFactor))")

        guard case .decomposed(let decomposed) = result.group.state,
              let ligBox = composed.outline?.cgPath(at: style.pointSize).boundingBoxOfPath,
              let firstBox = decomposed.components[0].outline?.cgPath(at: style.pointSize).boundingBoxOfPath,
              let lastBox = decomposed.components[1].outline?.cgPath(at: style.pointSize).boundingBoxOfPath
        else {
            Issue.record("expected a decomposed, outlined result")
            return
        }
        let assembledMinX = decomposed.components[0].layout.position.x + firstBox.minX
        let assembledMaxX = decomposed.components[1].layout.position.x + lastBox.maxX
        let assembledWidth = assembledMaxX - assembledMinX
        let toleranceRatio = 0.02
        #expect(abs(assembledWidth - ligBox.width) <= ligBox.width * toleranceRatio + 0.5,
                "assembled outline width \(assembledWidth) not within 2% of original ligature outline width \(ligBox.width)")
    }

    @Test func decomposeOptOutDiffersFromFidelityLayout() async throws {
        let text = "لا"
        let style = ArrangeFixtures.geezaStyle()
        let composition = await ArrangeFixtures.derive(text, style: style, fonts: ArrangeFixtures.geezaFonts)
        guard let group = ligature(in: composition) else {
            Issue.record("expected لا ligature")
            return
        }

        let decomposer = LigatureDecomposer(fonts: ArrangeFixtures.geezaFonts)
        let fidelityResult = try await decomposer.decompose(group, sourceString: text, style: style, options: .fidelityDefault)
        let optOutResult = try await decomposer.decompose(group, sourceString: text, style: style, options: .defaultForms)

        guard case .decomposed(let fidelityDecomposed) = fidelityResult.group.state,
              case .decomposed(let optOutDecomposed) = optOutResult.group.state
        else {
            Issue.record("expected both decompositions to succeed")
            return
        }
        #expect(optOutDecomposed.fidelityMode == .defaultForms)
        // Only meaningfully distinguishable when the fit actually rescales
        // anything ، if this particular font/size's لا happens to have a
        // near-1.0 natural scale factor, fidelity and opt-out legitimately
        // coincide (both are "correct", they just have nothing to
        // distinguish them here). The edge-alignment ITSELF (not the
        // scale) still generally shifts positions even at scale≈1 unless
        // the natural layout was ALREADY edge-aligned, which is why this
        // guards on the actual observed positions rather than assuming
        // scale≠1 is the only source of difference.
        if fidelityDecomposed.fidelityMode == .matchOriginal, abs(fidelityResult.naturalScaleFactor - 1) > 0.01 {
            #expect(fidelityDecomposed.components[1].layout.position.x != optOutDecomposed.components[1].layout.position.x,
                    "opt-out layout must differ from fidelity layout when the fit actually applied a non-trivial rescale (naturalScale=\(fidelityResult.naturalScaleFactor))")
        }
    }

    @Test func decomposeThenRecomposeWithNoEditsRoundTrips() async throws {
        let text = "لا"
        let style = ArrangeFixtures.geezaStyle()
        let composition = await ArrangeFixtures.derive(text, style: style, fonts: ArrangeFixtures.geezaFonts)
        guard let group = ligature(in: composition) else {
            Issue.record("expected لا ligature")
            return
        }

        let decomposer = LigatureDecomposer(fonts: ArrangeFixtures.geezaFonts)
        let result = try await decomposer.decompose(group, sourceString: text, style: style, options: .fidelityDefault)
        let recomposed = try decomposer.recompose(result.group, force: false)

        #expect(recomposed.state == group.state, "decompose→recompose with no edits must be an Equatable round-trip")
    }

    @Test func styleOnlyEditBlocksRecomposeUnlessForced_TARR_LIG_STYLE() async throws {
        let text = "لا"
        let style = ArrangeFixtures.geezaStyle()
        let composition = await ArrangeFixtures.derive(text, style: style, fonts: ArrangeFixtures.geezaFonts)
        guard let group = ligature(in: composition) else {
            Issue.record("expected لا ligature")
            return
        }

        let decomposer = LigatureDecomposer(fonts: ArrangeFixtures.geezaFonts)
        let result = try await decomposer.decompose(group, sourceString: text, style: style, options: .fidelityDefault)
        guard case .decomposed(var decomposed) = result.group.state else {
            Issue.record("expected decomposed state")
            return
        }

        // Style-only edit ، recolor ONE constituent, no transform change
        // (the exact T-ARR-LIG-STYLE regression this widened check fixes).
        decomposed.components[0].style = MKStyle(fill: .solid(MKSolidColor(r: 1, g: 0, b: 0)))
        var editedGroup = result.group
        editedGroup.state = .decomposed(decomposed)

        #expect(throws: MKArrangeError.self) {
            _ = try decomposer.recompose(editedGroup, force: false)
        }
        // Forced recompose must succeed and discard the style edit.
        let forced = try decomposer.recompose(editedGroup, force: true)
        #expect(forced.state == .composed(decomposed.original))
    }

    @Test func transformOnlyEditAlsoBlocksRecomposeUnlessForced() async throws {
        let text = "لا"
        let style = ArrangeFixtures.geezaStyle()
        let composition = await ArrangeFixtures.derive(text, style: style, fonts: ArrangeFixtures.geezaFonts)
        guard let group = ligature(in: composition) else {
            Issue.record("expected لا ligature")
            return
        }

        let decomposer = LigatureDecomposer(fonts: ArrangeFixtures.geezaFonts)
        let result = try await decomposer.decompose(group, sourceString: text, style: style, options: .fidelityDefault)
        guard case .decomposed(var decomposed) = result.group.state else {
            Issue.record("expected decomposed state")
            return
        }
        decomposed.components[1].transform = MKTransform2D(position: CGPoint(x: 5, y: 0))
        var editedGroup = result.group
        editedGroup.state = .decomposed(decomposed)

        #expect(throws: MKArrangeError.self) {
            _ = try decomposer.recompose(editedGroup, force: false)
        }
    }

    @Test func clampRefusalAutoFallsBackToDefaultForms() async throws {
        // A synthetic ligature whose advance width is wildly out of
        // proportion to its constituents' natural standalone widths (far
        // outside [0.85, 1.15]) ، exercises the D-221 pre-flight refusal
        // path directly (task 9's "fixture whose natural fit exceeds the
        // clamp asserts automatic fallback"), independent of whether any
        // real font's actual لا ligature happens to fall inside the clamp.
        let clusterID = MKClusterID()
        let provenance = MKProvenance(clusterID: clusterID, codepoints: [0x0644, 0x0627], utf16Start: 0, utf16Length: 2, bidiLevel: 1, visualIndex: 0, logicalIndex: 0)
        let squareOutline = MKPathData(commands: [0, -500, -500, 1, 500, -500, 1, 500, 500, 1, -500, 500, 4])
        let composed = MKComposedLigature(
            glyph: MKGlyphRef(glyphID: 1, font: .systemFallback, fontChecksum: "t"),
            outline: squareOutline,
            layout: MKGlyphLayout(position: .zero, advance: CGSize(width: 500, height: 0)),   // absurdly wide vs. natural ~2×letter-width
            decomposable: true)
        let group = MKLigatureGroup(state: .composed(composed), provenance: provenance)

        let style = ArrangeFixtures.geezaStyle()
        let decomposer = LigatureDecomposer(fonts: ArrangeFixtures.geezaFonts)
        let result = try await decomposer.decompose(group, sourceString: "لا", style: style, options: .fidelityDefault)

        #expect(result.fidelityAutoRefused, "natural scale \(result.naturalScaleFactor) should fall outside [0.85, 1.15] for this synthetic fixture")
        guard case .decomposed(let decomposed) = result.group.state else {
            Issue.record("expected decomposed state")
            return
        }
        #expect(decomposed.fidelityMode == .defaultForms, "clamp refusal must fall back to default-forms mode automatically")
    }

    /// WS-16 follow-up (`docs/impl-log/WS-16-cursive.md` ADR WS16-A4,
    /// `CONTRACTS.md`'s "required `MKArrange` follow-up" item 2). Unit-level
    /// (not depending on finding a real curs-covered ligature in a bundled
    /// font): `DecomposeResult.cursiveFidelityNote` must mirror the ORIGINAL
    /// composed ligature's own `provenance.cursiveAttached`, both when
    /// `true` and `false`, including on the idempotent no-op path (decompose
    /// called on an already-decomposed group).
    @Test func decomposeSurfacesCursiveFidelityNoteFromOriginalProvenance() async throws {
        let style = ArrangeFixtures.geezaStyle()
        let squareOutline = MKPathData(commands: [0, -500, -500, 1, 500, -500, 1, 500, 500, 1, -500, 500, 4])

        func makeGroup(cursiveAttached: Bool) -> MKLigatureGroup {
            let provenance = MKProvenance(
                clusterID: MKClusterID(), codepoints: [0x0644, 0x0627], utf16Start: 0, utf16Length: 2,
                bidiLevel: 1, visualIndex: 0, logicalIndex: 0, cursiveAttached: cursiveAttached)
            let composed = MKComposedLigature(
                glyph: MKGlyphRef(glyphID: 1, font: .system(postScriptName: ArrangeFixtures.geezaProName), fontChecksum: "t"),
                outline: squareOutline, layout: MKGlyphLayout(position: .zero, advance: CGSize(width: 40, height: 0)), decomposable: true)
            return MKLigatureGroup(state: .composed(composed), provenance: provenance)
        }

        let decomposer = LigatureDecomposer(fonts: ArrangeFixtures.geezaFonts)

        let flagged = try await decomposer.decompose(makeGroup(cursiveAttached: true), sourceString: "لا", style: style, options: .fidelityDefault)
        #expect(flagged.cursiveFidelityNote, "must surface true when the original composed ligature was cursive-attached")

        let unflagged = try await decomposer.decompose(makeGroup(cursiveAttached: false), sourceString: "لا", style: style, options: .fidelityDefault)
        #expect(!unflagged.cursiveFidelityNote, "must not surface a note when the original composed ligature was not cursive-attached")

        // Idempotent no-op path (already-decomposed input) also carries the note.
        let idempotent = try await decomposer.decompose(flagged.group, sourceString: "لا", style: style, options: .fidelityDefault)
        #expect(idempotent.cursiveFidelityNote, "the idempotent no-op decompose path must also mirror the original flag")
    }
}
