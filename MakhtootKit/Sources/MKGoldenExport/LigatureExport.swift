// Work item 0.2 — category (c): ligature. Two sub-parts per family:
// (1) detect — `MKLigatureDetector.detect` over the corpus fixtures that
//     actually contain a lam-alif family pair (F-1 لا, F-2 الله, F-7a/b,
//     F-9, F-12), classifying required/discretionary/contextual;
// (2) decompose/recompose — `LigatureDecomposer`, same لا-ligature pattern
//     `PerFontArrangeFidelitySweepTests` already established for real-font
//     sweeps (Tests/MKArrangeTests/PerFontArrangeFidelitySweepTests.swift),
//     reused here rather than re-derived.
//
// Output: `android/fixtures/ligature/<familyID>/<case-id>.json`.
//
// Determinism note (see Support.swift header): `MKDetectedLigature.clusterID`
// and every id inside `LigatureDecomposer.DecomposeResult.group` are freshly
// random per shaping/derivation call. This exporter drops the raw
// `clusterID` (keeping only `clusterOrdinal`, which `MKDetectedLigature`
// already provides as a plain `Int`) and represents decompose/recompose
// component identity by ARRAY POSITION, never by the source type's own
// `MKNodeID`.

import CoreGraphics
import CoreText
import Foundation
import MKArrange
import MKFoundation
import MKModel
import MKTextEngine

// MARK: - Detect DTOs

struct DetectedLigatureDTO: Encodable {
    var clusterOrdinal: Int
    var glyph: GlyphAddressDTO
    var constituentScalars: [UInt32]
    var kind: String
    var activeSetting: String

    init(_ l: MKDetectedLigature) {
        clusterOrdinal = l.clusterOrdinal
        glyph = GlyphAddressDTO(l.glyph)
        constituentScalars = l.constituentScalars
        switch l.kind {
        case .required: kind = "required"
        case .discretionary: kind = "discretionary"
        case .contextual: kind = "contextual"
        }
        activeSetting = l.activeSetting.rawValue
    }
}

struct LigatureDetectFixtureDTO: Encodable {
    var corpusID: String
    var familyID: String
    var postScriptName: String
    var sourceText: String
    var activeSetting: String
    var detected: [DetectedLigatureDTO]
}

// MARK: - Decompose/recompose DTOs

struct GlyphNodeMiniDTO: Encodable {
    var ordinal: Int
    var glyph: MKGlyphRef
    var layout: MKGlyphLayout
    var joining: MKJoiningState
    init(ordinal: Int, node: MKGlyphNode) {
        self.ordinal = ordinal
        glyph = node.glyph
        layout = node.layout
        joining = node.joining
    }
}

struct DecomposeRecomposeFixtureDTO: Encodable {
    var corpusID: String
    var familyID: String
    var postScriptName: String
    var sourceText: String
    var fusedIntoOneCluster: Bool
    var decomposable: Bool?
    var naturalScaleFactor: Double?
    var fidelityAutoRefused: Bool?
    var fidelityMode: String?
    var componentCount: Int?
    var components: [GlyphNodeMiniDTO]?
    var recomposeRoundTripsExactly: Bool?
}

// Corpus fixtures that actually exercise a lam+alef-family adjacency
// (`MKLigatureDetector.classify`'s own rule) — the meaningful subset for a
// ligature-focused golden set, per this agent's port map (category c).
private let ligatureCorpusIDs: Set<String> = ["F-1", "F-2", "F-7a", "F-7b", "F-9", "F-12"]

func exportLigature() async throws {
    let families = FontCatalog.discoverFamilies()
    let categoryRoot = RepoPaths.fixturesRoot.appendingPathComponent("ligature")
    let ligatureFixtures = Corpus.fixtures.filter { ligatureCorpusIDs.contains($0.id) }

    var detectCount = 0
    var decomposeCount = 0
    for family in families {
        guard let ps = FontCatalog.registerAndResolvePostScriptName(family) else {
            print("[ligature] WARNING: could not resolve PostScript name for \(family.familyID) — skipped")
            continue
        }
        let fonts = NamedFontProvider(postScriptName: ps)
        let engine = MKShapingEngine(fonts: fonts)
        let familyDir = categoryRoot.appendingPathComponent(family.familyID)
        let style = MKTextStyle(font: .system(postScriptName: ps), pointSize: 36, lineHeightMultiple: 1.2)

        // (1) Detect, over every ligature-relevant corpus fixture.
        for fixture in ligatureFixtures {
            let line = engine.shapeSingleLine(MKShapingRequest(string: fixture.string, style: style))
            let detected = MKLigatureDetector.detect(in: line, activeSetting: style.ligatureSetting)
            let dto = LigatureDetectFixtureDTO(
                corpusID: fixture.id, familyID: family.familyID, postScriptName: ps,
                sourceText: fixture.string, activeSetting: style.ligatureSetting.rawValue,
                detected: detected.map(DetectedLigatureDTO.init))
            try GoldenJSON.write(dto, to: familyDir.appendingPathComponent("detect-\(fixture.id).json"))
            detectCount += 1
        }

        // (2) Decompose/recompose — لا (F-1), same pattern as
        // PerFontArrangeFidelitySweepTests. `MKShapingCaptureResult.lineAnalyses`
        // must be populated (via `MKShapingService`, not hand-built) —
        // `ArrangeDeriver.derive` indexes `capture.lineAnalyses[lineIndex]`
        // directly and a hand-built empty array crashes.
        let text = "لا"
        let service = MKShapingService(fonts: fonts)
        let capture = await service.captureResult(MKShapingRequest(string: text, style: style))
        let composition = await ArrangeDeriver(fonts: fonts).derive(sourceText: text, style: style, capture: capture)
        let ligatureGroup = composition.nodes.compactMap { child -> MKLigatureGroup? in
            if case .ligature(let l) = child { return l }
            return nil
        }.first

        var dto = DecomposeRecomposeFixtureDTO(
            corpusID: "F-1", familyID: family.familyID, postScriptName: ps, sourceText: text,
            fusedIntoOneCluster: ligatureGroup != nil)

        if let group = ligatureGroup, case .composed(let composed) = group.state, composed.decomposable {
            let decomposer = LigatureDecomposer(fonts: fonts)
            do {
                let result = try await decomposer.decompose(group, sourceString: text, style: style, options: .fidelityDefault)
                if case .decomposed(let decomposed) = result.group.state {
                    dto.decomposable = true
                    dto.naturalScaleFactor = Double(result.naturalScaleFactor)
                    dto.fidelityAutoRefused = result.fidelityAutoRefused
                    dto.fidelityMode = decomposed.fidelityMode.rawValue
                    dto.componentCount = decomposed.components.count
                    dto.components = decomposed.components.enumerated().map { GlyphNodeMiniDTO(ordinal: $0.offset, node: $0.element) }
                    let recomposed = try decomposer.recompose(result.group, force: false)
                    dto.recomposeRoundTripsExactly = (recomposed.state == group.state)
                }
            } catch {
                print("[ligature] \(family.familyID): decompose threw \(error) — recorded as decomposable=false")
                dto.decomposable = false
            }
        } else {
            dto.decomposable = false
        }
        try GoldenJSON.write(dto, to: familyDir.appendingPathComponent("decompose-recompose-F-1.json"))
        decomposeCount += 1
    }
    print("[ligature] wrote \(detectCount) detect files + \(decomposeCount) decompose/recompose files")
}
