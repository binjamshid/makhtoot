import CoreGraphics
import Foundation
import Testing
@testable import MKAssets

// WS-14 packet §5 task 11 accept criteria: "sheet generates; review notes
// recorded (artifacts fixed or asset pulled)." This suite generates BOTH
// standard sizes (256pt, 1024pt) and writes them as PNG evidence under
// `docs/impl-log/WS-14-contact-sheets/` ، the packet §7 gate 3 "T-asset-01
// contact-sheet visual QA (both sizes)" artifact. Review notes are recorded
// in `docs/impl-log/WS-14.md`, not in this file (evidence generation vs.
// evidence review are kept separate ، this suite only proves the generator
// WORKS and produces non-degenerate output; a human/agent visual pass over
// the written PNGs is the actual QA step).
@Suite("MKAssetContactSheetGenerator (T11)")
struct MKAssetContactSheetTests {
    @Test func generatesANonEmptySheetCoveringEveryAsset() {
        let descriptors = MKAssetLibrary.standard.all
        let sheet = MKAssetContactSheetGenerator.generate(descriptors: descriptors, cellSize: 256)
        #expect(sheet != nil)
        guard let sheet else { return }
        let expectedColumns = 8
        let expectedRows = Int(ceil(Double(descriptors.count) / Double(expectedColumns)))
        #expect(sheet.width == expectedColumns * 256)
        #expect(sheet.height == expectedRows * 256)
    }

    @Test func generatesTheStandardTwoSizePair() {
        let (small, large) = MKAssetContactSheetGenerator.generateStandardPair(descriptors: MKAssetLibrary.standard.all)
        #expect(small != nil)
        #expect(large != nil)
        #expect(small!.width < large!.width)
    }

    @Test func writesBothSheetsAsPNGEvidenceUnderDocsImplLog() throws {
        let descriptors = MKAssetLibrary.standard.all
        let (small, large) = MKAssetContactSheetGenerator.generateStandardPair(descriptors: descriptors)
        guard let small, let large else {
            Issue.record("sheet generation failed")
            return
        }

        let evidenceDir = Self.evidenceDirectory()
        try FileManager.default.createDirectory(at: evidenceDir, withIntermediateDirectories: true)

        let smallURL = evidenceDir.appendingPathComponent("contact-sheet-256.png")
        let largeURL = evidenceDir.appendingPathComponent("contact-sheet-1024.png")
        #expect(MKAssetContactSheetGenerator.writePNG(small, to: smallURL))
        #expect(MKAssetContactSheetGenerator.writePNG(large, to: largeURL))

        #expect(FileManager.default.fileExists(atPath: smallURL.path))
        #expect(FileManager.default.fileExists(atPath: largeURL.path))
        let smallSize = (try? FileManager.default.attributesOfItem(atPath: smallURL.path)[.size] as? Int) ?? nil
        #expect((smallSize ?? 0) > 0)
    }

    @Test func perCategorySheetsGenerateForFocusedReview() throws {
        // In addition to the full-library sheet, a per-category sheet is
        // easier for a reviewer to scan for category-specific artifacts
        // (task 5's "self-intersection artifacts" note is ornament-
        // specific, for example).
        let evidenceDir = Self.evidenceDirectory()
        try FileManager.default.createDirectory(at: evidenceDir, withIntermediateDirectories: true)
        for category in MKAssetCategory.browserOrder {
            let descriptors = MKAssetLibrary.standard.descriptors(in: category)
            guard let sheet = MKAssetContactSheetGenerator.generate(descriptors: descriptors, cellSize: 256, columns: 6) else {
                Issue.record("\(category.rawValue) sheet failed to generate")
                continue
            }
            let url = evidenceDir.appendingPathComponent("contact-sheet-\(category.rawValue)-256.png")
            #expect(MKAssetContactSheetGenerator.writePNG(sheet, to: url))
        }
    }

    /// Resolves `docs/impl-log/WS-14-contact-sheets/` relative to the repo
    /// root, walking up from this test file's own `#filePath` ، the same
    /// `#filePath`-relative resolution style `MKFixtureLocator`/
    /// `MKAssetManifestGenerator` already use in this codebase, so evidence
    /// generation works regardless of the process's current working
    /// directory.
    static func evidenceDirectory(sourceFile: String = #filePath) -> URL {
        // This file: .../MakhtootKit/Tests/MKAssetsTests/MKAssetContactSheetTests.swift
        var url = URL(fileURLWithPath: sourceFile)
        url.deleteLastPathComponent() // MKAssetsTests/
        url.deleteLastPathComponent() // Tests/
        url.deleteLastPathComponent() // MakhtootKit/
        url.deleteLastPathComponent() // repo root
        return url.appendingPathComponent("docs/impl-log/WS-14-contact-sheets", isDirectory: true)
    }
}
