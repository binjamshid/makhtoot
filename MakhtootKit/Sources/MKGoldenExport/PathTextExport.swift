// Work item 0.2 — category (f): path-text placement. Constructs three
// representative Bézier paths (straight, curved-open, closed) and dumps
// `PathLayoutEngine` placement results for a sample of corpus glyph runs
// along each, reusing the shipped engine exactly as
// `Tests/MKPathTextTests/PathLayoutEngineTests.swift` already exercises it.
//
// Output: `android/fixtures/pathtext/<path-id>/<family>-<corpus-id>.json`.
//
// Determinism: `PathGlyphPlacement.clusterID`/`baseClusterID` (raw
// `MKClusterID`) are replaced by their ordinal in the SAME shaped line's
// own cluster sequence (`clusterOrdinalMap`, Support.swift) — never the raw
// UUID. `provenanceKey` (codepoints + occurrenceOrdinal) is already
// deterministic content, kept as-is.

import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPathText
import MKTextEngine

// MARK: - DTOs

struct PathGlyphPlacementDTO: Encodable {
    var address: GlyphAddressDTO
    var clusterOrdinal: Int
    var codepoints: [UInt32]
    var occurrenceOrdinal: Int
    var arcLength: CGFloat
    var position: CGPoint
    var rotation: CGFloat
    var userOffset: CGPoint
    var userRotation: CGFloat
    var isMark: Bool
    var baseClusterOrdinal: Int?

    init(_ p: PathGlyphPlacement, clusterOrdinals: [MKClusterID: Int]) {
        address = GlyphAddressDTO(p.address)
        clusterOrdinal = clusterOrdinals[p.clusterID] ?? -1
        codepoints = p.provenanceKey.codepoints
        occurrenceOrdinal = p.provenanceKey.occurrenceOrdinal
        arcLength = p.arcLength
        position = p.position
        rotation = p.rotation
        userOffset = p.userOffset
        userRotation = p.userRotation
        isMark = p.isMark
        baseClusterOrdinal = p.baseClusterID.flatMap { clusterOrdinals[$0] }
    }
}

struct OverflowInfoDTO: Encodable {
    var isOverflowing: Bool
    var overflowUTF16Start: Int?
    var overflowUTF16End: Int?
    var continuedStraight: Bool
    init(_ o: OverflowInfo) {
        isOverflowing = o.isOverflowing
        overflowUTF16Start = o.overflowUTF16Range?.lowerBound
        overflowUTF16End = o.overflowUTF16Range?.upperBound
        continuedStraight = o.continuedStraight
    }
}

struct PathTextFixtureDTO: Encodable {
    var pathID: String
    var familyID: String
    var postScriptName: String
    var corpusID: String
    var sourceText: String
    var options: [String: String]
    var pathLength: CGFloat
    var curvatureWarning: Bool
    var penStartArcLength: CGFloat
    var penEndArcLength: CGFloat
    var placements: [PathGlyphPlacementDTO]
    var overflow: OverflowInfoDTO
}

// MARK: - Representative paths

private struct NamedPath { let id: String; let model: BezierPathModel; let closed: Bool }

private func representativePaths() -> [NamedPath] {
    let straight = BezierPathModel.line(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 900, y: 0))
    let circle = BezierPathModel.circle(center: CGPoint(x: 450, y: 450), radius: 400)
    // Open curved S-path: three anchors with cubic handles, deterministic
    // fixed geometry (no randomness).
    let curved = BezierPathModel(anchors: [
        PathAnchor(point: CGPoint(x: 0, y: 0), handleOut: CGPoint(x: 150, y: 0)),
        PathAnchor(point: CGPoint(x: 450, y: 300), handleIn: CGPoint(x: 300, y: 300), handleOut: CGPoint(x: 600, y: 300)),
        PathAnchor(point: CGPoint(x: 900, y: 0), handleIn: CGPoint(x: 750, y: 0)),
    ], isClosed: false)
    return [
        NamedPath(id: "straight", model: straight, closed: false),
        NamedPath(id: "curved-open", model: curved, closed: false),
        NamedPath(id: "closed-circle", model: circle, closed: true),
    ]
}

// A small representative sample of the corpus — every path-relevant case
// (F-10 is the dedicated path-text fixture; F-1/F-5/F-11 add ligature/bidi/
// full-alphabet coverage along a path).
private let pathTextCorpusIDs: Set<String> = ["F-1", "F-5", "F-10", "F-11"]

// A small representative family set (matches the arrange category's
// choice, for the same reason: full 45× sweep is `shaping/joining/marks`'s
// job, not this category's).
private let pathTextFamilyIDs = ["amiri", "noto-naskh-arabic"]

func exportPathText() throws {
    let categoryRoot = RepoPaths.fixturesRoot.appendingPathComponent("pathtext")
    let paths = representativePaths()
    let families = FontCatalog.discoverFamilies().filter { pathTextFamilyIDs.contains($0.familyID) }
    let corpusFixtures = Corpus.fixtures.filter { pathTextCorpusIDs.contains($0.id) }
    var count = 0

    for path in paths {
        let lut = ArcLengthLUT(path: path.model)
        let options = PathLayoutOptions()
        let pathDir = categoryRoot.appendingPathComponent(path.id)

        for family in families {
            guard let ps = FontCatalog.registerAndResolvePostScriptName(family) else {
                print("[pathtext] WARNING: could not resolve PostScript name for \(family.familyID) — skipped")
                continue
            }
            let engine = MKShapingEngine(fonts: NamedFontProvider(postScriptName: ps))
            let style = MKTextStyle(font: .system(postScriptName: ps), pointSize: 28, lineHeightMultiple: 1.2)

            for fixture in corpusFixtures {
                let line = engine.shapeSingleLine(MKShapingRequest(string: fixture.string, style: style))
                let clusterOrdinals = clusterOrdinalMap(line)
                let result = path.closed
                    ? PathLayoutEngine.layoutClosed(line: line, lut: lut, options: options)
                    : PathLayoutEngine.layout(line: line, lut: lut, options: options)

                let dto = PathTextFixtureDTO(
                    pathID: path.id, familyID: family.familyID, postScriptName: ps, corpusID: fixture.id,
                    sourceText: fixture.string,
                    options: ["side": String(describing: options.side), "spacingMode": String(describing: options.spacingMode), "alignment": options.alignment.rawValue],
                    pathLength: result.pathLength, curvatureWarning: result.curvatureWarning,
                    penStartArcLength: result.penStartArcLength, penEndArcLength: result.penEndArcLength,
                    placements: result.placements.map { PathGlyphPlacementDTO($0, clusterOrdinals: clusterOrdinals) },
                    overflow: OverflowInfoDTO(result.overflow))
                try GoldenJSON.write(dto, to: pathDir.appendingPathComponent("\(family.familyID)-\(fixture.id).json"))
                count += 1
            }
        }
    }
    print("[pathtext] wrote \(count) fixture files across \(paths.count) paths × \(families.count) families × \(corpusFixtures.count) corpus strings")
}
