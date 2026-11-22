import CoreGraphics
import Foundation
import MKFoundation
import MKModel
@testable import MKPathText
import MKPersistence
import Testing

@Suite("PathTextCommands ، task 11 accepts")
struct PathTextCommandsTests {
    static func makeScene(text: String = "سلام") -> (MKScene, MKNodeID) {
        let nodeID = MKNodeID()
        let node = MKPathTextNode(
            core: MKNodeCore(id: nodeID, name: "مسار"),
            text: MKSourceText(string: text),
            style: .default,
            path: BezierPathModel.line(from: .zero, to: CGPoint(x: 500, y: 0)).bezierPathData(),
            layout: MKPathLayoutOptions())
        let scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 1000, height: 1000)), nodes: [.pathText(node)])
        return (scene, nodeID)
    }

    @Test("setText applies and inverts back to the original node")
    func setTextApplyInverse() throws {
        let (scene, nodeID) = Self.makeScene()
        let command = PathTextCommands.setText(MKSourceText(string: "عليك"), nodeID: nodeID, in: scene, burstKey: "burst-1")
        #expect(command != nil)
        guard let command else { return }
        let applied = try command.apply(to: scene)
        guard case .pathText(let updated) = applied.node(id: nodeID) else {
            Issue.record("expected pathText node")
            return
        }
        #expect(updated.text.string == "عليك")

        let inverse = command.inverse(against: scene)
        let reverted = try inverse.apply(to: applied)
        guard case .pathText(let original) = reverted.node(id: nodeID) else {
            Issue.record("expected pathText node")
            return
        }
        #expect(original.text.string == "سلام")
    }

    @Test("setPath commits an edited BezierPathModel")
    func setPathCommits() throws {
        let (scene, nodeID) = Self.makeScene()
        let newPath = BezierPathModel.circle(center: .zero, radius: 200)
        let command = PathTextCommands.setPath(newPath, nodeID: nodeID, in: scene, coalescingKey: "path:\(nodeID)")
        #expect(command != nil)
        guard let command else { return }
        let applied = try command.apply(to: scene)
        guard case .pathText(let updated) = applied.node(id: nodeID) else {
            Issue.record("expected pathText node")
            return
        }
        #expect(updated.path.isClosed)
        #expect(updated.path == newPath.bezierPathData())
    }

    @Test("setOptions and setStyle apply and are independently coalescable")
    func setOptionsAndStyle() throws {
        let (scene, nodeID) = Self.makeScene()
        let newOptions = MKPathLayoutOptions(startOffset: 42, side: .above, spacingMode: .justify)
        guard let optionsCommand = PathTextCommands.setOptions(newOptions, nodeID: nodeID, in: scene) else {
            Issue.record("expected a command")
            return
        }
        let afterOptions = try optionsCommand.apply(to: scene)
        guard case .pathText(let updated) = afterOptions.node(id: nodeID) else {
            Issue.record("expected pathText node")
            return
        }
        #expect(updated.layout.startOffset == 42)
        #expect(updated.layout.side == .above)
        #expect(updated.layout.spacingMode == .justify)

        let newStyle = MKTextStyle(pointSize: 60)
        guard let styleCommand = PathTextCommands.setStyle(newStyle, nodeID: nodeID, in: afterOptions) else {
            Issue.record("expected a command")
            return
        }
        let afterStyle = try styleCommand.apply(to: afterOptions)
        guard case .pathText(let restyled) = afterStyle.node(id: nodeID) else {
            Issue.record("expected pathText node")
            return
        }
        #expect(restyled.style.pointSize == 60)
        // Options survive an independent style edit.
        #expect(restyled.layout.startOffset == 42)
    }

    @Test("Commands return nil for a node that is not pathText")
    func nonPathTextNodeReturnsNil() {
        let nodeID = MKNodeID()
        let shape = MKShapeNode(core: MKNodeCore(id: nodeID, name: "شكل"), geometry: .ellipse)
        let scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 100, height: 100)), nodes: [.shape(shape)])
        #expect(PathTextCommands.setText(MKSourceText(string: "x"), nodeID: nodeID, in: scene, burstKey: "b") == nil)
    }

    @Test("Full node Codable round-trip including path/options")
    func nodeCodableRoundTrip() throws {
        let (scene, nodeID) = Self.makeScene(text: "بسم الله")
        guard case .pathText(var node) = scene.node(id: nodeID) else {
            Issue.record("expected pathText node")
            return
        }
        node.layout = MKPathLayoutOptions(startOffset: 12, side: .below, spacingMode: .justify)
        node.path = BezierPathModel.circle(center: CGPoint(x: 10, y: 10), radius: 80).bezierPathData()

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(node)
        let decoded = try decoder.decode(MKPathTextNode.self, from: data)
        #expect(decoded == node)
    }

    @Test("setGlyphOffset commits a per-glyph nudge into glyphOffsets, applies and inverts correctly")
    func setGlyphOffsetApplyInverse() throws {
        let (scene, nodeID) = Self.makeScene()
        let key = PathClusterProvenanceKey(codepoints: [0x0633], occurrenceOrdinal: 0)
        let offset = PathGlyphUserOffset(offset: CGPoint(x: 5, y: -3), rotation: 0.1)
        let command = PathTextCommands.setGlyphOffset(offset, forKey: key, nodeID: nodeID, in: scene)
        #expect(command != nil)
        guard let command else { return }

        let applied = try command.apply(to: scene)
        guard case .pathText(let updated) = applied.node(id: nodeID) else {
            Issue.record("expected pathText node")
            return
        }
        let persistedKey = MKPathGlyphOffsetKey(codepoints: key.codepoints, occurrenceOrdinal: key.occurrenceOrdinal)
        #expect(updated.glyphOffsets[persistedKey] == MKPathGlyphOffset(offset: CGPoint(x: 5, y: -3), rotation: 0.1))

        let inverse = command.inverse(against: scene)
        let reverted = try inverse.apply(to: applied)
        guard case .pathText(let original) = reverted.node(id: nodeID) else {
            Issue.record("expected pathText node")
            return
        }
        #expect(original.glyphOffsets.isEmpty)
    }

    @Test("persistedUserOffsets converts a node's persisted glyphOffsets into the engine's runtime keying")
    func persistedUserOffsetsConverts() throws {
        let (scene, nodeID) = Self.makeScene()
        let key = PathClusterProvenanceKey(codepoints: [0x0644, 0x0627], occurrenceOrdinal: 2)
        let offset = PathGlyphUserOffset(offset: CGPoint(x: 1, y: 2), rotation: 0.3)
        guard let command = PathTextCommands.setGlyphOffset(offset, forKey: key, nodeID: nodeID, in: scene) else {
            Issue.record("expected a command")
            return
        }
        let applied = try command.apply(to: scene)
        guard case .pathText(let updated) = applied.node(id: nodeID) else {
            Issue.record("expected pathText node")
            return
        }

        let converted = PathTextCommands.persistedUserOffsets(from: updated)
        #expect(converted[key] == offset)
    }

    @Test("PathTextOffsetStore holds per-node, per-key offsets (engine-level, not yet MKCommand-integrated ، see README)")
    func offsetStoreHoldsPerNodeOffsets() {
        let store = PathTextOffsetStore()
        let nodeA = MKNodeID()
        let nodeB = MKNodeID()
        let key = PathClusterProvenanceKey(codepoints: [0x0633], occurrenceOrdinal: 0)
        store.setOffset(PathGlyphUserOffset(offset: CGPoint(x: 3, y: 4)), forKey: key, nodeID: nodeA)
        #expect(store.offsets(for: nodeA)[key]?.offset == CGPoint(x: 3, y: 4))
        #expect(store.offsets(for: nodeB).isEmpty)
        store.clear(nodeID: nodeA)
        #expect(store.offsets(for: nodeA).isEmpty)
    }
}
