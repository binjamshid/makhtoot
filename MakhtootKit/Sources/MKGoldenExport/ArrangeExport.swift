// Work item 0.2 — category (e): arrange derivation snapshots. Loads
// each of the 4 `Tests/Fixtures/*.makhtoot` scenes via `MKSceneCodec`, runs
// `ArrangeDeriver` over every `.liveText` node, and dumps the derived
// `ArrangedComposition` (pre-arrange scene → arranged composition).
//
// Output: `android/fixtures/arrange/<fixture-name>/<node-index>.json`.
//
// Determinism (see Support.swift header — MKID/Date are never serialized
// raw): every `MKNodeID` on a freshly-derived glyph/mark/ligature child is
// replaced by its ARRAY POSITION in `composition.nodes` (top-level) or, for
// decomposed-ligature components / cross-references, its position within
// the referenced local array. Every `MKClusterID` in `MKProvenance` is
// replaced by its ordinal position in the shaping capture's own cluster
// sequence (`clusterOrdinalMap`, Support.swift) — the SAME capture object
// `ArrangeDeriver.derive` itself consumed, so the mapping is exact.
// `MKSourceTextBackup.createdAt` (a `Date`) is dropped entirely; its
// `contentHash`/`sourceString`/`style` are deterministic and kept.

import CoreGraphics
import Foundation
import MKArrange
import MKFoundation
import MKModel
import MKPersistence
import MKTextEngine

// MARK: - DTOs

struct ArrangeProvenanceDTO: Encodable {
    var clusterOrdinal: Int
    var codepoints: [UInt32]
    var utf16Start: Int
    var utf16Length: Int
    var bidiLevel: UInt8
    var visualIndex: Int
    var logicalIndex: Int
    var cursiveAttached: Bool

    init(_ p: MKProvenance, clusterOrdinals: [MKClusterID: Int]) {
        clusterOrdinal = clusterOrdinals[p.clusterID] ?? -1
        codepoints = p.codepoints
        utf16Start = p.utf16Start
        utf16Length = p.utf16Length
        bidiLevel = p.bidiLevel
        visualIndex = p.visualIndex
        logicalIndex = p.logicalIndex
        cursiveAttached = p.cursiveAttached
    }
}

struct ArrangeGlyphNodeDTO: Encodable {
    var ordinal: Int
    var glyph: MKGlyphRef
    var hasOutline: Bool
    var layout: MKGlyphLayout
    var transform: MKTransform2D
    var style: MKStyle
    var provenance: ArrangeProvenanceDTO
    var joining: MKJoiningState
    var isHidden: Bool
    var isLocked: Bool

    init(ordinal: Int, node: MKGlyphNode, clusterOrdinals: [MKClusterID: Int]) {
        self.ordinal = ordinal
        glyph = node.glyph
        hasOutline = node.outline != nil
        layout = node.layout
        transform = node.transform
        style = node.style
        provenance = ArrangeProvenanceDTO(node.provenance, clusterOrdinals: clusterOrdinals)
        joining = node.joining
        isHidden = node.isHidden
        isLocked = node.isLocked
    }
}

struct ArrangeMarkNodeDTO: Encodable {
    var ordinal: Int
    var glyph: MKGlyphRef
    var hasOutline: Bool
    var attachedToOrdinal: Int?
    var relativeOffset: CGSize
    var followsBase: Bool
    var transform: MKTransform2D
    var style: MKStyle
    var provenance: ArrangeProvenanceDTO
    var markClass: MKMarkClass
    var stackIndex: Int
    var isHidden: Bool
    var isLocked: Bool

    init(ordinal: Int, node: MKMarkNode, clusterOrdinals: [MKClusterID: Int], topLevelOrdinals: [MKNodeID: Int]) {
        self.ordinal = ordinal
        glyph = node.glyph
        hasOutline = node.outline != nil
        attachedToOrdinal = node.attachedTo.flatMap { topLevelOrdinals[$0] }
        relativeOffset = node.relativeOffset
        followsBase = node.followsBase
        transform = node.transform
        style = node.style
        provenance = ArrangeProvenanceDTO(node.provenance, clusterOrdinals: clusterOrdinals)
        markClass = node.markClass
        stackIndex = node.stackIndex
        isHidden = node.isHidden
        isLocked = node.isLocked
    }
}

