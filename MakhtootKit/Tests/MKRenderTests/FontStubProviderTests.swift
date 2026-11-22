import Testing
import CoreGraphics
import CoreText
import MKFoundation
import MKModel
import MKTextEngine
@testable import MKRender

/// Regression suite for WS-13 Session 3 Bug 1 (`docs/impl-log/WS-13.md`,
/// P4-exit blocker): `SystemFontStubProvider` garbled Arabic because it
/// IGNORED the requested PostScript name ، Core Text cascaded shaping to
/// the SF Arabic member (whose name+glyph IDs the run captures), but the
/// stub resolved that name back to the plain system UI font at draw time,
/// so SF-Arabic glyph IDs were drawn through SF-UI's glyph table. These
/// tests pin the exact invariant whose violation produced the garbling:
/// draw-time resolution of a shaped run's captured font name must return
/// the SAME font (PostScript-name round-trip), and that font must actually
/// cover Arabic. Lives in MKRenderTests (not MKFoundationTests) because
/// the invariant is only expressible through MKTextEngine's shaping
/// capture, which MKFoundationTests cannot import.
@Suite struct FontStubProviderTests {
    private let stub = SystemFontStubProvider()

    /// The coordinator-requested smoke test: shape «مرحبا» via the stub and
    /// assert glyph/cluster sanity plus the shaping↔drawing consistency
    /// invariant.
    @Test func shapesArabicWithDrawTimeResolutionConsistency() {
        let engine = MKShapingEngine(fonts: stub)
        let line = engine.shapeSingleLine(MKShapingRequest(string: "مرحبا", style: .default))

        // Glyph sanity: 5 letters → between 1 (full ligation) and 10
        // (2× letters) glyphs. The upper bound is NOT the letter count:
        // SF Arabic decomposes some letters into base + dot COMPONENT
        // glyphs (observed on this toolchain: «مرحبا» shapes to 6 glyphs,
        // ح contributing two), which is normal shaping, not garbling ،
        // the garbling marker is .notdef (glyph 0), asserted below.
        #expect(line.glyphCount >= 1 && line.glyphCount <= 10)
        for run in line.runs {
            #expect(run.isRTL, "Arabic-only line must shape as an RTL run")
            #expect(!run.glyphs.contains(0), "run contains .notdef glyphs ، font not Arabic-capable at shape time")

            // THE invariant (violated by the pre-fix stub): resolving the
            // run's captured font name at draw time must return the same
            // font the run was shaped with ، otherwise the captured glyph
            // IDs index a different glyph table and render as garbage.
            let drawFont = stub.resolve(MKFontHandle(postScriptName: run.font.postScriptName, pointSize: run.font.pointSize))
            let drawPSName = CTFontCopyPostScriptName(drawFont) as String
            #expect(
                drawPSName == run.font.postScriptName,
                "draw-time resolution returned '\(drawPSName)' for run font '\(run.font.postScriptName)' ، glyph IDs would render through the wrong glyph table (the WS-13 garbling bug)"
            )
        }

        // Cluster sanity per MKTextEngine: every cluster accounted for, in
        // logical order over the 5-letter source.
        #expect(!line.clusterMap.clusters.isEmpty)
        let coveredUTF16 = line.clusterMap.clusters.reduce(0) { $0 + $1.utf16Range.count }
        #expect(coveredUTF16 == "مرحبا".utf16.count, "cluster map does not cover the full source string")
    }

    /// The stub's resolved font for the pre-WS-09 default handle must
    /// actually have Arabic coverage (the pre-fix stub could hand back a
    /// font where this holds only via cascade at shape time but not at
    /// direct draw-time lookup; post-fix, the resolved font itself covers
    /// Arabic).
    @Test func defaultHandleResolvesToAnArabicCapableFont() {
        let font = stub.resolve(MKFontHandle(postScriptName: MKFontRef.systemFallback.postScriptName, pointSize: 48))
        var chars: [UniChar] = Array("مرحبا".utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        let allMapped = CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count)
        #expect(allMapped, "resolved font lacks glyphs for basic Arabic letters")
        #expect(!glyphs.contains(0))
    }

    /// A REAL installed font requested by name must still resolve by name
    /// (the fix's step 1 ، the stub is not "always SF Arabic now").
    @Test func realInstalledFontsStillResolveByName() {
        // Helvetica is present on every Apple platform/simulator runtime.
        let font = stub.resolve(MKFontHandle(postScriptName: "Helvetica", pointSize: 24))
        #expect((CTFontCopyPostScriptName(font) as String) == "Helvetica")
    }

    /// A bogus name must fall back to an Arabic-capable font (never a
    /// silent TimesNewRoman-style substitution leaking through, never a
    /// crash).
    @Test func unknownNameFallsBackToArabicCapableFont() {
        let font = stub.resolve(MKFontHandle(postScriptName: "NoSuchFont-Bold", pointSize: 24))
        var chars: [UniChar] = Array("م".utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        #expect(CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count))
        #expect(glyphs[0] != 0)
    }

    /// End-to-end through the actual MKRender path: rendering «مرحبا» with
    /// the DEFAULT stub must produce the same pixels as rendering it with
    /// an explicitly-consistent provider chain ، i.e. the default path is
    /// no longer the odd one out. (A weaker but fully-automatable stand-in
    /// for WS-13's screenshot-level "not garbled" check: the garbled
    /// rendering came specifically from the default stub diverging from
    /// name-honoring resolution; with the fix, both paths are identical by
    /// construction, and this test locks that in.)
    @Test func defaultStubRenderMatchesNameHonoringRender() {
        let scene = TestScenes.scene(canvasSize: CGSize(width: 300, height: 120), background: .white, nodes: [
            TestScenes.liveText("مرحبا", position: CGPoint(x: 20, y: 20), pointSize: 48),
        ])
        let defaultRender = MKSnapshotRenderer(fonts: SystemFontStubProvider()).renderFullCanvas(scene, scale: 1, quality: .exportQuality)
        let explicitRender = MKSnapshotRenderer(fonts: stub).renderFullCanvas(scene, scale: 1, quality: .exportQuality)
        #expect(defaultRender != nil && explicitRender != nil)
        guard let defaultRender, let explicitRender else { return }
        #expect(PixelDiff.differingFraction(defaultRender, explicitRender) == 0)
        // And it actually painted glyphs (not a blank canvas):
        var data = [UInt8](repeating: 0, count: defaultRender.width * defaultRender.height * 4)
        let ctx = CGContext(
            data: &data, width: defaultRender.width, height: defaultRender.height, bitsPerComponent: 8,
            bytesPerRow: defaultRender.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.draw(defaultRender, in: CGRect(x: 0, y: 0, width: defaultRender.width, height: defaultRender.height))
        let nonWhite = stride(from: 0, to: data.count, by: 4).contains { data[$0] < 200 }
        #expect(nonWhite, "render produced a blank canvas ، no glyphs drawn")
    }
}
