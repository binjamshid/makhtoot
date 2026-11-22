// Work item 0.2 — category (d): mark attachment. Drives
// `MKMarkAttacher.attachments(in:)` over the tashkeel-heavy corpus fixtures
// (F-3, F-4, F-6a/b, F-8) per family, including the Qur'anic annotation
// range U+06D6–06ED (harvested separately as a synthetic per-family probe,
// since none of the F-1..F-12 corpus strings contain a Qur'anic annotation
// mark — that range is reserved for recitation marks, not ordinary prose).
//
// `MKMarkAttachment` already stores `markClusterIndex`/`baseClusterIndex`
// as plain `Int` array indices (never a raw `MKClusterID`), so this DTO is
// a direct field-for-field mirror — no id-remap needed (Support.swift's
// header note does not apply to this category).
//
// Output: `android/fixtures/marks/<familyID>/<case-id>.json`.

import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKTextEngine

struct MarkAttachmentDTO: Encodable {
    var markClusterIndex: Int
    var markGlyph: GlyphAddressDTO?
    var baseClusterIndex: Int?
    var baseGlyph: GlyphAddressDTO?
    var relativeOffsetWidth: CGFloat?
    var relativeOffsetHeight: CGFloat?
    var markClass: String?

    init(_ a: MKMarkAttachment) {
        markClusterIndex = a.markClusterIndex
        markGlyph = a.markGlyph.map(GlyphAddressDTO.init)
        baseClusterIndex = a.baseClusterIndex
        baseGlyph = a.baseGlyph.map(GlyphAddressDTO.init)
        relativeOffsetWidth = a.relativeOffset?.width
        relativeOffsetHeight = a.relativeOffset?.height
        markClass = a.markClass?.rawValue
    }
}

struct MarksFixtureDTO: Encodable {
    var caseID: String
    var familyID: String
    var postScriptName: String
    var sourceText: String
    var attachments: [MarkAttachmentDTO]
}

// The tashkeel-bearing corpus subset (category d's port-map scope).
private let marksCorpusIDs: Set<String> = ["F-3", "F-4", "F-6a", "F-6b", "F-8"]

/// Synthetic per-family probe covering the Qur'anic recitation-annotation
/// range (U+06D6–U+06ED, D-105/`MKMarkClass.quranicAnnotation`) — deliberately
/// NOT real Qur'anic verse text (R-1.5/D-120: "no preloaded Qur'anic
/// content"), just a base letter (ب) followed by one mark from each end of
/// the range, purely to exercise the mark-classification/attachment code
/// path against that Unicode block.
private let quranicAnnotationProbe = "ب\u{06D6}ب\u{06ED}"

func exportMarks() throws {
    let families = FontCatalog.discoverFamilies()
    let categoryRoot = RepoPaths.fixturesRoot.appendingPathComponent("marks")
    let marksFixtures = Corpus.fixtures.filter { marksCorpusIDs.contains($0.id) }
        + [CorpusFixture(id: "quranic-annotation-probe", string: quranicAnnotationProbe, note: "U+06D6/U+06ED synthetic probe, not real Quranic content (R-1.5/D-120)")]

    var count = 0
    for family in families {
        guard let ps = FontCatalog.registerAndResolvePostScriptName(family) else {
            print("[marks] WARNING: could not resolve PostScript name for \(family.familyID) — skipped")
            continue
        }
        let fonts = NamedFontProvider(postScriptName: ps)
        let engine = MKShapingEngine(fonts: fonts)
        let familyDir = categoryRoot.appendingPathComponent(family.familyID)
        let style = MKTextStyle(font: .system(postScriptName: ps), pointSize: 36, lineHeightMultiple: 1.2)

        for fixture in marksFixtures {
            let line = engine.shapeSingleLine(MKShapingRequest(string: fixture.string, style: style))
            let attachments = MKMarkAttacher.attachments(in: line)
            let dto = MarksFixtureDTO(caseID: fixture.id, familyID: family.familyID, postScriptName: ps, sourceText: fixture.string, attachments: attachments.map(MarkAttachmentDTO.init))
            try GoldenJSON.write(dto, to: familyDir.appendingPathComponent("\(fixture.id).json"))
            count += 1
        }
    }
    print("[marks] wrote \(count) fixture files across \(families.count) families")
}
