// Work item 0.2 — category `assets/` (spine §10 correction, same
// status as `canvas/` — see that file's header for the "no packet row
// names this explicitly, judgment call logged" note). `ANDROID_TASK_PACKETS/
// BATCH-5.md` cites `android/fixtures/assets/**` twice as "manifest
// goldens" (Agent 5.5a) and "provenance/thumbnail goldens" (Agent 5.5b) —
// this category is scoped to exactly those two things, kept distinct from
// `android/fixtures/resources/**` (work item 0.4, verbatim copies of the raw
// `assets-manifest.json`/`provenance-records.json` source files
// themselves): this category instead EXERCISES code — real deterministic
// thumbnail rendering (`MKSnapshotRenderer.renderThumbnail`, the same
// pipeline `MKPersistence`'s own thumbnail path uses) and a per-node asset-
// reference inventory — over the 4 canonical fixture scenes, so Batch
// 5.5a/5.5b have something to diff their OWN thumbnail/manifest-reading
// logic against, not just a copy of the input JSON.
//
// Output: `android/fixtures/assets/<fixture-name>.thumbnail.png` (512px
// long edge, matching `MKSnapshotRenderer.renderThumbnail`'s own default)
// + `android/fixtures/assets/<fixture-name>.manifest.json` (per-node asset-
// reference inventory: node id, kind, `MKAssetRef.digest`/`.ext` for any
// `.image` node).

import CoreGraphics
import Foundation
import MKExport
import MKFoundation
import MKModel
import MKRender

struct AssetReferenceDTO: Encodable {
    var nodeID: String
    var nodeKind: String
    var assetDigest: String?
    var assetExt: String?
    var imageKind: String?
}

struct AssetsManifestFixtureDTO: Encodable {
    var fixtureName: String
    var nodeCount: Int
    var imageNodeCount: Int
    var assetReferences: [AssetReferenceDTO]
}

func exportAssets() throws {
    let categoryRoot = RepoPaths.fixturesRoot.appendingPathComponent("assets")
    RepoPaths.ensure(categoryRoot)
    let renderer = MKSnapshotRenderer()
    var count = 0

    for fixtureName in fixtureNames {
        let scene = try FixtureSceneLoader.loadScene(named: fixtureName)

        // Thumbnail golden — deterministic (same renderer/inputs as
        // `render/`'s full-canvas PNGs, just a smaller long edge).
        if let thumbnail = renderer.renderThumbnail(scene, longEdge: 512) {
            let url = categoryRoot.appendingPathComponent("\(fixtureName).thumbnail.png")
            try MKRasterEncoders.writePNG(thumbnail, to: url, dpi: 144)
            count += 1
        } else {
            print("[assets] WARNING: \(fixtureName) produced no thumbnail (degenerate canvas size \(scene.canvas.size)) — skipped")
        }

        // Manifest golden — per-node asset-reference inventory.
        var refs: [AssetReferenceDTO] = []
        var imageCount = 0
        for node in scene.nodes {
            if case .image(let imageNode) = node {
                imageCount += 1
                refs.append(AssetReferenceDTO(
                    nodeID: node.id.description, nodeKind: "image",
                    assetDigest: imageNode.asset.digest, assetExt: imageNode.asset.ext,
                    imageKind: imageNode.kind.rawValue))
            } else {
                refs.append(AssetReferenceDTO(nodeID: node.id.description, nodeKind: kindTagAssets(node), assetDigest: nil, assetExt: nil, imageKind: nil))
            }
        }
        let manifestDTO = AssetsManifestFixtureDTO(fixtureName: fixtureName, nodeCount: scene.nodes.count, imageNodeCount: imageCount, assetReferences: refs)
        try GoldenJSON.write(manifestDTO, to: categoryRoot.appendingPathComponent("\(fixtureName).manifest.json"))
        count += 1
    }
    print("[assets] wrote \(count) files (thumbnail + manifest per fixture) across \(fixtureNames.count) fixtures")
}

private func kindTagAssets(_ node: MKNode) -> String {
    switch node {
    case .group: return "group"
    case .liveText: return "liveText"
    case .pathText: return "pathText"
    case .arranged: return "arranged"
    case .shape: return "shape"
    case .image: return "image"
    case .background: return "background"
    }
}
