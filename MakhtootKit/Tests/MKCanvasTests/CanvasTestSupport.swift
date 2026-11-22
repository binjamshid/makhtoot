import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence
@testable import MKCanvas

// Shared test scaffolding: a temp-directory-backed `MakhtootDocument` (real
// file-package I/O, same primitive `MKPersistenceTests`/`MKModelTests` use
// via their own `FixtureGenerator`) plus a synthetic `MKCanvasGeometrySource`
// test double standing in for WS-07's not-yet-landed real geometry (see
// `Geometry/MKCanvasGeometrySource.swift`'s header comment for why a local
// seam exists at all).

@MainActor
enum CanvasTestSupport {
    /// Creates a fresh `MakhtootDocument` in a throwaway temp directory ،
    /// deleted automatically when the process/test run ends (macOS/iOS
    /// simulator temp dirs are cleaned by the OS; not deleted explicitly
    /// here to match `MKPersistenceTests`' own precedent of leaving temp
    /// fixtures for post-hoc inspection when a test fails).
    static func makeDocument(canvasSize: CGSize = CGSize(width: 1000, height: 1000), title: String = "اختبار") throws -> MakhtootDocument {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mkcanvas-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("\(UUID().uuidString).makhtoot")
        return try MakhtootDocument.create(at: root, title: title, canvas: MKCanvasSpec(size: canvasSize))
    }

    static func makeSession(canvasSize: CGSize = CGSize(width: 1000, height: 1000)) throws -> CanvasSession {
        let document = try makeDocument(canvasSize: canvasSize)
        return CanvasSession(document: document)
    }

    /// A simple shape node at `position` with `size` (world-space, no
    /// rotation) ، inserted directly via the document's real command
    /// funnel so undo/journal/autosave machinery is exercised exactly as
    /// production code would.
    @discardableResult
    static func addShapeNode(to session: CanvasSession, name: String = "شكل", position: CGPoint, size: CGSize = CGSize(width: 100, height: 60), rotation: CGFloat = 0, locked: Bool = false, hidden: Bool = false) throws -> MKNodeID {
        var core = MKNodeCore(name: name, transform: MKTransform2D(position: position, rotation: rotation, scale: CGSize(width: size.width, height: size.height)))
        core.isLocked = locked
        core.isHidden = hidden
        let node = MKNode.shape(MKShapeNode(core: core, geometry: .rect(cornerRadius: 0)))
        try session.perform(MKInsertNodeCommand(node: node, index: nil, parent: nil))
        return node.id
    }
}

/// Synthetic `MKCanvasGeometrySource`: nodes are unit-square shapes scaled
/// by `transform.scale` (matching `CanvasTestSupport.addShapeNode`'s
/// convention above), so `worldOBB` is just `MKOrientedRect(localBounds:
/// transform:)` with a `(0,0)-(1,1)` local rect scaled up by `transform
/// .scale` ، i.e. `transform.scale` directly encodes the node's world
/// size. This is the same "intrinsic size" contract
/// `HandleGestures`/`InspectorModel` assume when deriving a new transform
/// back out of a resized OBB.
@MainActor
final class FakeGeometrySource: MKCanvasGeometrySource {
    static let unitLocalBounds = CGRect(x: 0, y: 0, width: 1, height: 1)

    func worldOBB(for nodeID: MKNodeID, in scene: MKScene) -> MKOrientedRect? {
        guard let node = scene.node(id: nodeID) else { return nil }
        return MKOrientedRect(localBounds: Self.unitLocalBounds, transform: node.core.transform)
    }
}

/// Records every `applyTransientTransform`/`commitTransients` call so
/// tests can assert the D-114/D-115 fast-path contract is exercised (no
/// scene-content redraw call is possible to assert from `MKCanvas` alone ،
/// that half is WS-07's own gate ، but call COUNT/ORDER is this packet's
/// to verify).
@MainActor
final class RecordingRenderBridge: MKCanvasRenderBridge {
    private(set) var transientCalls: [(nodeID: MKNodeID, transform: CGAffineTransform)] = []
    private(set) var commitCount = 0

    func applyTransientTransform(nodeID: MKNodeID, transform: CGAffineTransform) {
        transientCalls.append((nodeID, transform))
    }

    func commitTransients() {
        commitCount += 1
    }
}
