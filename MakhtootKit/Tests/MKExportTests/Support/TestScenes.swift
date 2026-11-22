import CoreGraphics
import MKFoundation
import MKModel

// Shared fixture builders for MKExportTests. Kept minimal and local (no
// `Tests/Fixtures/` sibling-directory dependency) ، every scene here is
// built directly via `MKModel`'s own public initializers, matching this
// test target's documented "no MKPersistence round trip needed" choice
// (see Package.swift's testTarget comment).
enum TestScenes {
    /// A simple canvas (`width` × `height` pt) with a solid backgound and
    /// one filled rectangle covering the top-left quadrant ، enough
    /// visual content to exercise the render/encode pipeline without
    /// needing text shaping (MKExport's P10-EARLY slice does not depend
    /// on the text engine).
    static func rectScene(canvasSize: CGSize = CGSize(width: 200, height: 200), backgroundHidden: Bool = false) -> MKScene {
        var background = MKBackgroundNode.defaultBackground()
        background.content = .solid(MKSolidColor(r: 0.9, g: 0.85, b: 0.7))
        background.core.isHidden = backgroundHidden

        let rect = MKNode.shape(MKShapeNode(
            core: MKNodeCore(
                name: "Rect",
                transform: MKTransform2D(position: CGPoint(x: canvasSize.width / 4, y: canvasSize.height / 4)),
                style: MKStyle(fill: .solid(MKSolidColor(r: 0.8, g: 0.1, b: 0.1)))
            ),
            geometry: .rect(cornerRadius: 0)
        ))

        return MKScene(canvas: MKCanvasSpec(size: canvasSize), background: background, nodes: [rect])
    }

    /// A scene with a Live Text node set in `font` ، used by
    /// `ExportGate`'s premium-content-present font checks.
    static func liveTextScene(font: MKFontRef, canvasSize: CGSize = CGSize(width: 200, height: 200), hidden: Bool = false) -> MKScene {
        let textNode = MKNode.liveText(MKLiveTextNode(
            core: MKNodeCore(name: "Text", isHidden: hidden),
            text: MKSourceText(string: "بسم الله"),
            style: MKTextStyle(font: font)
        ))
        return MKScene(canvas: MKCanvasSpec(size: canvasSize), nodes: [textNode])
    }

    /// A scene whose background is a photo (image) ، D-119 "photo
    /// backgrounds = any image-node background".
    static func photoBackgroundScene(canvasSize: CGSize = CGSize(width: 200, height: 200)) -> MKScene {
        var background = MKBackgroundNode.defaultBackground()
        background.content = .image(MKAssetRef(digest: "deadbeef", ext: "jpg"), fit: .cover)
        return MKScene(canvas: MKCanvasSpec(size: canvasSize), background: background, nodes: [])
    }

    /// A scene with a regular image node flagged as a photo-background use
    /// (D-119's second "photo background" trigger, distinct from the
    /// canvas background slot itself).
    static func photoBackgroundUseImageNodeScene(canvasSize: CGSize = CGSize(width: 200, height: 200), hidden: Bool = false) -> MKScene {
        let imageNode = MKNode.image(MKImageNode(
            core: MKNodeCore(name: "Photo", isHidden: hidden),
            asset: MKAssetRef(digest: "cafebabe", ext: "jpg"),
            kind: .raster,
            isPhotoBackgroundUse: true
        ))
        return MKScene(canvas: MKCanvasSpec(size: canvasSize), nodes: [imageNode])
    }

    /// A plain group node with `id` ، used by premium-asset-node-id gating
    /// tests (the caller-supplied `Set<MKNodeID>` path).
    static func groupScene(groupID: MKNodeID, canvasSize: CGSize = CGSize(width: 200, height: 200)) -> MKScene {
        let group = MKNode.group(MKGroupNode(core: MKNodeCore(id: groupID, name: "PatternGroup"), children: []))
        return MKScene(canvas: MKCanvasSpec(size: canvasSize), nodes: [group])
    }

    // MARK: - P10-COMPLETION fixtures (PDF/SVG writers)

