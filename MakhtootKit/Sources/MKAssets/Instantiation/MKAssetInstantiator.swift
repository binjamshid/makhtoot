import CoreGraphics
import Foundation
import MKFoundation
import MKModel

// WS-14 packet §5 task 3. `MKAssetInstantiator.place(asset:) -> MKNode`.
//
// Serialization strategy (packet task 3, "the decisive design note"):
// placed nodes embed the FULL path data in `scene.json` ، self-contained
// documents, a `.makhtoot` file must render on a device/app-version lacking
// that asset id. This is achieved here by construction: `place(asset:)`
// returns a plain `.shape(MKShapeNode(geometry: .path(MKPathData)))` node
// with the ENTIRE geometry inlined (`MKAssetGeometry.toPathData()`) ، the
// SAME `MKPathData` type + `MKModel.Codable`/`MKRender.ShapeDrawer` path
// every other shape node already uses (verified by reading `Sources/
// MKRender/Drawers/ShapeDrawer.swift`: `.path(let pathData):
// pathData.cgPath(at: pathData.unitsPerEm)` ، no `MKAssets` dependency
// needed for a placed asset to render, today, with the already-shipped
// renderer). Because the node carries zero reference back to `MKAssets`,
// "document opens correctly with the asset id stripped" is trivially and
// permanently true ، there is no assetID anywhere IN the node to strip.
//
// **MKModel coordination note (assetID dedup/re-link ، NOT applied this
// session, fence conflict, logged per the WS02-A7/WS-06↔WS-07 precedent).**
// The packet's task 3 ALSO asks for "assetID provenance attribute for
// future dedup/re-link" living on the placed node itself. The shipped
// `MKModel` schema (`MKNodeCore`, `MKShapeNode`, `MKShapeGeometry`) has no
// generic metadata slot for this ، `MKNodeCore.name` is already spoken for
// (`= nameAr`, task 3's own requirement), and `MKShapeGeometry.asset
// (MKAssetRef)` is a DIFFERENT, unsuitable case: `MKAssetRef` is a
// content-addressed digest+ext into the document's persisted `assets/`
// store (`MKPersistence.MKAssetStore`), and `MKRender.ShapeDrawer`'s own
// `.asset` case is a documented no-op today (`report.recordSubstitution
// (kind: .missingAsset, detail: "shape geometry .asset needs
// MKAssetVectorProgram (WS-14, not yet built)")`) ، using it would make
// every placed asset invisible until a real `MKAssetVectorProgram` lands,
// the opposite of self-containment. This run's fence is `MKAssets sources/
// tests/resources` only (no other module sources), so the clean fix ،
// adding one field ، is out of scope THIS session. Proposed, ready-to-apply
// addition for whoever next has `MKModel` in their fence:
//
//     // MKNode.swift, on MKNodeCore (shared by every node kind, since
//     // asset placement can in principle mark a shape OR a background):
//     public var sourceAssetID: String?   // Codable, defaults nil, additive
//
// Until that lands, dedup/re-link and premium-content-scene-reconstruction
// (T13) both go through the CALLER-held `MKPlacementRecord`/
// `MKPremiumContentLedger` this file and `MKPremiumContentLedger.swift`
// provide ، real, tested, and exactly the seam a future document-session
// integration would drive; only "reconstruct which placed nodes were
// premium assets from a REOPENED scene.json alone, with no ledger" needs
// the `MKModel` field above.
public struct MKAssetInstantiator: Sendable {
    public init() {}

    /// Placement result: the ready-to-insert scene node, plus a
    /// caller-held record of WHICH asset produced it (assetID, category,
    /// premium flag, Arabic name) for dedup/re-link and premium-content
    /// bookkeeping (`MKPremiumContentLedger`) until the `MKModel`
    /// coordination note above lands.
    public struct Placement: Sendable {
        public let node: MKNode
        public let record: MKPlacementRecord
    }

    /// Places `asset` as a scene node at `position` (canvas points,
    /// default the origin ، callers typically pass the current viewport
    /// center; WS-13's browser panel owns that policy) with `scale`
    /// (default identity ، the asset's authored `localBounds` size is its
    /// on-canvas footprint at scale 1, per `MKAssetUnits`'s convention).
    ///
    /// `basicShapes`/`ornaments`/`frames`/`calligraphicElements` → `.shape`
    /// node with the FULL inline path + a theme-aware default fill (T3:
    /// "theme-aware default fill from MKDesignSystem ink color" ، realized
    /// via `MKModel.MKSolidColor.defaultInk`, the MKModel-layer default
    /// ADR'd exactly for this purpose so `MKAssets` never needs a
    /// `MKDesignSystem` dependency edge FOUNDATION §2 does not grant it).
    ///
    /// `patternBackgrounds` are NOT handled here ، see
    /// `MKPatternInstantiator.placeBackground(assetID:canvasSize:)`
    /// (that file's header explains the `.background`-node schema gap).
    public func place(_ asset: MKAssetDescriptor, at position: CGPoint = .zero, scale: CGSize = CGSize(width: 1, height: 1)) -> Placement {
        precondition(asset.category != .patternBackgrounds, "pattern backgrounds instantiate via MKPatternInstantiator, not MKAssetInstantiator")
        let pathData = asset.pathData.toPathData()
        let style = MKStyle(fill: .solid(.defaultInk))
        let core = MKNodeCore(name: asset.nameAr, transform: MKTransform2D(position: position, rotation: 0, scale: scale), style: style)
        let shapeNode = MKShapeNode(core: core, geometry: .path(pathData))
        let node = MKNode.shape(shapeNode)
        let record = MKPlacementRecord(nodeID: node.id, assetID: asset.assetID, category: asset.category, isPremium: asset.isPremium, nameAr: asset.nameAr)
        return Placement(node: node, record: record)
    }
}

/// Caller-held join between a placed `MKNode` and the `MKAssetDescriptor`
/// that produced it ، see `MKAssetInstantiator`'s file header ("MKModel
/// coordination note") for exactly why this lives outside the node itself
/// in v1.
public struct MKPlacementRecord: Hashable, Sendable, Equatable {
    public var nodeID: MKNodeID
    public var assetID: String
    public var category: MKAssetCategory
    public var isPremium: Bool
    public var nameAr: String

    public init(nodeID: MKNodeID, assetID: String, category: MKAssetCategory, isPremium: Bool, nameAr: String) {
        self.nodeID = nodeID
        self.assetID = assetID
        self.category = category
        self.isPremium = isPremium
        self.nameAr = nameAr
    }
}
