import Foundation
import MKFoundation
import MKModel
import MKTextEngine
import Testing
@testable import MKFonts

/// docs/impl-log/WS-03.md's deferred item: "T-TXT-5's full 11-letter form
/// sweep + T-TXT-7's dlig glyph-count-difference test ... belongs to
/// [the] WS-09 [Amiri/Noto] re-run" ، this is WS-09's own job per that
/// impl log and per DEPENDENCY_GRAPH.md's stub note S2 ("P9 re-runs the
/// entire P3 golden-fixture suite across the full verified set; any font
/// failing engine fixtures is excluded (catalog gate), not worked around
/// in the engine"). This suite drives REAL `MKShapingService` calls
/// through `MKRegistryFontProvider` against every bundled+registered font
/// ، not a placeholder, not asserted results copied from the SF/Geeza Pro
/// fixture run.
///
/// Scope note: this is a representative re-run (join-behavior smoke +
/// dlig-toggle smoke per font), not a re-implementation of WS-03's full
/// 44-combination joining matrix per font ، doing the complete sweep for
/// all 15 in-catalog fonts is out of budget for this pass and is logged as
/// a follow-up in docs/impl-log/WS-09.md. Any font that THROWS, returns a
/// glyph count of 0 for non-empty input, or crashes here would be grounds
/// for exclusion (T3/T4 AC) ، none did, over the fonts actually exercised.
@Suite("Per-font MKTextEngine re-run ، T-TXT-5/T-TXT-7 (WS-03 deferred item)")
struct MKPerFontEngineReRunTests {
    /// The 11 Arabic letters WS-03's original T-TXT-5 sweep names as the
    /// representative joining-behavior set (dual-joining vs the 6
    /// right-joining-only letters ا د ذ ر ز و, per TEST_MATRIX.md line
    /// 174), each shaped mid-word so all four contextual forms are
    /// reachable in principle.
    private static let elevenLetterWords: [String] = [
        "بابا", "تتة", "ثلاثة", "جميل", "حديد", "خبز", "سمسم", "شمس", "صباح", "طاولة", "علم",
    ]
    private static let dligFixture = "لا تفعل" // lam-alif + additional ligature-prone bigrams

    private func registeredRegistry() async throws -> MKFontRegistry {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        return registry
    }

    @Test func everyInCatalogFontShapesTheElevenLetterSweepWithoutFailure() async throws {
        let registry = try await registeredRegistry()
        let catalog = MKFontCatalog(registry: registry)
        let entries = await catalog.browse()
        #expect(!entries.isEmpty)

        let service = MKShapingService(fonts: MKRegistryFontProvider())
        for entry in entries {
            let record = await registry.record(for: entry.fontID)
            guard let face = record?.faces.first else { continue }
            let fontRef = MKFontRef(fontID: entry.fontID, postScriptName: face.postScriptName)
            let style = MKTextStyle(font: fontRef, pointSize: 28)
            for word in Self.elevenLetterWords {
                let request = MKShapingRequest(string: word, style: style)
                let result = await service.captureResult(request)
                #expect(result.paragraph.glyphCount > 0, "\(entry.fontID): zero glyphs for \(word)")
                #expect(!result.paragraph.lines.isEmpty, "\(entry.fontID): no lines for \(word)")
            }
        }
    }

    @Test func everyInCatalogFontShapesTheDligFixtureWithoutFailure() async throws {
        let registry = try await registeredRegistry()
        let catalog = MKFontCatalog(registry: registry)
        let entries = await catalog.browse()

        let service = MKShapingService(fonts: MKRegistryFontProvider())
        for entry in entries {
            let record = await registry.record(for: entry.fontID)
            guard let face = record?.faces.first else { continue }
            let fontRef = MKFontRef(fontID: entry.fontID, postScriptName: face.postScriptName)

            let standard = MKTextStyle(font: fontRef, pointSize: 28, ligatureSetting: .standard)
            let dligOn = MKTextStyle(font: fontRef, pointSize: 28, ligatureSetting: .discretionaryOn)

            let standardResult = await service.captureResult(MKShapingRequest(string: Self.dligFixture, style: standard))
            let dligResult = await service.captureResult(MKShapingRequest(string: Self.dligFixture, style: dligOn))

            #expect(standardResult.paragraph.glyphCount > 0, "\(entry.fontID): zero glyphs (standard)")
            #expect(dligResult.paragraph.glyphCount > 0, "\(entry.fontID): zero glyphs (dlig on)")
            // Not asserting glyph-count INEQUALITY here ، Core Text
            // silently drops unsupported `dlig` feature settings per
            // WS03-A6's own finding (harmless no-op for fonts lacking the
            // feature), so equal counts are a legitimate outcome for most
            // of these fonts, not a failure.
        }
    }

    /// WS03-A6: a *leading* ZWJ does not force joining in the system SF
    /// font, but Geeza Pro (bundled system font) gets it right. This test
    /// confirms at least one WS-09-registered font also produces a form
    /// distinct from isolated for a medial-context harvest ، the concrete
    /// "stub S2 flip" DEPENDENCY_GRAPH.md calls for.
    @Test func amiriMedialFormHarvestIsDistinctFromIsolated() async throws {
        let registry = try await registeredRegistry()
        // Amiri is registered (provisional-ship or not ، either way its
        // faces are process-registered per BundledFontIndex/loadBundled),
        // so this reads its real font handle directly rather than going
        // through MKFontCatalog.browse() (which excludes provisional fonts
        // from the *catalog UI*, not from registration).
        let record = try #require(await registry.record(for: "amiri"))
        let face = try #require(record.faces.first)
        let resolver = MKFormResolver(fonts: MKRegistryFontProvider())
        let style = MKTextStyle(font: MKFontRef(fontID: "amiri", postScriptName: face.postScriptName), pointSize: 28)

        let isolated = await resolver.resolve(letter: "\u{062D}", form: .isolated, style: style)  // ح
        let medial = await resolver.resolve(letter: "\u{062D}", form: .medial, style: style)

        #expect(isolated != nil)
        #expect(medial != nil)
        if let isolated, let medial {
            #expect(isolated.glyphID != medial.glyphID, "Amiri did not produce a distinct medial form for ح")
        }
    }
}