    /// System-registered font ، real, resolvable via `SystemFontStubProvider`
    /// (the default `fonts:` provider every writer test uses), so glyph
    /// shaping/outline extraction produces REAL, non-empty geometry (not a
    /// missing-font substitution).
    static let realFontRef = MKFontRef.system(postScriptName: "Helvetica")

    /// A user-imported font ref ، `AllOFLLicenseStub.embeddingRights`
    /// answers `[]` for ANY `userImported == true` ref (T15's rule), so
    /// this reliably exercises the outline-substitution path
    /// (`MKEmbeddingRestrictionWalker`/`MKTextOutlining`) in both PDF and
    /// SVG writers without needing a real premium/locked-font catalog.
    static let userImportedFontRef = MKFontRef(fontID: "user.testfont", postScriptName: "Helvetica", userImported: true)

    /// A multi-node scene exercising shapes + live text + a group ، the
    /// PDF/SVG writers' general "walk the whole tree" fixture.
    static func mixedContentScene(canvasSize: CGSize = CGSize(width: 400, height: 300), font: MKFontRef = realFontRef) -> MKScene {
        let rect = MKNode.shape(MKShapeNode(
            core: MKNodeCore(
                name: "Rect", transform: MKTransform2D(position: CGPoint(x: 100, y: 80), scale: CGSize(width: 120, height: 80)),
                // `cornerRadius`/`MKStroke.width` are both applied in the
                // shape's LOCAL 1×1-unit-square space, BEFORE this node's
                // own 120×80 transform scales it up (`ShapeDrawer
                // .localPath`/`MKStylePainting.paint`'s CTM-relative
                // `setLineWidth`) ، small fractional values here, not
                // absolute-point literals (a real pitfall independently
                // discovered and documented in `ZZEvidenceGenerator.swift`;
                // an earlier literal `cornerRadius: 8`/`width: 2` here
                // rendered as a solid-black/over-rounded shape when
                // visually inspected against a real generated sample).
                style: MKStyle(fill: .solid(MKSolidColor(r: 0.7, g: 0.15, b: 0.15)), stroke: MKStroke(color: .black, width: 0.01))
            ),
            geometry: .rect(cornerRadius: 0.06)
        ))
        let ellipse = MKNode.shape(MKShapeNode(
            core: MKNodeCore(
                name: "Ellipse", transform: MKTransform2D(position: CGPoint(x: 300, y: 200), scale: CGSize(width: 90, height: 90)),
                style: MKStyle(fill: .solid(MKSolidColor(r: 0.1, g: 0.3, b: 0.6)))
            ),
            geometry: .ellipse
        ))
        let text = MKNode.liveText(MKLiveTextNode(
            core: MKNodeCore(name: "Caption", transform: MKTransform2D(position: CGPoint(x: 40, y: 220)), style: MKStyle(fill: .solid(.black))),
            text: MKSourceText(string: "بسم الله الرحمن الرحيم"),
            style: MKTextStyle(font: font, pointSize: 22)
        ))
        let group = MKNode.group(MKGroupNode(core: MKNodeCore(name: "Shapes", transform: MKTransform2D(position: CGPoint(x: 0, y: 0))), children: [rect, ellipse]))
        var background = MKBackgroundNode.defaultBackground()
        background.content = .solid(.white)
        return MKScene(canvas: MKCanvasSpec(size: canvasSize), background: background, nodes: [group, text])
    }

    /// Live text using a font WITHOUT `.pdf`/`.svg` embedding rights
    /// (`userImportedFontRef`) ، the license-outline-switch fixture.
    static func restrictedFontLiveTextScene(canvasSize: CGSize = CGSize(width: 300, height: 150)) -> MKScene {
        let text = MKNode.liveText(MKLiveTextNode(
            core: MKNodeCore(name: "Restricted", transform: MKTransform2D(position: CGPoint(x: 30, y: 60)), style: MKStyle(fill: .solid(.black))),
            text: MKSourceText(string: "Restricted نص"),
            style: MKTextStyle(font: userImportedFontRef, pointSize: 28)
        ))
        return MKScene(canvas: MKCanvasSpec(size: canvasSize), nodes: [text])
    }

