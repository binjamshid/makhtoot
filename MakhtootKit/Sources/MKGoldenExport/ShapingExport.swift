// Work item 0.2 — category (a): shaping. Drives `MKShapingEngine`
// across all 45 bundled families × the canonical corpus (`Corpus.swift`,
// PRD.md F-1..F-12) and dumps glyph ids, positions, advances, cluster map,
// bidi levels and RTL run flags as sorted-key JSON.
//
// Output: `android/fixtures/shaping/<familyID>/<corpus-id>.json`.

import CoreGraphics
import CoreText
import Foundation
import MKFoundation
import MKModel
import MKTextEngine

// MARK: - DTOs (see Support.swift header: never a raw MKID/Date)

struct GlyphAddressDTO: Encodable {
    var run: Int
    var glyph: Int
    init(_ a: MKGlyphAddress) { run = a.run; glyph = a.glyph }
}

struct ShapedRunDTO: Encodable {
    var glyphs: [UInt16]
    var positions: [CGPoint]
    var advances: [CGSize]
    var stringIndices: [Int]
    var stringRangeStart: Int
    var stringRangeEnd: Int
    var isRTL: Bool
    var isNonMonotonic: Bool
    var fontPostScriptName: String
    var fontPointSize: CGFloat
    var tracking: CGFloat
    var baselineShift: CGFloat
    var standardLigaturesEnabled: Bool
    var cursiveAttached: [Bool]

    init(_ run: MKShapedRun) {
        glyphs = run.glyphs
        positions = run.positions
        advances = run.advances
        stringIndices = run.stringIndices
        stringRangeStart = run.stringRange.lowerBound
        stringRangeEnd = run.stringRange.upperBound
        isRTL = run.isRTL
        isNonMonotonic = run.isNonMonotonic
        fontPostScriptName = run.font.postScriptName
        fontPointSize = run.font.pointSize
        tracking = run.attributes.tracking
        baselineShift = run.attributes.baselineShift
        standardLigaturesEnabled = run.attributes.standardLigaturesEnabled
        cursiveAttached = run.cursiveAttached
    }
}

struct ClusterDTO: Encodable {
    var ordinal: Int
    var utf16Start: Int
    var utf16End: Int
    var codepoints: [UInt32]
    var glyphs: [GlyphAddressDTO]
    var kind: String

    init(ordinal: Int, cluster: MKCluster) {
        self.ordinal = ordinal
        utf16Start = cluster.utf16Range.lowerBound
        utf16End = cluster.utf16Range.upperBound
        codepoints = cluster.codepoints
        glyphs = cluster.glyphs.map(GlyphAddressDTO.init)
        switch cluster.kind {
        case .simple: kind = "simple"
        case .ligature: kind = "ligature"
        case .baseWithMarks(let baseCount): kind = "baseWithMarks(\(baseCount))"
        case .markOnly: kind = "markOnly"
        case .control: kind = "control"
        }
    }
}

struct BidiRunDTO: Encodable {
    var utf16Start: Int
    var utf16End: Int
    var level: UInt8
    var isRTL: Bool
    var visualOrdinal: Int
    init(_ run: MKBidiRun) {
        utf16Start = run.utf16Range.lowerBound
        utf16End = run.utf16Range.upperBound
        level = run.level
        isRTL = run.isRTL
        visualOrdinal = run.visualOrdinal
    }
}

struct ShapedLineDTO: Encodable {
    var lineIndexInParagraph: Int
    var sourceRangeStart: Int
    var sourceRangeEnd: Int
    var ascent: CGFloat
    var descent: CGFloat
    var leading: CGFloat
    var width: CGFloat
    var glyphCount: Int
    var runs: [ShapedRunDTO]
    var clusters: [ClusterDTO]
    var bidiBaseDirection: String
    var bidiRuns: [BidiRunDTO]

    init(_ line: MKShapedLine) {
        lineIndexInParagraph = line.lineIndexInParagraph
        sourceRangeStart = line.sourceRange.lowerBound
        sourceRangeEnd = line.sourceRange.upperBound
        ascent = line.typographicBounds.ascent
        descent = line.typographicBounds.descent
        leading = line.typographicBounds.leading
        width = line.typographicBounds.width
        glyphCount = line.glyphCount
        runs = line.runs.map(ShapedRunDTO.init)
        clusters = line.clusterMap.clusters.enumerated().map { ClusterDTO(ordinal: $0.offset, cluster: $0.element) }
        bidiBaseDirection = line.bidiMap.baseDirection.rawValue
        bidiRuns = line.bidiMap.runs.map(BidiRunDTO.init)
    }
}

struct ShapingFixtureDTO: Encodable {
    var corpusID: String
    var note: String
    var familyID: String
    var familyDir: String
    var fontFile: String
    var postScriptName: String
    var pointSize: Double
    var sourceText: String
    var lines: [ShapedLineDTO]
}

// MARK: - Export

func exportShaping() throws {
    let families = FontCatalog.discoverFamilies()
    precondition(families.count == 45, "expected 45 bundled families, found \(families.count) — see impl log")

    let categoryRoot = RepoPaths.fixturesRoot.appendingPathComponent("shaping")
    var count = 0
    for family in families {
        guard let ps = FontCatalog.registerAndResolvePostScriptName(family) else {
            print("[shaping] WARNING: could not resolve PostScript name for \(family.familyID) (\(family.fileName)) — skipped")
            continue
        }
        let fonts = NamedFontProvider(postScriptName: ps)
        let engine = MKShapingEngine(fonts: fonts)
        let familyDir = categoryRoot.appendingPathComponent(family.familyID)

        for fixture in Corpus.fixtures {
            let style = MKTextStyle(font: .system(postScriptName: ps), pointSize: 36, lineHeightMultiple: 1.2, baseDirection: .rightToLeft)
            let request = MKShapingRequest(string: fixture.string, style: style)
            let paragraph = engine.shapeParagraph(request)
            let dto = ShapingFixtureDTO(
                corpusID: fixture.id, note: fixture.note, familyID: family.familyID,
                familyDir: family.familyDir, fontFile: family.fileName, postScriptName: ps,
                pointSize: style.pointSize, sourceText: fixture.string,
                lines: paragraph.lines.map(ShapedLineDTO.init))
            try GoldenJSON.write(dto, to: familyDir.appendingPathComponent("\(fixture.id).json"))
            count += 1
        }
    }
    print("[shaping] wrote \(count) fixture files across \(families.count) families")
}
