import CoreGraphics
import Foundation
import MKFoundation
import MKModel

// WS-14 packet §5 tasks 3/8. Pattern-background instantiation.
//
// **`MKModel` schema-gap note (documented, not silently worked around).**
// The packet's task 3 literally asks for pattern backgrounds to become "a
// `.background` node with pattern fill." The shipped `MKModel` schema's
// `MKBackgroundContent` enum has exactly two cases ، `.solid(MKSolidColor)`
// and `.image(MKAssetRef)` ، verified by reading `Sources/MKModel/
// MKNode.swift`; there is NO pattern case. Adding one
// (`case pattern(MKPatternFillRef)` or similar) is a `MKModel` schema
// change outside this run's fence (`MKAssets` only). Rather than block on
// that or silently misuse `.image(MKAssetRef)` (which is a
// content-addressed reference into `MKPersistence`'s persisted `assets/`
// store ، using it here would require writing raster/vector bytes into a
// document's asset store, `MKPersistence` territory, not self-contained,
// and not vector), this instantiator realizes a pattern background TODAY
// as a `.group` node of real, individually-inlined `.shape(.path(...))`
// tile instances covering the canvas ، vector, self-contained (every tile's
// FULL path data is inline, same as any other placed asset), and drawn by
// the ALREADY-SHIPPED `MKRender.ShapeDrawer`/`GroupDrawer` with zero new
// renderer work. `MKPatternBackgroundTests` verifies this literally
// "renders tiled" (tile count scales with canvas size; tiles cover the
// full canvas rect at 3 sizes, per the packet's own T-asset-05 AC wording).
//
// **Consequence for a future SVG `<pattern>` writer (WS-08 coordination
// note, packet task 8's own ask):** because this v1 realization is already
// flat repeated shapes rather than a semantic "this is one pattern"
// node, `MKExport`'s SVG serializer needs NO pattern-specific code at all ،
// each tile shape serializes as its own ordinary `<path>`, exactly like any
// other shape node. This is simpler than the packet's own `<pattern>`+`<use>`
// framing, at the cost of a larger SVG file for big canvases (documented
// tradeoff, not a defect ، vector `<path>` count scales with tile count,
// same as the canvas's own rendered tile count).
public struct MKPatternInstantiator: Sendable {
    public init() {}

    public struct Placement: Sendable {
        public let node: MKNode
        public let record: MKPlacementRecord
    }

    /// Tiles `fill`'s motif across `canvasSize`, painting `fill
    /// .backgroundColor` behind it and `fill.motifColor` for every tile
    /// instance. `descriptor` must be the `.patternBackgrounds` asset this
    /// `fill` belongs to (used for the placement record + Arabic naming).
    public func placeBackground(_ descriptor: MKAssetDescriptor, fill: MKPatternFill, canvasSize: CGSize) -> Placement {
        precondition(descriptor.category == .patternBackgrounds, "placeBackground is for .patternBackgrounds assets only")
        precondition(canvasSize.width > 0 && canvasSize.height > 0, "canvasSize must be positive")

        let tileSize = fill.tile.tileSize
        let pathData = fill.tile.geometry.toPathData()
        let motifStyle = MKStyle(fill: .solid(fill.motifColor))

        let columns = max(1, Int(ceil(canvasSize.width / tileSize.width))) + 1
        let rows = max(1, Int(ceil(canvasSize.height / tileSize.height))) + 1

        var tiles: [MKNode] = []
        tiles.reserveCapacity(columns * rows)
        for row in 0..<rows {
            for col in 0..<columns {
                var x = Double(col) * tileSize.width
                if fill.repeatMode == .halfDrop, row.isMultiple(of: 2) == false {
                    x += tileSize.width / 2
                }
                let y = Double(row) * tileSize.height
                let center = CGPoint(x: x + tileSize.width / 2, y: y + tileSize.height / 2)
                let core = MKNodeCore(
                    name: descriptor.nameAr, transform: MKTransform2D(position: center, rotation: 0, scale: CGSize(width: 1, height: 1)), style: motifStyle
                )
                tiles.append(.shape(MKShapeNode(core: core, geometry: .path(pathData))))
            }
        }

        let backgroundStyle = MKStyle(fill: .solid(fill.backgroundColor))
        let backgroundCore = MKNodeCore(
            name: "خلفية النمط", transform: MKTransform2D(position: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2), rotation: 0, scale: canvasSize),
            style: backgroundStyle
        )
        let backgroundRect = MKNode.shape(MKShapeNode(core: backgroundCore, geometry: .rect(cornerRadius: 0)))

        let groupCore = MKNodeCore(name: descriptor.nameAr)
        let groupNode = MKNode.group(MKGroupNode(core: groupCore, children: [backgroundRect] + tiles))
        let record = MKPlacementRecord(nodeID: groupNode.id, assetID: descriptor.assetID, category: .patternBackgrounds, isPremium: true, nameAr: descriptor.nameAr)
        return Placement(node: groupNode, record: record)
    }
}
