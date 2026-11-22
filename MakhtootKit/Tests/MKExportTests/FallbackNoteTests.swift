import Testing
import Foundation
import MKFoundation
@testable import MKExport

// WS-08 packet §5 task 4 / Q73 "never silent" ، every `FallbackReason` has
// a non-empty Arabic message, and `FallbackNote` round-trips through
// Codable (needed for `MKExportResult`/future `ExportRecord` persistence).
@Suite struct FallbackNoteTests {
    private static let allReasons: [FallbackReason] = [
        .arrangedGeometry,
        .customLigatureDecomposition,
        .fontEmbeddingRestricted(fontName: "Amiri"),
        .pathTextFidelity,
        .userFidelityToggle,
        .rasterBelowPrintDPI,
        .pdfAssetRasterized,
        .colorGlyphRasterized,
        .lockedFontNoShapedCache(fontName: "DiwaniRoyal"),
        .downscaledForFreeTierBudget(requestedPixelWidth: 4096, requestedPixelHeight: 4096),
    ]

    @Test(arguments: allReasons)
    func everyReasonHasANonEmptyArabicMessage(_ reason: FallbackReason) {
        #expect(!reason.arabicMessage.isEmpty)
    }

    @Test(arguments: allReasons)
    func everyReasonHasAStableEventName(_ reason: FallbackReason) {
        #expect(!reason.eventName.isEmpty)
    }

    @Test func noteCarriesTheReasonsMessageAndEventName() {
        let note = FallbackNote(nodeID: MKNodeID(), reason: .rasterBelowPrintDPI, detail: "142 DPI measured")
        #expect(note.arabicMessage == FallbackReason.rasterBelowPrintDPI.arabicMessage)
        #expect(note.eventName == "rasterBelowPrintDPI")
    }

    @Test func fallbackNoteRoundTripsThroughJSON() throws {
        let note = FallbackNote(nodeID: MKNodeID(), reason: .fontEmbeddingRestricted(fontName: "Custom Font"), detail: "no license")
        let data = try JSONEncoder().encode(note)
        let decoded = try JSONDecoder().decode(FallbackNote.self, from: data)
        #expect(decoded == note)
    }

    @Test func documentWideNoteHasNoNodeID() {
        let note = FallbackNote(reason: .downscaledForFreeTierBudget(requestedPixelWidth: 100, requestedPixelHeight: 100))
        #expect(note.nodeID == nil)
    }
}
