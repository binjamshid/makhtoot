import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence
import Testing
@testable import MKCanvas

// Coverage for `CanvasSession.flipScene(axis:)` ، the whole-composition
// mirror added for the 2026-07-29 user report "no way to flip/mirror a
// project". The distinction from `flipSelection(axis:)` (which negates each
// node's own scale and leaves it exactly where it stands) is the entire
// point of the feature, so it is asserted explicitly below.
@MainActor
@Suite("CanvasSession.flipScene")
struct FlipSceneTests {
    private static let canvasSize = CGSize(width: 1000, height: 800)

    private static func makeSession() throws -> CanvasSession {
        try CanvasTestSupport.makeSession(canvasSize: canvasSize)
    }

    @Test func horizontalSceneFlipMirrorsPositionsAboutTheCanvasCentre() throws {
        let session = try Self.makeSession()
        let id = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 200, y: 400))

        try session.flipScene(axis: .horizontal)

        let transform = try #require(session.scene.node(id: id)?.core.transform)
        // 200 → 1000 − 200 = 800.
        #expect(abs(transform.position.x - 800) < 1e-6)
        #expect(abs(transform.position.y - 400) < 1e-6)
        // The object itself is mirrored too, not merely relocated.
        #expect(transform.scale.width < 0)
        #expect(transform.scale.height > 0)
    }

    @Test func verticalSceneFlipMirrorsTheOtherAxisOnly() throws {
        let session = try Self.makeSession()
        let id = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 300, y: 100))

        try session.flipScene(axis: .vertical)

        let transform = try #require(session.scene.node(id: id)?.core.transform)
        #expect(abs(transform.position.x - 300) < 1e-6)
        // 100 → 800 − 100 = 700.
        #expect(abs(transform.position.y - 700) < 1e-6)
        #expect(transform.scale.height < 0)
        #expect(transform.scale.width > 0)
    }

    @Test func flippingTheSceneTwiceRestoresItExactly() throws {
        let session = try Self.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, name: "أ", position: CGPoint(x: 120, y: 640))
        let b = try CanvasTestSupport.addShapeNode(to: session, name: "ب", position: CGPoint(x: 875, y: 90))
        let before = [a, b].map { session.scene.node(id: $0)!.core.transform }

        try session.flipScene(axis: .horizontal)
        try session.flipScene(axis: .horizontal)

        for (index, original) in zip([a, b], before).enumerated() {
            _ = index
            let now = try #require(session.scene.node(id: original.0)?.core.transform)
            #expect(abs(now.position.x - original.1.position.x) < 1e-6)
            #expect(abs(now.position.y - original.1.position.y) < 1e-6)
            #expect(abs(now.scale.width - original.1.scale.width) < 1e-6)
            #expect(abs(now.scale.height - original.1.scale.height) < 1e-6)
            #expect(abs(now.rotation - original.1.rotation) < 1e-6)
        }
    }

    /// Why this operation had to exist at all: Select All + Flip Horizontal
    /// is NOT a mirror of the design. It leaves every node's position
    /// untouched, so a composition laid out left-to-right stays laid out
    /// left-to-right, merely with each element back-to-front.
    @Test func aSceneFlipRelocatesNodesWhereASelectionFlipDoesNot() throws {
        let selectionSession = try Self.makeSession()
        let selectionID = try CanvasTestSupport.addShapeNode(to: selectionSession, position: CGPoint(x: 100, y: 400))
        selectionSession.setSelection([selectionID])
        try selectionSession.flipSelection(axis: .horizontal)
        let afterSelectionFlip = try #require(selectionSession.scene.node(id: selectionID)?.core.transform)
        #expect(abs(afterSelectionFlip.position.x - 100) < 1e-6, "a selection flip must not move anything")

        let sceneSession = try Self.makeSession()
        let sceneID = try CanvasTestSupport.addShapeNode(to: sceneSession, position: CGPoint(x: 100, y: 400))
        try sceneSession.flipScene(axis: .horizontal)
        let afterSceneFlip = try #require(sceneSession.scene.node(id: sceneID)?.core.transform)
        #expect(abs(afterSceneFlip.position.x - 900) < 1e-6, "a scene flip must relocate to the mirrored side")
    }

    /// Reflection conjugation: a mirror reverses the sense of any rotation
    /// it carries. Without this a rotated element would keep leaning the
    /// same way after the mirror, which reads as "the flip didn't work" on
    /// exactly the compositions where it matters most.
    @Test func rotationIsNegatedByASceneFlip() throws {
        let session = try Self.makeSession()
        let id = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 250, y: 250), rotation: 0.6)

        try session.flipScene(axis: .horizontal)

        let transform = try #require(session.scene.node(id: id)?.core.transform)
        #expect(abs(transform.rotation + 0.6) < 1e-6)
    }

    /// Unlike `flipSelection`, a scene flip is one document-level
    /// transform, so it must be ONE undo step no matter how many nodes it
    /// touched ، unwinding a mirror N steps at a time would be
    /// indefensible.
    @Test func aSceneFlipIsASingleUndoStep() throws {
        let session = try Self.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, name: "أ", position: CGPoint(x: 120, y: 640))
        let b = try CanvasTestSupport.addShapeNode(to: session, name: "ب", position: CGPoint(x: 875, y: 90))

        try session.flipScene(axis: .horizontal)
        try session.undo()

        #expect(abs((session.scene.node(id: a)?.core.transform.position.x ?? 0) - 120) < 1e-6)
        #expect(abs((session.scene.node(id: b)?.core.transform.position.x ?? 0) - 875) < 1e-6)
    }

    /// Locked nodes are deliberately INCLUDED (see `flipScene`'s doc
    /// comment): skipping one would not protect it, it would silently
    /// produce a half-mirrored composition.
    @Test func lockedNodesAreMirroredToo() throws {
        let session = try Self.makeSession()
        let locked = try CanvasTestSupport.addShapeNode(
            to: session, name: "مقفل", position: CGPoint(x: 200, y: 400), locked: true)

        try session.flipScene(axis: .horizontal)

        let transform = try #require(session.scene.node(id: locked)?.core.transform)
        #expect(abs(transform.position.x - 800) < 1e-6)
    }

    @Test func flippingAnEmptySceneIsANoOp() throws {
        let session = try Self.makeSession()
        try session.flipScene(axis: .horizontal)
        #expect(session.scene.nodes.isEmpty)
        #expect(session.canUndo == false)
    }
}
