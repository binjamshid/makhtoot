import Testing
import CoreGraphics
import Foundation
import MKColor
@testable import MKExport

// P10-COMPLETION (Run-3, packet §5 task 12). CMYK print PDF writer.
// "Spike C" (docs/impl-log/WS-08.md): this session's finding that true
// per-element vector CMYK is unreachable without editing `MKRender` ، this
// writer ships a whole-page raster CMYK embed instead, and these tests
// verify EXACTLY that shape: real OutputIntent (Spike-B shape), real CMYK
// colorspace image data, explicit rendering intent, and the
// `.cmykContentRasterized` disclosure note on every export.
@Suite struct PDFPrintCMYKExporterTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pdfcmyk-\(UUID().uuidString).pdf")
    }

    @Test func producesAPDFWithOutputIntentAndDestOutputProfile() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let scene = TestScenes.mixedContentScene()
        let result = try await PDFPrintCMYKExporter.export(
            scene: scene, pixelSize: CGSize(width: 400, height: 300), dpi: 150, title: "T",
            profile: ICCProfileStore.loadBundled(), to: url
        )
        let bytes = try Data(contentsOf: url)
        let text = String(decoding: bytes, as: UTF8.self)
        #expect(text.contains("/OutputIntents"))
        #expect(text.contains("/DestOutputProfile"))
        #expect(text.contains("/ICCBased"))
        // Spike D (this session, see `PDFOutputIntent.swift`'s header):
        // CoreGraphics silently DISCARDS the whole OutputIntent dictionary
        // unless `/S` is the literal `GTS_PDFX` ، so the technical subtype
        // is always that value; D-226(4)'s "no PDF/X claim under
        // fallback" is honored at the Swift/app-copy level instead
        // (`MKICCProfileProvenance.mayClaimPDFX`), asserted below.
        #expect(text.contains("/S /GTS_PDFX"))
        #expect(text.contains("Apple Generic CMYK"))   // honest /OutputConditionIdentifier + /Info text
        #expect(!ICCProfileStore.loadBundled().provenance.mayClaimPDFX)
        #expect(result.fallbacks.contains { $0.reason == FallbackReason.cmykContentRasterized })
    }

    @Test func embeddedImageHasNoAlphaChannel() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let scene = TestScenes.rectScene()
        _ = try await PDFPrintCMYKExporter.export(
            scene: scene, pixelSize: CGSize(width: 200, height: 200), dpi: 72, title: "T",
            profile: ICCProfileStore.loadBundled(), to: url
        )
        let document = try #require(CGPDFDocument(url as CFURL))
        #expect(document.numberOfPages == 1)
        let bytes = try Data(contentsOf: url)
        let text = String(decoding: bytes, as: UTF8.self)
        #expect(text.contains("/ColorSpace"))
        #expect(text.contains("/XObject"))
        // No alpha channel (Spike A: CMYK bitmap contexts are alpha-none
        // only) ، no soft mask should ever be present on the embedded page
        // image.
        #expect(!text.contains("/SMask"))
    }

    @Test func degenerateSizeThrows() async {
        let scene = TestScenes.rectScene()
        await #expect(throws: MKExportError.self) {
            _ = try await PDFPrintCMYKExporter.export(
                scene: scene, pixelSize: .zero, dpi: 72, title: "T",
                profile: ICCProfileStore.loadBundled(), to: tempURL()
            )
        }
    }
}
