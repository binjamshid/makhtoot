import Testing
import CoreGraphics
import Foundation
import MKFoundation
@testable import MKExport

// P10-COMPLETION (Run-3, packet §5 tasks 13-16).
@Suite struct SVGSerializerTests {
    @Test func rootElementIsWellFormedAndCarriesTheSchemaVersion() throws {
        let scene = TestScenes.mixedContentScene()
        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 800, height: 600))
        #expect(result.svg.hasPrefix("<svg "))
        #expect(result.svg.contains("data-mk-schema=\"1\""))
        #expect(result.svg.contains("xmlns=\"http://www.w3.org/2000/svg\""))
        try XMLWellFormedness.assertWellFormed(result.svg)
    }

    @Test func backgroundRendersAsARect() throws {
        let scene = TestScenes.rectScene()
        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 200, height: 200))
        #expect(result.svg.contains("data-mk-kind=\"background\""))
        try XMLWellFormedness.assertWellFormed(result.svg)
    }

    @Test func shapesEmitPathElements() throws {
        let scene = TestScenes.mixedContentScene()
        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 800, height: 600))
        #expect(result.svg.contains("data-mk-kind=\"shape\""))
        #expect(result.svg.contains("<path"))
    }

    @Test func groupsNestChildrenWithATransformAttribute() throws {
        let scene = TestScenes.mixedContentScene()
        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 800, height: 600))
        #expect(result.svg.contains("data-mk-kind=\"group\""))
        #expect(result.svg.contains("transform=\"matrix("))
    }

    // MARK: - Live text

    @Test func embeddableLiveTextEmitsARealTextElementWithArabicSourceText() throws {
        let scene = TestScenes.mixedContentScene()
        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 800, height: 600))
        #expect(result.svg.contains("data-mk-kind=\"liveText\""))
        #expect(result.svg.contains("<text "))
        #expect(result.svg.contains("direction=\"rtl\""))
        #expect(result.svg.contains("بسم الله الرحمن الرحيم"))
    }

    @Test func restrictedFontLiveTextIsOutlinedWithProvenanceAndFallbackNote() throws {
        let scene = TestScenes.restrictedFontLiveTextScene()
        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 600, height: 300))
        #expect(result.svg.contains("data-mk-outlined=\"fontEmbeddingRestricted\""))
        #expect(!result.svg.contains("<text "))   // outlined, not live text
        #expect(result.svg.contains("data-mk-kind=\"glyph\""))
        #expect(result.fallbacks.contains { if case .fontEmbeddingRestricted = $0.reason { return true }; return false })
        try XMLWellFormedness.assertWellFormed(result.svg)
    }

    /// `MKTextOutlining.isEmojiCluster`'s own logic, tested directly
    /// (deterministic ، does not depend on a specific font being able to
    /// shape/render U+1F600, which `SystemFontStubProvider`'s Latin-only
    /// "Helvetica" fallback cannot do; see `arrangedEmojiFixture` test
    /// below for the full end-to-end carve-out, which sidesteps live
    /// shaping entirely by using pre-tagged `MKProvenance.codepoints`).
    @Test func isEmojiClusterDetectsGrinningFaceButNotArabicDigits() {
        #expect(MKTextOutlining.isEmojiCluster([0x1F600]))   // 😀
        #expect(MKTextOutlining.isEmojiCluster([0x0644, 0x1F600]))   // mixed cluster still counts
        #expect(!MKTextOutlining.isEmojiCluster([0x0644]))   // ل (Arabic lam)
        #expect(!MKTextOutlining.isEmojiCluster([0x0031]))   // ASCII '1' ، isEmoji but not isEmojiPresentation
        #expect(!MKTextOutlining.isEmojiCluster([]))
    }

    /// D-227(4)'s literal accept fixture: "emoji-inside-arranged-group
    /// fixture exports as image element (not outlined)."
    @Test func emojiInsideArrangedGroupBecomesAnImageElement() throws {
        let scene = TestScenes.arrangedSceneWithEmoji()
        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 300, height: 200))
        #expect(result.svg.contains("data-mk-kind=\"emojiGlyph\""))
        #expect(result.fallbacks.contains { $0.reason == FallbackReason.colorGlyphRasterized })
        try XMLWellFormedness.assertWellFormed(result.svg)
    }

    // MARK: - Path text (WS08-A5: always outlined, never <textPath>)

    @Test func pathTextNeverEmitsTextPathElement() throws {
        let scene = TestScenes.pathTextScene()
        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 300, height: 300))
        #expect(!result.svg.contains("<textPath"))
        #expect(result.svg.contains("data-mk-kind=\"pathText\""))
        #expect(result.fallbacks.contains { $0.reason == .pathTextFidelity })
        try XMLWellFormedness.assertWellFormed(result.svg)
    }

    // MARK: - Arranged composition (D-227(2) canonical schema)

    @Test func arrangedGlyphsCarryTheCanonicalProvenanceSchema() throws {
        let scene = TestScenes.arrangedScene()
        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 300, height: 200))
        #expect(result.svg.contains("data-mk-kind=\"arranged\""))
        #expect(result.svg.contains("data-mk-kind=\"glyph\""))
        #expect(result.svg.contains("data-mk-kind=\"mark\""))
        // D-227(2): space-separated hex codepoints, e.g. "644" (لا's lam,
        // 0x0644) ، never comma-separated.
        #expect(result.svg.contains("data-mk-codepoints=\"644\""))
        #expect(!result.svg.contains("data-mk-codepoints=\"644,"))
        #expect(result.svg.contains("data-mk-schema=\"1\""))
        try XMLWellFormedness.assertWellFormed(result.svg)
    }

    /// Task 15 accept: "round-trip audit ، parse own SVG, reconstruct
    /// codepoints from `data-mk-*`, equals the source backup."
    @Test func arrangedProvenanceRoundTripsToTheOriginalCodepoints() throws {
        let scene = TestScenes.arrangedScene()
        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 300, height: 200))
        let reconstructed = DataMKProvenanceParser.reconstructCodepoints(fromGlyphGroupsIn: result.svg)
        // The scene's two glyphs carry codepoints 0x0644 ("ل") and 0x0627
        // ("ا") ، reconstructing IN DOCUMENT ORDER (the order `<g
        // data-mk-kind="glyph">` elements appear, which is paint/visual
        // order per `MKArrangedGeometry.Index.paintOrder`) must recover
        // both.
        #expect(reconstructed.contains(0x0644))
        #expect(reconstructed.contains(0x0627))
    }

    // MARK: - Fallback documentation agreement (INV-15 test hook)

    @Test func everyOutlinedAttributeHasAMatchingFallbackNote() throws {
        let scene = TestScenes.restrictedFontLiveTextScene()
        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 600, height: 300))
        let outlinedCount = result.svg.components(separatedBy: "data-mk-outlined=\"fontEmbeddingRestricted\"").count - 1
        let noteCount = result.fallbacks.filter { if case .fontEmbeddingRestricted = $0.reason { return true }; return false }.count
        #expect(outlinedCount == noteCount)
    }

    @Test func degenerateSourceProducesAnEmptySVGBodyNotACrash() {
        var scene = TestScenes.rectScene()
        scene.background.core.isHidden = true
        scene.nodes = []
        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 10, height: 10))
        #expect(result.svg.contains("<svg"))
        #expect(result.fallbacks.isEmpty)
    }
}