struct ArrangeComposedLigatureDTO: Encodable {
    var glyph: MKGlyphRef
    var hasOutline: Bool
    var layout: MKGlyphLayout
    var decomposable: Bool
    init(_ c: MKComposedLigature) {
        glyph = c.glyph; hasOutline = c.outline != nil; layout = c.layout; decomposable = c.decomposable
    }
}

struct ArrangeDecomposedLigatureDTO: Encodable {
    var components: [ArrangeGlyphNodeDTO]
    var fidelityMode: MKFidelityMode
    var original: ArrangeComposedLigatureDTO
}

struct ArrangeLigatureStateDTO: Encodable {
    var kind: String   // "composed" | "decomposed"
    var composed: ArrangeComposedLigatureDTO?
    var decomposed: ArrangeDecomposedLigatureDTO?
}

struct ArrangeLigatureGroupDTO: Encodable {
    var ordinal: Int
    var state: ArrangeLigatureStateDTO
    var provenance: ArrangeProvenanceDTO
    var transform: MKTransform2D
    var style: MKStyle
    var attachedMarkOrdinals: [Int]
    var isHidden: Bool
    var isLocked: Bool
}

struct ArrangeChildDTO: Encodable {
    var ordinal: Int
    var kind: String   // "glyph" | "mark" | "ligature"
    var glyph: ArrangeGlyphNodeDTO?
    var mark: ArrangeMarkNodeDTO?
    var ligature: ArrangeLigatureGroupDTO?
}

struct ArrangeFixtureDTO: Encodable {
    var fixtureName: String
    var nodeIndexInScene: Int
    var sourceString: String
    var sourceContentHash: String
    var originFrame: CGRect
    var nodeCount: Int
    var nodes: [ArrangeChildDTO]
}

// MARK: - Export

/// Derives `text`/`style` via `ArrangeDeriver` and builds the DTO tree
/// (shared by the fixture-scene sweep and the corpus sweep below).
private func deriveFixtureDTO(
    fixtureName: String, nodeIndexInScene: Int, text: String, style: MKTextStyle,
    paintStyle: MKStyle, fonts: any MKFontProviding
) async -> ArrangeFixtureDTO {
    let service = MKShapingService(fonts: fonts)
    let capture = await service.captureResult(MKShapingRequest(string: text, style: style))
    let clusterOrdinals = clusterOrdinalMap(capture.paragraph)
    let composition = await ArrangeDeriver(fonts: fonts).derive(
        sourceText: text, style: style, capture: capture, paintStyle: paintStyle)

    let topLevelOrdinals = nodeOrdinalMap(composition)
    var childDTOs: [ArrangeChildDTO] = []
    for (ordinal, child) in composition.nodes.enumerated() {
        switch child {
        case .glyph(let g):
            childDTOs.append(ArrangeChildDTO(
                ordinal: ordinal, kind: "glyph",
                glyph: ArrangeGlyphNodeDTO(ordinal: ordinal, node: g, clusterOrdinals: clusterOrdinals),
                mark: nil, ligature: nil))
        case .mark(let m):
            childDTOs.append(ArrangeChildDTO(
                ordinal: ordinal, kind: "mark", glyph: nil,
                mark: ArrangeMarkNodeDTO(ordinal: ordinal, node: m, clusterOrdinals: clusterOrdinals, topLevelOrdinals: topLevelOrdinals),
                ligature: nil))
        case .ligature(let l):
            let stateDTO: ArrangeLigatureStateDTO
            switch l.state {
            case .composed(let c):
                stateDTO = ArrangeLigatureStateDTO(kind: "composed", composed: ArrangeComposedLigatureDTO(c), decomposed: nil)
            case .decomposed(let d):
                let componentDTOs = d.components.enumerated().map { ArrangeGlyphNodeDTO(ordinal: $0.offset, node: $0.element, clusterOrdinals: clusterOrdinals) }
                stateDTO = ArrangeLigatureStateDTO(
                    kind: "decomposed", composed: nil,
                    decomposed: ArrangeDecomposedLigatureDTO(components: componentDTOs, fidelityMode: d.fidelityMode, original: ArrangeComposedLigatureDTO(d.original)))
            }
            childDTOs.append(ArrangeChildDTO(
                ordinal: ordinal, kind: "ligature", glyph: nil, mark: nil,
                ligature: ArrangeLigatureGroupDTO(
                    ordinal: ordinal, state: stateDTO,
                    provenance: ArrangeProvenanceDTO(l.provenance, clusterOrdinals: clusterOrdinals),
                    transform: l.transform, style: l.style,
                    attachedMarkOrdinals: l.attachedMarks.compactMap { topLevelOrdinals[$0] },
                    isHidden: l.isHidden, isLocked: l.isLocked)))
        }
    }

    return ArrangeFixtureDTO(
        fixtureName: fixtureName, nodeIndexInScene: nodeIndexInScene, sourceString: composition.sourceBackup.sourceString,
        sourceContentHash: composition.sourceBackup.contentHash, originFrame: composition.originFrame,
        nodeCount: composition.nodes.count, nodes: childDTOs)
}

