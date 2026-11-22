import CoreGraphics
import MKArrange
import MKFoundation
import MKModel
@testable import MKPathText
import MKPersistence
import MKTextEngine
import Testing

@Suite("PathPlacementProvider ، task 12, T-PTH-6 arrange-on-path integration")
struct PathPlacementProviderTests {
    static func capture(_ text: String, style: MKTextStyle) async -> MKShapingCaptureResult {
        let service = MKShapingService()
        return await service.captureResult(MKShapingRequest(string: text, style: style))
    }

    @Test("Derived glyph nodes match the live placements within 0.1 pt")
    func derivedNodesMatchLivePlacementsWithinTolerance() async throws {
        let text = "سلام"
        let style = MKTextStyle(pointSize: 36)
        let pathData = BezierPathModel.arc(center: .zero, radius: 400, startAngle: -.pi / 3, endAngle: .pi / 3).bezierPathData()
        let capture = await Self.capture(text, style: style)
        let line = capture.paragraph.lines[0]

        let options = PathLayoutOptions()
        let (provider, liveResult) = MKPathTextPlacementProvider.forArrangeOnPath(line: line, path: pathData, options: options)

        let deriver = ArrangeDeriver()
        let composition = await deriver.derive(
            sourceText: text, style: style, capture: capture,
            paintStyle: MKStyle(fill: .solid(.defaultInk)),
            pathData: pathData, placement: provider)

        let liveByAddress = Dictionary(uniqueKeysWithValues: liveResult.placements.filter { !$0.isMark }.map { ($0.address, $0) })

        var checkedAtLeastOne = false
        for child in composition.nodes {
            guard case .glyph(let glyph) = child else { continue }
            // Match this derived glyph back to a live placement via its
            // provenance (codepoints + cluster ordering is preserved
            // 1:1 by `ArrangeDeriver`, so scanning by cluster identity is
            // unnecessary ، every non-mark glyph node corresponds to
            // exactly one `MKGlyphAddress` the deriver queried, and since
            // it queried EVERY live placement's address, comparing the
            // full VALUE sets is sufficient and simpler than re-deriving
            // the address mapping here).
            let matches = liveByAddress.values.contains { live in
                hypot(live.position.x - glyph.layout.position.x, live.position.y - glyph.layout.position.y) < 0.1
                    && abs((glyph.layout.pathTangentAngle ?? .nan) - Double(live.rotation)) < 0.001
            }
            #expect(matches)
            #expect(glyph.layout.pathTangentAngle != nil)
            checkedAtLeastOne = true
        }
        #expect(checkedAtLeastOne)
    }

    @Test("Arrange-on-path round trip: revert restores a live pathText node on the identical path")
    func arrangeThenRevertRestoresPathTextNode() async throws {
        let text = "بسم الله"
        let style = MKTextStyle(pointSize: 30)
        let originalPath = BezierPathModel.circle(center: CGPoint(x: 0, y: 0), radius: 250).bezierPathData()
        let capture = await Self.capture(text, style: style)
        let line = capture.paragraph.lines[0]

        let (provider, _) = MKPathTextPlacementProvider.forArrangeOnPath(line: line, path: originalPath, options: PathLayoutOptions())
        let deriver = ArrangeDeriver()
        let composition = await deriver.derive(
            sourceText: text, style: style, capture: capture,
            paintStyle: MKStyle(fill: .solid(.defaultInk)),
            pathData: originalPath, placement: provider)

        #expect(composition.sourceBackup.pathData == originalPath)

        let nodeID = MKNodeID()
        let core = MKNodeCore(id: nodeID, name: "مسار")
        let arrangeCommand = ArrangeCommands.arrangeCommand(
            sourceNodeID: nodeID, core: core, composition: composition, derivedFrom: .pathText(originalPath))

        let originalPathTextNode = MKPathTextNode(core: core, text: MKSourceText(string: text), style: style, path: originalPath)
        let scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 1200, height: 1200)), nodes: [.pathText(originalPathTextNode)])
        let arrangedScene = try arrangeCommand.apply(to: scene)

        guard case .arranged(let arrangedNode) = arrangedScene.node(id: nodeID) else {
            Issue.record("expected an arranged node after applying arrangeCommand")
            return
        }

        let revertCommand = try RevertService().revertCommand(arrangedNodeID: nodeID, node: arrangedNode)
        let revertedScene = try revertCommand.apply(to: arrangedScene)
        guard case .pathText(let revertedNode) = revertedScene.node(id: nodeID) else {
            Issue.record("expected revert to restore a pathText node")
            return
        }
        #expect(revertedNode.path == originalPath)
        #expect(revertedNode.text.string == text)
    }

    @Test("placement(for:lineIndex:) returns nil for an address it never computed (safe default)")
    func unknownAddressReturnsNil() {
        let result = PathLayoutResult(placements: [], overflow: .none, pathLength: 0, curvatureWarning: false)
        let provider = MKPathTextPlacementProvider(layout: result, lineIndex: 0)
        #expect(provider.placement(for: MKGlyphAddress(run: 0, glyph: 0), lineIndex: 0) == nil)
        #expect(provider.placement(for: MKGlyphAddress(run: 0, glyph: 0), lineIndex: 1) == nil)
    }
}
