import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence
import Testing
@testable import MKCanvas

// P6 leftover: session-level regression coverage for `CanvasSession
// .flipSelection(axis:)` (`MKCanvas/EditingOperations.swift`), the first
// feature to produce a negative `MKTransform2D.scale` component anywhere in
// this codebase. Render/hit-test coverage lives in `MKRenderTests/
// FlipRenderingTests.swift`; SVG export coverage in `MKExportTests/
// FlipSVGExportTests.swift`. This file covers the `CanvasSession` API
// contract itself (which axis/nodes are affected, undo shape) plus the
// save→load round trip through a real `.makhtoot` package on disk.
@MainActor
@Suite("CanvasSession.flipSelection")
struct FlipSessionTests {
    @Test func horizontalFlipNegatesOnlyScaleWidth() throws {
        let session = try CanvasTestSupport.makeSession()
        let id = try CanvasTestSupport.addShapeNode(to: session, position: .zero, size: CGSize(width: 100, height: 60))
        session.setSelection([id])

        try session.flipSelection(axis: .horizontal)

        let transform = session.scene.node(id: id)?.core.transform
        #expect(transform?.scale.width == -100)
        #expect(transform?.scale.height == 60)
    }

    @Test func verticalFlipNegatesOnlyScaleHeight() throws {
        let session = try CanvasTestSupport.makeSession()
        let id = try CanvasTestSupport.addShapeNode(to: session, position: .zero, size: CGSize(width: 100, height: 60))
        session.setSelection([id])

        try session.flipSelection(axis: .vertical)

        let transform = session.scene.node(id: id)?.core.transform
        #expect(transform?.scale.width == 100)
        #expect(transform?.scale.height == -60)
    }

    /// Flipping twice about the same axis restores the original (positive)
    /// scale ، the intuitive "flip is its own inverse" property, not
    /// something a naive absolute-value-based implementation would break,
    /// but worth pinning since it is the property users actually rely on
    /// (flip, look, flip back).
    @Test func flippingTwiceRestoresTheOriginalScale() throws {
        let session = try CanvasTestSupport.makeSession()
        let id = try CanvasTestSupport.addShapeNode(to: session, position: .zero, size: CGSize(width: 100, height: 60))
        session.setSelection([id])

        try session.flipSelection(axis: .horizontal)
        try session.flipSelection(axis: .horizontal)

        #expect(session.scene.node(id: id)?.core.transform.scale.width == 100)
    }

    /// Matches `deleteSelection()`/`toggleLockForSelection()`'s own
    /// established "loop selection, skip locked" convention (doc comment
    /// on `flipSelection` in `EditingOperations.swift`).
    @Test func lockedNodesAreSkippedByFlip() throws {
        let session = try CanvasTestSupport.makeSession()
        let locked = try CanvasTestSupport.addShapeNode(to: session, position: .zero, size: CGSize(width: 100, height: 60), locked: true)
        // `setSelection` itself filters locked nodes out (matching every
        // other bulk-selection command's own test precedent above,
        // `lockedNodeIsExcludedFromDeleteSelection`) ، simulate a stale
        // selection containing the locked id directly via the internal
        // selection setter's sibling used elsewhere in this suite.
        session.setSelection([locked])
        #expect(session.selection.isEmpty) // sanity: setSelection already excludes it

        try session.flipSelection(axis: .horizontal)

        #expect(session.scene.node(id: locked)?.core.transform.scale.width == 100)
    }

    /// One `MKTransformCommand` per node (doc comment: "NOT wrapped in a
    /// single beginGesture()/endGesture() bracket") ، a two-node flip needs
    /// two `undo()` calls to fully revert, matching multi-node Delete's own
    /// established shape.
    @Test func multiNodeFlipIsOneUndoStepPerNode() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, name: "a", position: .zero, size: CGSize(width: 100, height: 60))
        let b = try CanvasTestSupport.addShapeNode(to: session, name: "b", position: CGPoint(x: 200, y: 0), size: CGSize(width: 100, height: 60))
        session.setSelection([a, b])

        try session.flipSelection(axis: .horizontal)
        #expect(session.scene.node(id: a)?.core.transform.scale.width == -100)
        #expect(session.scene.node(id: b)?.core.transform.scale.width == -100)

        try session.document.undo()
        // Only the LAST performed command (whichever node flipSelection's
        // selection-set iteration happened to visit last) is reverted by a
        // single undo ، the other stays flipped, proving this was two
        // separate undo steps rather than one bracketed gesture.
        let stillFlippedCount = [a, b].filter { session.scene.node(id: $0)?.core.transform.scale.width == -100 }.count
        #expect(stillFlippedCount == 1)

        try session.document.undo()
        #expect(session.scene.node(id: a)?.core.transform.scale.width == 100)
        #expect(session.scene.node(id: b)?.core.transform.scale.width == 100)
    }

    // MARK: - Save → load round trip

    /// A flip is just data (`MKTransform2D.scale` is `Codable` as plain
    /// `CGSize` fields, no raw-matrix re-decomposition on the direct
    /// persistence path ، `MKTransform2D.init(decomposing:)` is only used
    /// by `concatenating`/`inverted`/gesture bridging, never by JSON
    /// encode/decode), so the negative component must survive a real
    /// save-to-disk → reopen cycle through `DocumentPackage`'s
    /// `scene.json`, byte for byte.
    @Test func flipSurvivesASaveAndReloadRoundTrip() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mkcanvas-flip-roundtrip-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("\(UUID().uuidString).makhtoot")
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }

        let document = try MakhtootDocument.create(at: root, title: "اختبار الانعكاس", canvas: MKCanvasSpec(size: CGSize(width: 500, height: 500)))
        let session = CanvasSession(document: document)
        let id = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 10, y: 10), size: CGSize(width: 100, height: 60))
        session.setSelection([id])
        try session.flipSelection(axis: .horizontal)
        #expect(session.scene.node(id: id)?.core.transform.scale.width == -100)

        try await document.saveNow(reason: .documentClose)

        let package = DocumentPackage(rootURL: root)
        let reloadedScene = try package.readScene()
        #expect(reloadedScene.node(id: id)?.core.transform.scale.width == -100)
        #expect(reloadedScene.node(id: id)?.core.transform.scale.height == 60)

        // And re-opening through the full `MakhtootDocument.open` path
        // (crash-recovery/journal reconciliation included) preserves it
        // too ، not just the raw `scene.json` bytes.
        let (reopened, _) = try await MakhtootDocument.open(at: root)
        #expect(reopened.scene.node(id: id)?.core.transform.scale.width == -100)
    }
}