func exportArrange() async throws {
    let categoryRoot = RepoPaths.fixturesRoot.appendingPathComponent("arrange")
    let systemFonts = SystemFontStubProvider()
    var fileCount = 0
    var derivedNodeCount = 0

    // (1) The 4 canonical `Tests/Fixtures/*.makhtoot` scenes (port map task
    // 5) — only `fixture-arabic-basic` actually contains a `.liveText` node
    // to derive from; `fixture-100/5000-nodes` are shape-only perf fixtures
    // and `fixture-arranged-la` is already `.arranged` (nothing to
    // re-derive). Verified directly against the checked-in files, not
    // assumed — see `android/docs/impl-log/BATCH-0.2.md`.
    for fixtureName in fixtureNames {
        let scene = try FixtureSceneLoader.loadScene(named: fixtureName)
        let fixtureDir = categoryRoot.appendingPathComponent(fixtureName)
        for (nodeIndex, node) in scene.nodes.enumerated() {
            guard case .liveText(let liveNode) = node else { continue }
            let dto = await deriveFixtureDTO(
                fixtureName: fixtureName, nodeIndexInScene: nodeIndex, text: liveNode.text.string,
                style: liveNode.style, paintStyle: liveNode.core.style, fonts: systemFonts)
            try GoldenJSON.write(dto, to: fixtureDir.appendingPathComponent("node-\(nodeIndex).json"))
            fileCount += 1
            derivedNodeCount += dto.nodeCount
        }
    }

    // (2) Corpus sweep (F-1..F-12) across a small representative font set —
    // the single bundled scene above only exercises one font/one string;
    // Batch 4's arrange-porting agents need derivation coverage across the
    // full canonical corpus (ligatures, marks, mixed bidi, tashkeel-only,
    // tatweel) the way the shaping/ligature/marks categories already give
    // them. `amiri` and `noto-naskh-arabic` are well-attested real Arabic
    // text faces (used elsewhere in this repo's own test suite for the
    // same reason); the system stub font stands in for the "no font
    // registry yet" baseline case.
    let representativeFamilyIDs = ["amiri", "noto-naskh-arabic"]
    let families = FontCatalog.discoverFamilies().filter { representativeFamilyIDs.contains($0.familyID) }
    for family in families {
        guard let ps = FontCatalog.registerAndResolvePostScriptName(family) else {
            print("[arrange] WARNING: could not resolve PostScript name for \(family.familyID) — skipped")
            continue
        }
        let fonts = NamedFontProvider(postScriptName: ps)
        let style = MKTextStyle(font: .system(postScriptName: ps), pointSize: 36, lineHeightMultiple: 1.2)
        let corpusDir = categoryRoot.appendingPathComponent("corpus-\(family.familyID)")
        for fixture in Corpus.fixtures {
            let dto = await deriveFixtureDTO(
                fixtureName: "corpus-\(family.familyID)", nodeIndexInScene: 0, text: fixture.string,
                style: style, paintStyle: MKStyle(fill: .solid(.defaultInk)), fonts: fonts)
            try GoldenJSON.write(dto, to: corpusDir.appendingPathComponent("\(fixture.id).json"))
            fileCount += 1
            derivedNodeCount += dto.nodeCount
        }
    }

    print("[arrange] wrote \(fileCount) fixture files (\(derivedNodeCount) derived children total): \(fixtureNames.count) source scenes + \(families.count)-family × \(Corpus.fixtures.count)-corpus sweep")
}
