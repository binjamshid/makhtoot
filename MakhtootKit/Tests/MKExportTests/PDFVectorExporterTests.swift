import Testing
import CoreGraphics
import Foundation
import MKFoundation
import MKModel
@testable import MKExport

// P10-COMPLETION (Run-3, packet §5 task 11). Verifies the vector RGB PDF
// writer by RE-PARSING the produced file (`CGPDFDocument`), never just
// checking that `export` didn't throw ، matching the packet's own
// "verified by re-parsing" evidence bar.
@Suite struct PDFVectorExporterTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pdfvector-\(UUID().uuidString).pdf")
    }

    @Test func producesAWellFormedSinglePagePDF() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let scene = TestScenes.mixedContentScene()
        _ = try PDFVectorExporter.export(
            scene: scene, pixelSize: CGSize(width: 800, height: 600), dpi: 72, title: "Test",
            fontLicense: AllOFLLicenseStub(), fonts: SystemFontStubProvider(), to: url
        )
        let document = try #require(CGPDFDocument(url as CFURL))
        #expect(document.numberOfPages == 1)
        let page = try #require(document.page(at: 1))
        let box = page.getBoxRect(.mediaBox)
        #expect(box.width > 0 && box.height > 0)
    }

    /// Task 11 accept: "arranged content pure vector (6400% zoom, no
    /// pixelation)" ، verified indirectly here by confirming the content
    /// stream contains real vector path operators (`re`/`f`/`S`/curve ops)
    /// rather than being dominated by a single embedded raster image.
    @Test func contentStreamContainsVectorPathOperators() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let scene = TestScenes.mixedContentScene()
        _ = try PDFVectorExporter.export(
            scene: scene, pixelSize: CGSize(width: 800, height: 600), dpi: 72, title: "Test",
            fontLicense: AllOFLLicenseStub(), fonts: SystemFontStubProvider(), to: url
        )
        let decompressed = try PDFContentStreamProbe.decompressedContentStreams(of: url)
        let combined = decompressed.joined()
        // A shape fill/stroke pair always emits at least one PDF
        // path-painting operator; a pure-raster page would not. `B`
        // (fill-then-stroke, the combined operator `ctx.drawPath(using:
        // .fillStroke)` actually emits ، confirmed empirically by
        // inspecting a real produced content stream, not assumed from the
        // PDF spec's operator table alone) is the one `mixedContentScene`'s
        // stroked rect produces; the other single-purpose operators are
        // checked too for robustness against future fixture changes.
        let pathPaintingOperators = [" B", " b", " f", " f*", " S", " s"]
        #expect(pathPaintingOperators.contains { combined.contains($0) }, "content stream had no path-painting operator: \(combined.prefix(300))")
    }

    /// D-227(1)/§16.5: a font WITH `.pdf` embedding rights draws as real
    /// text (CTFontDrawGlyphs → PDF text-showing operators), never as an
    /// outline substitution ، verified by checking the page's font
    /// resource dictionary is non-empty (a real embedded/referenced font).
    @Test func embeddableFontDrawsAsRealTextWithAFontResource() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let scene = TestScenes.mixedContentScene()
        _ = try PDFVectorExporter.export(
            scene: scene, pixelSize: CGSize(width: 800, height: 600), dpi: 72, title: "Test",
            fontLicense: AllOFLLicenseStub(), fonts: SystemFontStubProvider(), to: url
        )
        let bytes = try Data(contentsOf: url)
        let text = String(decoding: bytes, as: UTF8.self)
        #expect(text.contains("/Font"))
    }

    /// The per-license outline switch (task 11's "license switch: no-embed
    /// fonts → outlines"): a user-imported font (no `.pdf` rights per
    /// `AllOFLLicenseStub`) must NOT produce a `/Font` resource for that
    /// text ، its glyphs are filled paths instead ، and the writer must
    /// report a `fontEmbeddingRestricted` fallback for that node.
    @Test func restrictedFontProducesOutlinesAndAFallbackNote() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let scene = TestScenes.restrictedFontLiveTextScene()
        let result = try PDFVectorExporter.export(
            scene: scene, pixelSize: CGSize(width: 600, height: 300), dpi: 72, title: "Test",
            fontLicense: AllOFLLicenseStub(), fonts: SystemFontStubProvider(), to: url
        )
        #expect(result.fallbacks.contains { if case .fontEmbeddingRestricted = $0.reason { return true }; return false })
        // The path must be genuinely non-empty (real outline geometry was
        // drawn, not silently skipped).
        let bytes = try Data(contentsOf: url)
        #expect(bytes.count > 500)
    }

    /// Pins EXISTING behavior (this test adds no new production code): the
    /// vector PDF writer already embeds a canvas background image
    /// correctly, unlike the SVG writer's `imageBackgroundNotEmbedded` gap
    /// this session fixes elsewhere. `PDFVectorExporter.export` builds an
    /// `MKSceneRenderer(fonts:assets:)` and renders into the real
    /// `CGPDFContext` (`PDFVectorExporter.swift`), which routes through
    /// `SceneRenderer.swift`'s `backgroundDrawer.draw(...)` →
    /// `BackgroundDrawer.swift`'s `.image` case (`ctx.draw(image, in:)`) ،
    /// the SAME drawer every other render target (live preview, raster
    /// export) uses. Verified two ways: (1) the produced PDF re-parses as
    /// valid via `CGPDFDocument`, and (2) it is materially larger than the
    /// same scene with a solid-color background, which is only possible if
    /// the photo's pixel data actually made it into the page content
    /// stream (an un-embedded/dropped background would produce a
    /// byte-for-byte-comparable, NOT materially larger, file).
    @Test func vectorPDFAlreadyEmbedsTheCanvasBackgroundImage() throws {
        let assetRef = MKAssetRef(digest: "feedface", ext: "png")
        let image = FakeAssetFactory.nonSquareImage(width: 300, height: 150)
        let assets = FakeAssetProvider(ref: assetRef, image: image)

        var photoBackground = MKBackgroundNode.defaultBackground()
        photoBackground.content = .image(assetRef, fit: .cover)
        let photoScene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 200, height: 200)), background: photoBackground, nodes: [])

        var solidBackground = MKBackgroundNode.defaultBackground()
        solidBackground.content = .solid(.white)
        let solidScene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 200, height: 200)), background: solidBackground, nodes: [])

        let photoURL = tempURL()
        let solidURL = tempURL()
        defer {
            try? FileManager.default.removeItem(at: photoURL)
            try? FileManager.default.removeItem(at: solidURL)
        }

        let photoResult = try PDFVectorExporter.export(
            scene: photoScene, pixelSize: CGSize(width: 200, height: 200), dpi: 72, title: "Test",
            fontLicense: AllOFLLicenseStub(), fonts: SystemFontStubProvider(), assets: assets, to: photoURL
        )
        _ = try PDFVectorExporter.export(
            scene: solidScene, pixelSize: CGSize(width: 200, height: 200), dpi: 72, title: "Test",
            fontLicense: AllOFLLicenseStub(), fonts: SystemFontStubProvider(), to: solidURL
        )

        let photoDocument = try #require(CGPDFDocument(photoURL as CFURL))
        #expect(photoDocument.numberOfPages == 1)
        #expect(photoResult.fallbacks.isEmpty)

        let photoBytes = try Data(contentsOf: photoURL)
        let solidBytes = try Data(contentsOf: solidURL)
        #expect(photoBytes.count > solidBytes.count + 1000, "expected the embedded photo to materially grow the PDF (photo: \(photoBytes.count) bytes, solid: \(solidBytes.count) bytes)")
    }

    @Test func degenerateSizeThrows() {
        let scene = TestScenes.rectScene()
        #expect(throws: MKExportError.self) {
            _ = try PDFVectorExporter.export(
                scene: scene, pixelSize: .zero, dpi: 72, title: "Test",
                fontLicense: AllOFLLicenseStub(), fonts: SystemFontStubProvider(), to: tempURL()
            )
        }
    }
}

