import CoreGraphics
import Foundation
import MKFoundation

// WS-02 packet §5 task 4. Combining mark (glossary: Mark Node) ، tashkeel
// and Qur'anic annotation glyphs, attached to a base `MKGlyphNode` by id
// reference (not tree containment) so detaching a mark is a single field
// change, not a tree move (§3.4 design notes: "undo stays trivial and
// provenance stays intact").

public enum MKMarkClass: String, Hashable, Sendable, Codable {
    /// Standard tashkeel: fatha, damma, kasra, sukun, shadda, tanwin, etc.
    /// (U+064B–065F, U+0610–061A).
    case tashkeel
    /// Qur'anic recitation annotation marks (U+06D6–06ED).
    case quranicAnnotation
    /// Any other Unicode Mn/Me combining mark not covered above.
    case otherCombining
}

/// One attached (or explicitly detached) combining mark (glossary: Mark
/// Node). D-106: "Mark Nodes (attached, relative offset, follow-base
/// default)"; BRIEF: "tashkeel attach to base by default, follow it,
/// individually selectable/detachable/movable."
public struct MKMarkNode: Hashable, Sendable, Codable, Equatable {
    public var id: MKNodeID
    public var glyph: MKGlyphRef
    public var outline: MKPathData?
    /// Base glyph node this mark is anchored to; `nil` = detached (an
    /// explicit user act per BRIEF, not an error state).
    public var attachedTo: MKNodeID?
    /// GPOS-captured offset from the base's anchor point, in base-local
    /// space (D-105).
    public var relativeOffset: CGSize
    /// Default `true`: the base's transform composes onto this mark's
    /// position so moving/rotating the base carries its marks along.
    public var followsBase: Bool
    /// The mark's own transform, applied AFTER `relativeOffset` ، lets a
    /// user nudge one mark independently without disturbing the anchor.
    public var transform: MKTransform2D
    public var style: MKStyle
    public var provenance: MKProvenance
    public var markClass: MKMarkClass
    /// Paint/stacking order among multiple marks on the same base (e.g.
    /// shadda below, fatha above) ، a dedicated field, deliberately not
    /// overloaded onto `provenance.visualIndex` (that index is the
    /// composition-wide visual order, a different axis).
    public var stackIndex: Int
    public var isHidden: Bool
    public var isLocked: Bool

    public init(
        id: MKNodeID = MKNodeID(),
        glyph: MKGlyphRef,
        outline: MKPathData? = nil,
        attachedTo: MKNodeID?,
        relativeOffset: CGSize = .zero,
        followsBase: Bool = true,
        transform: MKTransform2D = .identity,
        style: MKStyle = .default,
        provenance: MKProvenance,
        markClass: MKMarkClass,
        stackIndex: Int = 0,
        isHidden: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.glyph = glyph
        self.outline = outline
        self.attachedTo = attachedTo
        self.relativeOffset = relativeOffset
        self.followsBase = followsBase
        self.transform = transform
        self.style = style
        self.provenance = provenance
        self.markClass = markClass
        self.stackIndex = stackIndex
        self.isHidden = isHidden
        self.isLocked = isLocked
    }
}
