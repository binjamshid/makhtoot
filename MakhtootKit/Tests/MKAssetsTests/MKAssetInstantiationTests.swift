import CoreGraphics
import Foundation
import MKModel
import Testing
@testable import MKAssets

// WS-14 packet §5 task 3 accept criteria: "placed asset round-trips through
// scene Codable; document opens correctly with the asset id stripped
// (fallback to inline path proven by test); node behaves as plain shape to
// MKModel consumers."
@Suite("MKAssetInstantiator (T3, self-containment)")
struct MKAssetInstantiationTests {
    private let instantiator = MKAssetInstantiator()

    @Test func placingAShapeProducesAShapeNodeNamedTheArabicName() {
        let ornament = MKAssetLibrary.standard.descriptor(assetID: "ornament.star-rosette-8")!
        let placement = instantiator.place(ornament)
        guard case .shape(let shapeNode) = placement.node else {
            Issue.record("expected a .shape node")
            return
        }
        #expect(shapeNode.core.name == "خاتم")
        guard case .path(let pathData) = shapeNode.geometry else {
            Issue.record("expected .path geometry")
            return
        }
        #expect(!pathData.commands.isEmpty)
    }

    @Test func placementRecordCarriesAssetMetadata() {
        let ornament = MKAssetLibrary.standard.descriptor(assetID: "ornament.star-rosette-8")!
        let placement = instantiator.place(ornament)
        #expect(placement.record.assetID == "ornament.star-rosette-8")
        #expect(placement.record.category == .ornaments)
        #expect(placement.record.isPremium == false)
        #expect(placement.record.nodeID == placement.node.id)
    }

    @Test func placedNodeRoundTripsThroughSceneCodable() throws {
        let asset = MKAssetLibrary.standard.descriptor(assetID: "shape.star-8")!
        let placement = instantiator.place(asset, at: CGPoint(x: 100, y: 200))
        var scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 1000, height: 1000)))
        scene = scene.inserting(placement.node)

        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(MKScene.self, from: data)

        #expect(decoded.nodes.count == 1)
        #expect(decoded.node(id: placement.node.id) == placement.node)
    }

    /// The literal "asset id stripped" proof: nothing anywhere in the
    /// encoded scene JSON references `asset.assetID` at all ، there is no
    /// assetID string embedded in the node to strip in the first place
    /// (see `MKAssetInstantiator`'s file header, "MKModel coordination
    /// note"), so decoding succeeds and the shape renders identically with
    /// or without ANY knowledge of `MKAssets` ever having existed.
    @Test func decodedSceneContainsNoReferenceToTheSourceAssetID() throws {
        let asset = MKAssetLibrary.standard.descriptor(assetID: "ornament.mandorla-lozenge-medallion")!
        let placement = instantiator.place(asset)
        var scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 500, height: 500)))
        scene = scene.inserting(placement.node)

        let data = try JSONEncoder().encode(scene)
        let json = String(data: data, encoding: .utf8)!
        #expect(!json.contains(asset.assetID))

        // Decoding needs nothing beyond MKModel's own Codable ، no MKAssets
        // lookups, no asset-id resolution step.
        let decoded = try JSONDecoder().decode(MKScene.self, from: data)
        guard case .shape(let shapeNode) = decoded.nodes[0], case .path(let pathData) = shapeNode.geometry else {
            Issue.record("expected a decoded .shape(.path) node")
            return
        }
        let originalPathData = asset.pathData.toPathData()
        #expect(pathData.commands == originalPathData.commands)
    }

    @Test func placedNodeBehavesAsAnOrdinaryShapeToSceneTreeOperations() {
        let asset = MKAssetLibrary.standard.descriptor(assetID: "frame.circular")!
        let placement = instantiator.place(asset)
        var scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 400, height: 400)))
        scene = scene.inserting(placement.node)

        // Ordinary MKScene tree operations (transform update, removal) work
        // with zero MKAssets awareness.
        scene = scene.updatingNode(id: placement.node.id) { node in
            if case .shape(var shape) = node {
                shape.core.transform.rotation = .pi / 4
                node = .shape(shape)
            }
        }
        guard case .shape(let rotated) = scene.node(id: placement.node.id)! else {
            Issue.record("expected shape node")
            return
        }
        #expect(rotated.core.transform.rotation == .pi / 4)

        scene = scene.removing(id: placement.node.id)
        #expect(scene.node(id: placement.node.id) == nil)
    }

    @Test func geometryProducesAValidNonEmptyCGPath() {
        for descriptor in MKAssetLibrary.standard.all where descriptor.category != .patternBackgrounds {
            let path = descriptor.pathData.cgPath()
            #expect(!path.isEmpty, "\(descriptor.assetID) produced an empty CGPath")
        }
    }
}
