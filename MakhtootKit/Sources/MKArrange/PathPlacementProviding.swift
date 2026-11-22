import CoreGraphics
import MKFoundation
import MKTextEngine

// WS-04 packet §5 task 1: the shared seam with WS-05 (`MKPathText`) for
// arrange-on-path. WS-05 hands `ArrangeDeriver` per-glyph final positions +
// rotations already resolved in the path's arc-length space; `ArrangeDeriver`
// itself never touches Bézier/arc-length math (that engine is entirely
// WS-05's, per FOUNDATION §2's module map). Until WS-05 lands, callers
// deriving from plain Live Text pass `IdentityPlacement()`, under which
// every glyph keeps its normal straight-baseline shaped position ، i.e.
// `placement(for:lineIndex:)` returning `nil` is the "no path override, use
// the captured position as-is" signal `ArrangeDeriver` reads.

/// One glyph's final placement when arranging text that sits on a path
/// (D-110): the composition-local position (same axis convention
/// `ArrangeDeriver` otherwise derives from `CTRunGetPositions` ، see
/// `ArrangeDeriver.swift`'s coordinate-convention note) plus the local path
/// tangent angle, which becomes `MKGlyphLayout.pathTangentAngle`.
public struct MKPathGlyphPlacement: Sendable, Equatable {
    public var position: CGPoint
    /// Radians, same convention as `MKTransform2D.rotation`
    /// (counter-clockwise positive).
    public var tangentAngle: CGFloat

    public init(position: CGPoint, tangentAngle: CGFloat) {
        self.position = position
        self.tangentAngle = tangentAngle
    }
}

/// The WS-04/WS-05 seam (packet task 1). Conformers supply a final
/// position + rotation for a shaped glyph, addressed the same way
/// `MKTextEngine`'s capture output addresses it (`MKGlyphAddress` within a
/// given line). `ArrangeDeriver` calls this once per glyph while building
/// `MKGlyphLayout`; a `nil` result means "no path override for this glyph,
/// use the straight-baseline shaped position" (the case every plain
/// Live-Text derivation hits for every glyph, via `IdentityPlacement`).
///
/// WS-05 develops against this protocol using its own conformer (arc-length
/// LUT walk, RTL-aware pen advance per D-110) without needing
/// `ArrangeDeriver`'s internals; `ArrangeDeriver` develops against
/// `IdentityPlacement` without needing WS-05 to exist yet. Neither side
/// blocks the other ، the documented purpose of a protocol seam (packet
/// §3: "you may develop against a straight-line fake conforming to the
/// same `PathPlacementProviding` protocol").
public protocol PathPlacementProviding: Sendable {
    func placement(for address: MKGlyphAddress, lineIndex: Int) -> MKPathGlyphPlacement?
}

/// The straight-baseline fake every plain Live-Text derivation uses
/// (packet task 1's required "ship `IdentityPlacement`"). Returns `nil`
/// unconditionally, meaning "defer entirely to the shaped-line capture
/// position" ، `ArrangeDeriver` never invents a straight-line placement of
/// its own to hand back through this protocol; it simply skips the path
/// override step when every call returns `nil`.
public struct IdentityPlacement: PathPlacementProviding {
    public init() {}
    public func placement(for address: MKGlyphAddress, lineIndex: Int) -> MKPathGlyphPlacement? { nil }
}
