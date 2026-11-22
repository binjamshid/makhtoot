import CoreGraphics
import MKFoundation
import MKModel
import MKPersistence
import Testing
@testable import MKCanvas

// WS-06 packet §5 task 12 accept: "each returns the new node id and
// selects it."
@MainActor
@Suite("CanvasContentAPI")
struct CanvasContentAPITests {
    @Test func addLiveTextInsertsPlaceholderTextAndOpensTheOverlay() throws {
        let session = try CanvasTestSupport.makeSession()
        let id = try session.addLiveText(at: CGPoint(x: 10, y: 10))
        #expect(session.selection.ids == [id])
        #expect(session.mode == .editText(nodeID: id))
        guard case .liveText(let node)? = session.scene.node(id: id) else {
            Issue.record("expected a liveText node")
            return
        }
        #expect(node.text.string == CanvasSession.defaultLiveTextPlaceholder)
    }

    @Test func addLiveTextAcceptsCustomText() throws {
        let session = try CanvasTestSupport.makeSession()
        let id = try session.addLiveText(at: .zero, text: "بسم الله")
        guard case .liveText(let node)? = session.scene.node(id: id) else {
            Issue.record("expected a liveText node")
            return
        }
        #expect(node.text.string == "بسم الله")
    }

    @Test func addShapeInsertsAndSelects() throws {
        let session = try CanvasTestSupport.makeSession()
        let id = try session.addShape(.ellipse, at: CGPoint(x: 5, y: 5))
        #expect(session.selection.ids == [id])
        guard case .shape(let node)? = session.scene.node(id: id) else {
            Issue.record("expected a shape node")
            return
        }
        if case .ellipse = node.geometry {} else { Issue.record("expected ellipse geometry") }
    }

    @Test func addImageInsertsAndSelects() throws {
        let session = try CanvasTestSupport.makeSession()
        let ref = MKAssetRef(digest: "abc123", ext: "png")
        let id = try session.addImage(assetRef: ref, kind: .raster, at: .zero)
        #expect(session.selection.ids == [id])
        guard case .image(let node)? = session.scene.node(id: id) else {
            Issue.record("expected an image node")
            return
        }
        #expect(node.asset == ref)
    }

    @Test func addedContentIsUndoable() throws {
        let session = try CanvasTestSupport.makeSession()
        let countBefore = session.scene.nodes.count
        _ = try session.addShape(.ellipse, at: .zero)
        #expect(session.scene.nodes.count == countBefore + 1)
        try session.undo()
        #expect(session.scene.nodes.count == countBefore)
    }
}