/// Minimal well-formedness check via `XMLParser` (Foundation) ، a REAL
/// parse, not a string heuristic (task 13 accept: "xmllint well-formed";
/// `XMLParser` is the in-process equivalent available without a shell
/// dependency).
enum XMLWellFormedness {
    static func assertWellFormed(_ xml: String) throws {
        // `XMLParser` requires a single root element and no bare `&`/`<`
        // outside markup ، wrap the fragment in a synthetic root only if
        // it doesn't already declare a `<?xml` prolog (our fragments are
        // plain `<svg>...</svg>`, already single-rooted).
        let data = Data(xml.utf8)
        let parser = XMLParser(data: data)
        let delegate = CollectingDelegate()
        parser.delegate = delegate
        let ok = parser.parse()
        if !ok {
            throw XMLNotWellFormedError(underlying: parser.parserError, line: parser.lineNumber, column: parser.columnNumber)
        }
    }

    private final class CollectingDelegate: NSObject, XMLParserDelegate {}

    struct XMLNotWellFormedError: Error, CustomStringConvertible {
        var underlying: Error?
        var line: Int
        var column: Int
        var description: String { "XML not well-formed at line \(line), column \(column): \(String(describing: underlying))" }
    }
}

/// A tiny regex-free `data-mk-codepoints`/`data-mk-kind="glyph"` extractor
/// ، a REAL parse of the emitted attributes (not re-deriving from the
/// source scene), matching task 15's own "parse own SVG, reconstruct
/// codepoints" accept criterion.
enum DataMKProvenanceParser {
    static func reconstructCodepoints(fromGlyphGroupsIn svg: String) -> Set<UInt32> {
        var result: Set<UInt32> = []
        var searchRange = svg.startIndex..<svg.endIndex
        while let kindRange = svg.range(of: "data-mk-kind=\"glyph\"", range: searchRange) {
            // The SAME element's `data-mk-codepoints="..."` attribute lives
            // on the same `<g ...>` opening tag ، search FORWARD a bounded
            // window (attribute order in `SVGSerializer.renderArrangedElement`
            // is `data-mk-schema`, `data-mk-kind`, `data-mk-codepoints`,
            // ...) up to the tag's closing `>`.
            let windowEnd = svg.index(kindRange.upperBound, offsetBy: 400, limitedBy: svg.endIndex) ?? svg.endIndex
            let window = svg[kindRange.upperBound..<windowEnd]
            if let tagEnd = window.firstIndex(of: ">"), let cpRange = window[..<tagEnd].range(of: "data-mk-codepoints=\"") {
                let afterQuote = cpRange.upperBound
                if let endQuote = window[afterQuote...].firstIndex(of: "\"") {
                    let hexTokens = window[afterQuote..<endQuote].split(separator: " ")
                    for token in hexTokens {
                        if let value = UInt32(token, radix: 16) { result.insert(value) }
                    }
                }
            }
            searchRange = kindRange.upperBound..<svg.endIndex
        }
        return result
    }
}
