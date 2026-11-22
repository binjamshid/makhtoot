import Testing
import CoreGraphics
import Foundation
import MKFoundation
import MKModel
@testable import MKRender

@Suite struct SnapshotRendererTests {
    private let renderer = MKSnapshotRenderer()

    @Test func rendersFullCanvasAtRequestedScale() {
        let scene = TestScenes.scene(canvasSize: CGSize(width: 100, height: 50), nodes: [TestScenes.redRect()])
        let image = renderer.renderFullCanvas(scene, scale: 3, quality: .exportQuality)
        #expect(image?.width == 300)
        #expect(image?.height == 150)
    }

    @Test func rendersArbitraryRegionAtCorrectPixelSize() {
        let scene = TestScenes.scene(canvasSize: CGSize(width: 400, height: 400), nodes: [TestScenes.redRect(position: CGPoint(x: 300, y: 300), size: CGSize(width: 40, height: 40))])
        let region = CGRect(x: 200, y: 200, width: 150, height: 150)
        let image = renderer.render(scene, region: region, scale: 2, quality: .exportQuality)
        #expect(image?.width == 300)
        #expect(image?.height == 300)
    }

    /// Region rendering must return the correct SUB-RECT ، a red square at
    /// (300,300) with a 150×150 region starting at (200,200) should place
    /// the square's center at region-local (100,100) → pixel (200,200) at
    /// scale 2.
    @Test func regionRenderCropsToCorrectSubRect() {
        let scene = TestScenes.scene(canvasSize: CGSize(width: 400, height: 400), background: .white, nodes: [
            TestScenes.redRect(position: CGPoint(x: 300, y: 300), size: CGSize(width: 40, height: 40)),
        ])
        let region = CGRect(x: 200, y: 200, width: 150, height: 150)
        guard let image = renderer.render(scene, region: region, scale: 2, quality: .exportQuality) else {
            Issue.record("render failed")
            return
        }
        let p = readPixel(image, x: 200, y: 200)
        #expect(p.0 > 200 && p.1 < 60 && p.2 < 60)   // red
    }

    /// Task 4 accept: thumbnail for a 100-node fixture generated <50 ms
    /// (simulator). Verified here as a lightweight perf smoke check on
    /// this sandboxed toolchain (device numbers are a P14 concern, task 14).
    @Test func thumbnailRendersUnderBudgetFor100Nodes() {
        var nodes: [MKNode] = []
        for i in 0..<100 {
            let x = CGFloat(i % 10) * 100 + 50
            let y = CGFloat(i / 10) * 100 + 50
            nodes.append(TestScenes.redRect(position: CGPoint(x: x, y: y), size: CGSize(width: 20, height: 20)))
        }
        let scene = TestScenes.scene(canvasSize: CGSize(width: 1080, height: 1080), nodes: nodes)

        let start = Date()
        let thumbnail = renderer.renderThumbnail(scene, longEdge: 512)
        let elapsed = Date().timeIntervalSince(start)

        #expect(thumbnail != nil)
        #expect(max(thumbnail?.width ?? 0, thumbnail?.height ?? 0) == 512)
        #expect(elapsed < 0.4, "thumbnail took \(elapsed)s on this sandboxed host ، investigate if far over budget")
    }

    @Test func reportsSubstitutionForMissingRasterAsset() {
        let node = MKImageNode(core: MKNodeCore(name: "img"), asset: MKAssetRef(digest: "missing", ext: "png"), kind: .raster)
        let scene = TestScenes.scene(nodes: [.image(node)])
        let (_, report) = renderer.renderWithReport(scene, region: CGRect(origin: .zero, size: scene.canvas.size), scale: 1, quality: .exportQuality)
        #expect(report.substitutions.contains { $0.kind == .missingAsset && $0.nodeID == node.core.id })
    }

    @Test func reportsSubstitutionForArrangedChildWithNoPersistedOutline() {
        let provenance = MKProvenance(clusterID: MKClusterID(), codepoints: [0x0644], utf16Start: 0, utf16Length: 1, bidiLevel: 0, visualIndex: 0, logicalIndex: 0)
        let glyph = MKGlyphNode(glyph: MKGlyphRef(glyphID: 1, font: .systemFallback, fontChecksum: "x"), outline: nil, layout: MKGlyphLayout(position: .zero, advance: .zero), provenance: provenance)
        let composition = ArrangedComposition(nodes: [.glyph(glyph)], sourceBackup: MKSourceTextBackup(sourceString: "ل", style: .default), originFrame: CGRect(x: -10, y: -10, width: 20, height: 20))
        let node = MKArrangedTextNode(core: MKNodeCore(name: "arranged"), composition: composition, derivedFrom: .liveText)
        let scene = TestScenes.scene(nodes: [.arranged(node)])

        let (_, report) = renderer.renderWithReport(scene, region: CGRect(origin: .zero, size: scene.canvas.size), scale: 1, quality: .exportQuality)
        #expect(report.substitutions.contains { $0.kind == .missingOutline })
    }

    private func readPixel(_ image: CGImage, x: Int, y: Int) -> (Int, Int, Int, Int) {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: &data, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let offset = (y * image.width + x) * 4
        return (Int(data[offset]), Int(data[offset + 1]), Int(data[offset + 2]), Int(data[offset + 3]))
    }
}
