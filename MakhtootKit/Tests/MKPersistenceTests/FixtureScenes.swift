import CoreGraphics
import Foundation
import MKFoundation
import MKModel

// WS-02 packet §5 task 19. Pure `MKScene`/`MKNode` builders (no disk I/O ،
// `FixtureGenerator.swift` wraps these into on-disk `.makhtoot` packages).
// Duplicated verbatim into `Tests/MKPersistenceTests/` (see
// `MKFixtureLocator.swift`'s header note on why test targets can't share
// source files directly without an extra shared target this packet's file
// list doesn't call for).
enum FixtureScenes {
    static let defaultCanvas = MKCanvasSpec(size: CGSize(width: 1080, height: 1350))

    /// `count` flat sibling shape nodes ، used for the D-115 open-time
    /// budget fixtures (100-node / 5000-node).
    static func flatNodesScene(count: Int) -> MKScene {
        var nodes: [MKNode] = []
        nodes.reserveCapacity(count)
        for i in 0..<count {
            let core = MKNodeCore(name: "عنصر \(i)", zOrder: i)
            nodes.append(.shape(MKShapeNode(core: core, geometry: .rect(cornerRadius: 4))))
        }
        return MKScene(canvas: defaultCanvas, nodes: nodes)
    }

    /// A single Live Text object reading "بسم الله الرحمن الرحيم"
    /// (fixture-arabic-basic).
    static func arabicBasicScene() -> MKScene {
        let core = MKNodeCore(name: "نص حي")
        let text = MKSourceText(string: "بسم الله الرحمن الرحيم")
        let node = MKNode.liveText(MKLiveTextNode(core: core, text: text))
        return MKScene(canvas: MKCanvasSpec(size: CGSize(width: 1080, height: 1080)), nodes: [node])
    }

    /// One hand-built Arranged Composition for "لا" (lam U+0644 + alif
    /// U+0627, a mandatory ligature) ، a single composed `MKLigatureGroup`
    /// child, with a retained `MKSourceTextBackup` (fixture-arranged-la;
    /// packet task 4/13 accept criteria).
    static func arrangedLaScene() -> MKScene {
        let style = MKTextStyle(font: .system(postScriptName: "AmiriRegular"), pointSize: 96)
        let backup = MKSourceTextBackup(sourceString: "لا", style: style)

        let clusterID = MKClusterID()
        let provenance = MKProvenance(
            clusterID: clusterID,
            codepoints: [0x0644, 0x0627], // ل ا
            utf16Start: 0, utf16Length: 2,
            bidiLevel: 1, visualIndex: 0, logicalIndex: 0
        )
        let glyphRef = MKGlyphRef(glyphID: 421, font: style.font, fontChecksum: "deadbeef")
        let layout = MKGlyphLayout(position: .zero, advance: CGSize(width: 80, height: 0))
        let composed = MKComposedLigature(glyph: glyphRef, layout: layout, decomposable: true)
        let ligature = MKLigatureGroup(state: .composed(composed), provenance: provenance)

        let composition = ArrangedComposition(
            nodes: [.ligature(ligature)],
            sourceBackup: backup,
            originFrame: CGRect(x: 0, y: 0, width: 80, height: 96)
        )
        let arrangedCore = MKNodeCore(name: "تركيبة لا")
        let arrangedNode = MKArrangedTextNode(core: arrangedCore, composition: composition, derivedFrom: .liveText)
        return MKScene(canvas: MKCanvasSpec(size: CGSize(width: 400, height: 400)), nodes: [.arranged(arrangedNode)])
    }
}