    /// Live text containing an emoji ، D-227(4)'s color-glyph carve-out
    /// fixture (used against the OUTLINED path, since the emoji-in-live
    /// `<text>` case relies on the viewer's own font, not this writer).
    static func emojiRestrictedFontLiveTextScene(canvasSize: CGSize = CGSize(width: 300, height: 150)) -> MKScene {
        let text = MKNode.liveText(MKLiveTextNode(
            core: MKNodeCore(name: "Emoji", transform: MKTransform2D(position: CGPoint(x: 30, y: 60)), style: MKStyle(fill: .solid(.black))),
            text: MKSourceText(string: "Hi 😀"),
            style: MKTextStyle(font: userImportedFontRef, pointSize: 28, baseDirection: .leftToRight)
        ))
        return MKScene(canvas: MKCanvasSpec(size: canvasSize), nodes: [text])
    }

    /// Path text on a simple arc ، exercises `MKPathTextNode`'s
    /// always-outlined SVG path and the PDF vector writer's unmodified
    /// `PathTextDrawer` (live text-mode) path.
    static func pathTextScene(
        canvasSize: CGSize = CGSize(width: 300, height: 300), font: MKFontRef = realFontRef,
        highlightColor: MKSolidColor? = nil
    ) -> MKScene {
        let path = MKBezierPathData(segments: [
            MKBezierSegment(start: CGPoint(x: 40, y: 200), c1: CGPoint(x: 100, y: 60), c2: CGPoint(x: 220, y: 60), end: CGPoint(x: 260, y: 200)),
        ], isClosed: false)
        var style = MKTextStyle(font: font, pointSize: 20, baseDirection: .leftToRight)
        style.highlightColor = highlightColor
        let node = MKNode.pathText(MKPathTextNode(
            core: MKNodeCore(name: "PathText", style: MKStyle(fill: .solid(.black))),
            text: MKSourceText(string: "Arc Text"),
            style: style,
            path: path
        ))
        return MKScene(canvas: MKCanvasSpec(size: canvasSize), nodes: [node])
    }

    /// A minimal `MKArrangedTextNode` ، TWO synthetic "glyphs" (simple
    /// square outlines, not real font-extracted paths ، arranged content's
    /// whole point is that it NEVER re-consults the font at render/export
    /// time, INV-13, so a synthetic outline is exactly as representative
    /// as a real one for exercising the writer's own geometry/transform
    /// code) side by side, plus one mark glyph attached to the first.
    static func arrangedScene(canvasSize: CGSize = CGSize(width: 300, height: 200)) -> MKScene {
        func squareOutline() -> MKPathData {
            // A 500×500 unit square in glyph space (unitsPerEm 1000, so
            // this occupies the lower-left half of the em box) ، commands:
            // 0=move,1=line×3,4=close.
            MKPathData(commands: [
                0, 0, 0,
                1, 500, 0,
                1, 500, 500,
                1, 0, 500,
                4,
            ], unitsPerEm: 1000)
        }
        let baseGlyph = MKGlyphNode(
            glyph: MKGlyphRef(glyphID: 1, font: realFontRef, fontChecksum: "abc123"),
            outline: squareOutline(),
            layout: MKGlyphLayout(position: CGPoint(x: 0, y: 0), advance: CGSize(width: 30, height: 0)),
            style: MKStyle(fill: .solid(.black)),
            provenance: MKProvenance(clusterID: MKClusterID(), codepoints: [0x0644], utf16Start: 0, utf16Length: 1, bidiLevel: 1, visualIndex: 0, logicalIndex: 0)
        )
        let secondGlyph = MKGlyphNode(
            glyph: MKGlyphRef(glyphID: 2, font: realFontRef, fontChecksum: "abc123"),
            outline: squareOutline(),
            layout: MKGlyphLayout(position: CGPoint(x: 40, y: 0), advance: CGSize(width: 30, height: 0)),
            style: MKStyle(fill: .solid(MKSolidColor(r: 0.2, g: 0.4, b: 0.7))),
            provenance: MKProvenance(clusterID: MKClusterID(), codepoints: [0x0627], utf16Start: 1, utf16Length: 1, bidiLevel: 1, visualIndex: 1, logicalIndex: 1)
        )
        let markOutline = MKPathData(commands: [0, 0, 0, 1, 100, 0, 1, 100, 100, 1, 0, 100, 4], unitsPerEm: 1000)
        let mark = MKMarkNode(
            glyph: MKGlyphRef(glyphID: 3, font: realFontRef, fontChecksum: "abc123"),
            outline: markOutline,
            attachedTo: baseGlyph.id,
            relativeOffset: CGSize(width: 5, height: -25),
            style: MKStyle(fill: .solid(MKSolidColor(r: 0.6, g: 0.1, b: 0.1))),
            provenance: MKProvenance(clusterID: MKClusterID(), codepoints: [0x064B], utf16Start: 0, utf16Length: 1, bidiLevel: 1, visualIndex: 2, logicalIndex: 0),
            markClass: .tashkeel
        )
        let backup = MKSourceTextBackup(sourceString: "لا", style: MKTextStyle(font: realFontRef, pointSize: 40))
        let composition = ArrangedComposition(
            nodes: [.glyph(baseGlyph), .glyph(secondGlyph), .mark(mark)],
            sourceBackup: backup,
            originFrame: CGRect(x: 0, y: 0, width: 80, height: 40)
        )
        let arranged = MKNode.arranged(MKArrangedTextNode(
            core: MKNodeCore(name: "Arranged", transform: MKTransform2D(position: CGPoint(x: 100, y: 100))),
            composition: composition, derivedFrom: .liveText
        ))
        return MKScene(canvas: MKCanvasSpec(size: canvasSize), nodes: [arranged])
    }