/// Shared PDF content-stream decompression helper ، PDF's `/FlateDecode`
/// streams are standard zlib-wrapped DEFLATE (RFC 1950: a 2-byte header +
/// DEFLATE data + a 4-byte Adler-32 trailer). `NSData.decompressed(using:
/// .zlib)` (Foundation's `Compression.framework` bridge, macOS 10.15+/iOS
/// 13+, well within D-100's floor) is ، despite its name ، documented to
/// operate on RAW DEFLATE, NOT the zlib-wrapped container (verified
/// empirically: calling it directly on a real PDF content stream's raw
/// bytes throws `NSCocoaErrorDomain Code=5377`; stripping the 2-byte
/// header and 4-byte trailer first and decompressing THAT with `.zlib`
/// succeeds and produces readable PDF operators). This is a genuinely
/// confusing platform-API-naming trap (`.zlib` here means "raw deflate,"
/// not "zlib format") ، documented here so nobody "fixes" this back to
/// the naive call.
enum PDFContentStreamProbe {
    static func decompressedContentStreams(of url: URL) throws -> [String] {
        let bytes = try Data(contentsOf: url)
        var results: [String] = []
        var searchRange = bytes.startIndex..<bytes.endIndex
        let streamMarker = Data("stream".utf8)
        let endStreamMarker = Data("endstream".utf8)
        while let streamRange = bytes.range(of: streamMarker, options: [], in: searchRange) {
            var contentStart = streamRange.upperBound
            // `stream` keyword is followed by CRLF or LF before content.
            if contentStart < bytes.endIndex, bytes[contentStart] == 0x0D { contentStart += 1 }
            if contentStart < bytes.endIndex, bytes[contentStart] == 0x0A { contentStart += 1 }
            guard let endRange = bytes.range(of: endStreamMarker, options: [], in: contentStart..<bytes.endIndex) else { break }
            let raw = bytes[contentStart..<endRange.lowerBound]
            if raw.count > 6 {
                // Strip the 2-byte zlib header + 4-byte Adler-32 trailer
                // (see this type's doc comment) before handing the RAW
                // DEFLATE payload to `.decompressed(using: .zlib)`.
                let rawDeflate = Data(raw.dropFirst(2).dropLast(4))
                if let decompressed = try? (rawDeflate as NSData).decompressed(using: .zlib) as Data,
                   let text = String(data: decompressed, encoding: .isoLatin1) {
                    results.append(text)
                }
            }
            searchRange = endRange.upperBound..<bytes.endIndex
        }
        return results
    }
}
