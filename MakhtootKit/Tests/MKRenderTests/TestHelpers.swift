import CoreGraphics
import Foundation
import MKFoundation
import MKModel
@testable import MKRender

// Shared synthetic-scene builders for MKRenderTests. Built programmatically
// (not from `Tests/Fixtures/*.makhtoot` JSON) so every test has exact
// control over style/fill fields ، the WS-02 JSON fixtures (e.g.
// `fixture-arabic-basic.makhtoot`) were authored before rendering
// requirements existed and several (e.g. that one) have `style.fill: .none`
// on their live-text node, which is correct for WS-02's own scope but not
// useful as a rendering golden input.

enum TestScenes {
    static func core(name: String, position: CGPoint = .zero, rotation: CGFloat = 0, scale: CGSize = CGSize(width: 1, height: 1), fill: MKSolidColor? = .black) -> MKNodeCore {
        MKNodeCore(
            name: name,
            transform: MKTransform2D(position: position, rotation: rotation, scale: scale),
            style: MKStyle(fill: fill.map(MKFill.solid) ?? .none)
        )
    }

    static func redRect(position: CGPoint = CGPoint(x: 50, y: 50), size: CGSize = CGSize(width: 40, height: 40)) -> MKNode {
        .shape(MKShapeNode(
            core: core(name: "rect", position: position, scale: size, fill: MKSolidColor(r: 1, g: 0, b: 0, a: 1)),
            geometry: .rect(cornerRadius: 0)
        ))
    }

    static func blueEllipse(position: CGPoint = CGPoint(x: 100, y: 100), size: CGSize = CGSize(width: 30, height: 30)) -> MKNode {
        .shape(MKShapeNode(
            core: core(name: "ellipse", position: position, scale: size, fill: MKSolidColor(r: 0, g: 0, b: 1, a: 1)),
            geometry: .ellipse
        ))
    }

    static func liveText(_ string: String = "بسم الله", position: CGPoint = CGPoint(x: 20, y: 20), pointSize: Double = 32, fill: MKSolidColor = .black) -> MKNode {
        .liveText(MKLiveTextNode(
            core: core(name: "text", position: position, fill: fill),
            text: MKSourceText(string: string),
            style: MKTextStyle(pointSize: pointSize)
        ))
    }

    static func scene(canvasSize: CGSize = CGSize(width: 400, height: 400), background: MKSolidColor = .white, nodes: [MKNode] = []) -> MKScene {
        MKScene(
            canvas: MKCanvasSpec(size: canvasSize),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(background)),
            nodes: nodes
        )
    }

    /// A minimal synthetic Arranged Composition: one base glyph + one
    /// attached following mark, with hand-authored (not font-derived)
    /// square outlines ، enough to drive `T-ARR-1`/`T-ARR-2`'s D-220
    /// numeric checks without needing a real font/shaping pipeline.
    static func arrangedBaseAndMark(
        baseTransform: MKTransform2D = .identity,
        markRelativeOffset: CGSize = CGSize(width: 0, height: 20),
        markTransform: MKTransform2D = .identity,
        compositionTransform: MKTransform2D = .identity
    ) -> (node: MKArrangedTextNode, baseID: MKNodeID, markID: MKNodeID) {
        let baseID = MKNodeID()
        let markID = MKNodeID()
        let squareOutline = MKPathData(commands: [
            0, -500, -500,
            1, 500, -500,
            1, 500, 500,
            1, -500, 500,
            4,
        ], unitsPerEm: 1000)

        let provenance = MKProvenance(clusterID: MKClusterID(), codepoints: [0x0644], utf16Start: 0, utf16Length: 1, bidiLevel: 0, visualIndex: 0, logicalIndex: 0)
        let glyph = MKGlyphNode(
            id: baseID,
            glyph: MKGlyphRef(glyphID: 1, font: .systemFallback, fontChecksum: "test"),
            outline: squareOutline,
            layout: MKGlyphLayout(position: .zero, advance: CGSize(width: 40, height: 0)),
            transform: baseTransform,
            provenance: provenance
        )
        let mark = MKMarkNode(
            id: markID,
            glyph: MKGlyphRef(glyphID: 2, font: .systemFallback, fontChecksum: "test"),
            outline: squareOutline,
            attachedTo: baseID,
            relativeOffset: markRelativeOffset,
            followsBase: true,
            transform: markTransform,
            provenance: provenance,
            markClass: .tashkeel
        )
        let backup = MKSourceTextBackup(sourceString: "ل", style: MKTextStyle(pointSize: 96))
        let composition = ArrangedComposition(
            nodes: [.glyph(glyph), .mark(mark)],
            sourceBackup: backup,
            originFrame: CGRect(x: -50, y: -50, width: 100, height: 100)
        )
        let node = MKArrangedTextNode(
            core: MKNodeCore(name: "arranged", transform: compositionTransform),
            composition: composition,
            derivedFrom: .liveText
        )
        return (node, baseID, markID)
    }
}

/// Pixel-diff utility for golden/tolerance-based drawer tests (packet §5
/// task 2/3 accept: "tolerance-based diff ≤0.5%"; task 15: "≤0.1%
/// preview-vs-export").
enum PixelDiff {
    /// Fraction (0...1) of pixels that differ by more than `perChannelTolerance`
    /// in any RGBA channel. Images must have identical dimensions (returns
    /// `1.0`, i.e. "fully different," if they don't ، never crashes).
    static func differingFraction(_ a: CGImage, _ b: CGImage, perChannelTolerance: UInt8 = 8) -> Double {
        guard a.width == b.width, a.height == b.height, a.width > 0, a.height > 0 else { return 1.0 }
        guard let dataA = pixelData(a), let dataB = pixelData(b) else { return 1.0 }
        guard dataA.count == dataB.count else { return 1.0 }

        var differing = 0
        let pixelCount = a.width * a.height
        for i in 0..<pixelCount {
            let offset = i * 4
            var differs = false
            for channel in 0..<4 {
                let diff = abs(Int(dataA[offset + channel]) - Int(dataB[offset + channel]))
                if diff > Int(perChannelTolerance) { differs = true; break }
            }
            if differs { differing += 1 }
        }
        return Double(differing) / Double(pixelCount)
    }

    private static func pixelData(_ image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }
}