    /// D-227(4)'s literal accept fixture: "emoji-inside-arranged-group
    /// fixture exports as image element (not outlined)." Provenance
    /// codepoints are supplied directly on the fixture (matching how a
    /// REAL `MKArrange` derivation would tag an emoji cluster's
    /// `MKProvenance.codepoints`) rather than depending on live font
    /// shaping through a Latin-only stub font resolving U+1F600 (which
    /// `SystemFontStubProvider`/"Helvetica" cannot do) ، `MKArrangedTextNode`
    /// content NEVER re-consults the font at export time anyway (INV-13),
    /// so this is the representative way to exercise this specific carve-out.
    static func arrangedSceneWithEmoji(canvasSize: CGSize = CGSize(width: 300, height: 200)) -> MKScene {
        let emojiOutline = MKPathData(commands: [0, 0, 0, 1, 600, 0, 1, 600, 600, 1, 0, 600, 4], unitsPerEm: 1000)
        let emojiGlyph = MKGlyphNode(
            glyph: MKGlyphRef(glyphID: 9, font: realFontRef, fontChecksum: "abc123"),
            outline: emojiOutline,
            layout: MKGlyphLayout(position: CGPoint(x: 0, y: 0), advance: CGSize(width: 40, height: 0)),
            style: MKStyle(fill: .solid(.black)),
            provenance: MKProvenance(clusterID: MKClusterID(), codepoints: [0x1F600], utf16Start: 0, utf16Length: 2, bidiLevel: 0, visualIndex: 0, logicalIndex: 0)
        )
        let backup = MKSourceTextBackup(sourceString: "😀", style: MKTextStyle(font: realFontRef, pointSize: 40))
        let composition = ArrangedComposition(nodes: [.glyph(emojiGlyph)], sourceBackup: backup, originFrame: CGRect(x: 0, y: 0, width: 40, height: 40))
        let arranged = MKNode.arranged(MKArrangedTextNode(
            core: MKNodeCore(name: "ArrangedEmoji", transform: MKTransform2D(position: CGPoint(x: 100, y: 100))),
            composition: composition, derivedFrom: .liveText
        ))
        return MKScene(canvas: MKCanvasSpec(size: canvasSize), nodes: [arranged])
    }
}
