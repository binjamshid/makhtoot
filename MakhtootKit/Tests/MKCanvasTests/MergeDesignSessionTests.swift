import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence
import Testing
@testable import MKCanvas

// P7.4 (§2.2 "Merge Design"): `CanvasSession.mergeDesign(fromPackageAt:)`
// (`EditingOperations.swift`) imports another saved project's nodes into
// the current scene ، fresh ids (same requirement as P6's paste), one
// undo step, reusing `DocumentPackage.readScene()` directly.
@MainActor
@Suite("CanvasSession.mergeDesign")
struct MergeDesignSessionTests {
    private func makeSourcePackage(nodeCount: Int) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mkcanvas-merge-source-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("\(UUID().uuidString).makhtoot")
        let package = try MKPersistence.DocumentPackage.create(at: root, projectID: MKProjectID(), title: "مصدر", canvas: MKCanvasSpec(size: CGSize(width: 400, height: 400)))
        var scene = try package.readScene()
        for i in 0..<nodeCount {
            let node = MKNode.shape(MKShapeNode(
                core: MKNodeCore(name: "شكل \(i)", transform: MKTransform2D(position: CGPoint(x: Double(i) * 10, y: 0))),
                geometry: .rect(cornerRadius: 0)
            ))
            scene = scene.inserting(node)
        }
        try package.writeScene(scene)
        return root
    }

    @Test func mergeImportsEveryTopLevelNodeWithFreshIDs() throws {
        let sourceURL = try makeSourcePackage(nodeCount: 2)
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }
        let sourceScene = try MKPersistence.DocumentPackage(rootURL: sourceURL).readScene()
        let sourceIDs = Set(sourceScene.nodes.map(\.id))

        let session = try CanvasTestSupport.makeSession()
        try session.mergeDesign(fromPackageAt: sourceURL)

        #expect(session.scene.nodes.count == 2)
        let mergedIDs = Set(session.scene.nodes.map(\.id))
        // Fresh ids: zero overlap with the source project's own node ids.
        #expect(mergedIDs.isDisjoint(with: sourceIDs))
    }

    @Test func mergeSelectsTheMergedNodes() throws {
        let sourceURL = try makeSourcePackage(nodeCount: 2)
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        let session = try CanvasTestSupport.makeSession()
        try session.mergeDesign(fromPackageAt: sourceURL)

        #expect(session.selection.ids == Set(session.scene.nodes.map(\.id)))
    }

    @Test func mergeIsOneUndoStep() throws {
        let sourceURL = try makeSourcePackage(nodeCount: 3)
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        let session = try CanvasTestSupport.makeSession()
        try session.mergeDesign(fromPackageAt: sourceURL)
        #expect(session.scene.nodes.count == 3)

        try session.document.undo()
        #expect(session.scene.nodes.isEmpty)
    }

    @Test func mergingAnEmptySourceSceneIsANoOp() throws {
        let sourceURL = try makeSourcePackage(nodeCount: 0)
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        let session = try CanvasTestSupport.makeSession()
        try session.mergeDesign(fromPackageAt: sourceURL)
        #expect(session.scene.nodes.isEmpty)
    }
}
