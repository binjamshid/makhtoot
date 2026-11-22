// Work item 0.2 — category `canvas/` (spine §10 correction: a new
// category the BATCH-0.md ownership appendix predates and omits, but which
// this agent owns per the spine-wins rule stated in this agent's own
// dispatch). No Batch 0 packet reads/port-map row names this category
// explicitly (it postdates the packet text this agent was handed), so its
// fixture scope is documented here and
// in the impl log rather than left unproduced.
//
// Scope chosen: `MKRender.HitTester` geometry over the 4 canonical fixture
// scenes — `worldGeometry(of:in:)` (local bounds + world transform) and
// `containsPrecise(nodeID:worldPoint:in:)` at deterministic sample points
// (node center + 4 corners) for every top-level node, plus `allHits(at:in:)`
// at the canvas center. Batch 5.1's own port map (`ANDROID_TASK_PACKETS/
// BATCH-5.md`, `Geometry/MKCanvasGeometrySource.swift` row) names exactly
// these two `HitTester` entry points as what `MkCanvasGeometrySource`
// adapts, so this is the concrete, load-bearing subset of "canvas fixture"
// content that agent's own port map already implies it needs.
//
// Node ids here are the REAL, on-disk `MKNodeID` values from the checked-in
// fixture `scene.json` files — deterministic across runs because they come
// from a static, committed file (decode restores the persisted UUID
// exactly), unlike the freshly-derived ids the `arrange`/`ligature`/
// `pathtext` categories must ordinal-remap (Support.swift header).

import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKRender

struct WorldGeometryDTO: Encodable {
    var localBoundsX: CGFloat
    var localBoundsY: CGFloat
    var localBoundsWidth: CGFloat
    var localBoundsHeight: CGFloat
    var worldTransform: [CGFloat]   // [a, b, c, d, tx, ty] — CGAffineTransform components, explicit order
}

struct PrecisionProbeDTO: Encodable {
    var label: String   // "center" | "topLeft" | "topRight" | "bottomLeft" | "bottomRight"
    var worldPoint: CGPoint
    var contains: Bool
}

struct CanvasNodeGeometryDTO: Encodable {
    var nodeID: String
    var nodeKind: String
    var geometry: WorldGeometryDTO?
    var probes: [PrecisionProbeDTO]
}

struct CanvasHitDTO: Encodable {
    var nodeID: String
    var childID: String?
    var distance: CGFloat
}

struct CanvasFixtureDTO: Encodable {
    var fixtureName: String
    var canvasSize: CGSize
    var nodes: [CanvasNodeGeometryDTO]
    var hitsAtCanvasCenter: [CanvasHitDTO]
}

private func kindTag(_ node: MKNode) -> String {
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

func exportCanvas() throws {
    let categoryRoot = RepoPaths.fixturesRoot.appendingPathComponent("canvas")
    let hitTester = HitTester(fonts: SystemFontStubProvider())
    var count = 0

    for fixtureName in fixtureNames {
        let scene = try FixtureSceneLoader.loadScene(named: fixtureName)
        var nodeDTOs: [CanvasNodeGeometryDTO] = []

        // Cap at 25 nodes for the two large flat-node fixtures (100/5000) —
        // this category's purpose is exercising the geometry API's
        // correctness, not exhaustively cataloguing every node; the
        // `render`/`arrange` categories already cover full-scene fidelity.
        for node in scene.nodes.prefix(25) {
            let nodeID = node.id
            var probes: [PrecisionProbeDTO] = []
            var geometryDTO: WorldGeometryDTO?
            if let geometry = hitTester.worldGeometry(of: nodeID, in: scene) {
                let t = geometry.worldTransform
                geometryDTO = WorldGeometryDTO(
                    localBoundsX: geometry.localBounds.origin.x, localBoundsY: geometry.localBounds.origin.y,
                    localBoundsWidth: geometry.localBounds.width, localBoundsHeight: geometry.localBounds.height,
                    worldTransform: [t.a, t.b, t.c, t.d, t.tx, t.ty])

                let b = geometry.localBounds
                let corners: [(String, CGPoint)] = [
                    ("center", CGPoint(x: b.midX, y: b.midY)),
                    ("topLeft", CGPoint(x: b.minX, y: b.minY)),
                    ("topRight", CGPoint(x: b.maxX, y: b.minY)),
                    ("bottomLeft", CGPoint(x: b.minX, y: b.maxY)),
                    ("bottomRight", CGPoint(x: b.maxX, y: b.maxY)),
                ]
                for (label, localPoint) in corners {
                    let worldPoint = localPoint.applying(t)
                    let contains = hitTester.containsPrecise(nodeID: nodeID, worldPoint: worldPoint, in: scene)
                    probes.append(PrecisionProbeDTO(label: label, worldPoint: worldPoint, contains: contains))
                }
            }
            nodeDTOs.append(CanvasNodeGeometryDTO(nodeID: nodeID.description, nodeKind: kindTag(node), geometry: geometryDTO, probes: probes))
        }

        let canvasCenter = CGPoint(x: scene.canvas.size.width / 2, y: scene.canvas.size.height / 2)
        let hits = hitTester.allHits(at: canvasCenter, in: scene).map {
            CanvasHitDTO(nodeID: $0.nodeID.description, childID: $0.childID?.description, distance: $0.distance)
        }

        let dto = CanvasFixtureDTO(fixtureName: fixtureName, canvasSize: scene.canvas.size, nodes: nodeDTOs, hitsAtCanvasCenter: hits)
        try GoldenJSON.write(dto, to: categoryRoot.appendingPathComponent("\(fixtureName).json"))
        count += 1
    }
    print("[canvas] wrote \(count) hit-test-geometry fixture files across \(fixtureNames.count) fixtures")
}
