import CoreGraphics
import MKArrange
import MKFoundation
import MKModel
import MKTextEngine

// WS-05 packet §5 task 12. The real `PathPlacementProviding` conformer for
// WS-04's arrange-on-path seam (`MKArrange/PathPlacementProviding.swift`,
// published there ، this file is the promised "WS-05 develops against this
// protocol using its own conformer" half of that seam's contract).
//
// **Dependency-edge note (documented deviation, same precedent WS-03/06/07
// already logged for their own targets).** `DEPENDENCY_GRAPH.md`'s diagram
// shows `MKPathText --> MKModel, MKPathText --> MKTextEngine` only ، no
// edge to `MKArrange`. Conforming to `MKArrange.PathPlacementProviding`
// from this module requires importing the module that DECLARES the
// protocol (Swift has no other way to conform to a protocol owned by
// another module); `MKArrange` never depends on `MKPathText` (its own
// `Package.swift` deps are `MKFoundation, MKModel, MKTextEngine,
// MKPersistence`), so the edge `MKPathText -> MKArrange` is acyclic. Added
// to `Package.swift`, logged there and in `docs/impl-log/WS-05.md`.
//
// **Coordinate-convention reconciliation (the one real subtlety in this
// file ، worked example in `README.md`).** `ArrangeDeriver`'s own file
// header (`Sources/MKArrange/ArrangeDeriver.swift`) is normative:
// `MKGlyphLayout.position` (what this protocol's `position` field
// ultimately becomes) is **composition-local, Y-UP** space ، the same
// space EVERY glyph capture position already lives in
// (`CTRunGetPositions`, never flipped). A live `pathText` node's
// `MKBezierPathData`, by contrast, is authored in the SAME space as the
// rest of the canvas/document ، **Y-DOWN** (`docs/impl-log/WS-07.md`'s
// documented convention: "document/canvas = y-down top-left, font/CoreText
// content = y-up, one axis flip at each boundary"). `PathLayoutEngine`
// itself is coordinate-convention-agnostic (pure math, no assumption baked
// in ، a live-mode caller feeding it the path exactly as authored, Y-DOWN,
// gets Y-DOWN placements back, which is what a direct-to-canvas renderer
// wants). THIS conformer is the one call site that needs the OTHER
// convention, so it performs exactly one Y-flip on the path's points
// before running the engine, and returns the result unflipped (the flip
// makes tangent angles come out already expressed in the Y-UP frame
// `ArrangeDeriver` expects ، flip-then-compute, not compute-then-negate,
// so `MKTransform2D.rotation`'s meaning stays internally consistent; see
// `PathPlacementProviderTests.arrangedGlyphMatchesLiveFlippedPlacement`
// for the numeric round-trip check).
public struct MKPathTextPlacementProvider: PathPlacementProviding {
    private let layout: PathLayoutResult
    private let byAddress: [MKGlyphAddress: PathGlyphPlacement]
    private let lineIndex: Int

    /// Builds the provider directly from an already-computed
    /// `PathLayoutResult` (e.g. one produced in the path's OWN, already
    /// Y-UP-flipped space by `Self.forArrangeOnPath`).
    public init(layout: PathLayoutResult, lineIndex: Int = 0) {
        self.layout = layout
        self.lineIndex = lineIndex
        var map: [MKGlyphAddress: PathGlyphPlacement] = [:]
        for placement in layout.placements where !placement.isMark {
            map[placement.address] = placement
        }
        self.byAddress = map
    }

    /// The seam `ArrangeDeriver` calls once per BASE glyph while building
    /// `MKGlyphNode`s (task 12: "yields final per-glyph position+rotation
    /// (including user offsets)"). Marks are intentionally never queried
    /// by `ArrangeDeriver` for a path override ، see this file's README
    /// note "Marks and arrange-on-path" ، so this only needs to answer for
    /// pen-advancing (base) glyph addresses; any other address (including
    /// mark addresses) correctly returns `nil`, which `ArrangeDeriver`
    /// reads as "no path override, use the captured straight-baseline
    /// position" (harmless for marks, since their position is derived
    /// from their BASE's already-path-placed position via
    /// `relativeOffset`, not queried here at all).
    public func placement(for address: MKGlyphAddress, lineIndex: Int) -> MKPathGlyphPlacement? {
        guard lineIndex == self.lineIndex, let p = byAddress[address] else { return nil }
        return MKPathGlyphPlacement(position: p.position, tangentAngle: p.rotation)
    }

    /// Builds a provider ready for `ArrangeDeriver.derive(...,
    /// placement:)`, performing the Y-flip documented above. `path` is the
    /// pathText node's AUTHORED (canvas Y-DOWN) `MKBezierPathData`.
    public static func forArrangeOnPath(
        line: MKShapedLine, lineIndex: Int = 0, path: MKBezierPathData, options: PathLayoutOptions,
        userOffsets: [PathClusterProvenanceKey: PathGlyphUserOffset] = [:]
    ) -> (provider: MKPathTextPlacementProvider, result: PathLayoutResult) {
        let flipped = Self.flippedY(path)
        let model = BezierPathModel(flipped)
        let result: PathLayoutResult
        if flipped.isClosed {
            result = PathLayoutEngine.layoutClosed(line: line, lineIndex: lineIndex, lut: ArcLengthLUT(path: model), options: options, userOffsets: userOffsets)
        } else {
            result = PathLayoutEngine.layout(line: line, lineIndex: lineIndex, path: model, options: options, userOffsets: userOffsets)
        }
        return (MKPathTextPlacementProvider(layout: result, lineIndex: lineIndex), result)
    }

    static func flippedY(_ path: MKBezierPathData) -> MKBezierPathData {
        func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: -p.y) }
        let segments = path.segments.map { seg in
            MKBezierSegment(start: flip(seg.start), c1: flip(seg.c1), c2: flip(seg.c2), end: flip(seg.end))
        }
        return MKBezierPathData(segments: segments, isClosed: path.isClosed)
    }
}
