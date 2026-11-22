import CoreGraphics
import MKFoundation
import MKTextEngine

// WS-05 packet §5 task 3. Runtime-only (deliberately not `Codable` ، the
// packet's own words: "Codable-free runtime type") per-glyph placement
// output of `PathLayoutEngine.layout`, plus the user-adjustable-offset
// carry-over key (task 9: "carry over userOffsets by matching clusterID
// provenance (same codepoints + ordinal)"). `MKCluster.id` is a fresh UUID
// minted on every shaping capture (see `MKTextEngine`'s WS03-A7 note #4),
// so it is NOT a stable cross-relayout key by itself ، `PathClusterProvenanceKey`
// below is the stable substitute the packet's task 9 prose actually
// describes ("same codepoints + ordinal").

/// Stable identity for "the Nth cluster with these exact codepoints" ،
/// survives a full reshape (new `MKClusterID` UUIDs every time) as long as
/// the source text's relevant substring and its ordinal position among
/// identical clusters don't change. This is the key `PathLayoutEngine`
/// looks up user offsets by (task 9).
public struct PathClusterProvenanceKey: Hashable, Sendable {
    public var codepoints: [UInt32]
    public var occurrenceOrdinal: Int

    public init(codepoints: [UInt32], occurrenceOrdinal: Int) {
        self.codepoints = codepoints
        self.occurrenceOrdinal = occurrenceOrdinal
    }
}

/// A user-applied per-glyph nudge (task 3's "userOffset: CGPoint,
/// userRotation: CGFloat" fields), keyed by `PathClusterProvenanceKey` and
/// supplied to `PathLayoutEngine.layout` as an input dictionary ، see
/// `README.md`'s "Known schema gap" for why this is not yet persisted
/// inside `MKPathTextNode`.
public struct PathGlyphUserOffset: Hashable, Sendable {
    public var offset: CGPoint
    public var rotation: CGFloat

    public init(offset: CGPoint = .zero, rotation: CGFloat = 0) {
        self.offset = offset
        self.rotation = rotation
    }

    public static let zero = PathGlyphUserOffset()
}

/// One glyph's final placement on the path (task 3).
public struct PathGlyphPlacement: Hashable, Sendable {
    /// `(run, glyph)` address into the `MKShapedLine` this placement was
    /// computed from ، the join key `PathPlacementProvider` (task 12) uses
    /// to answer `PathPlacementProviding.placement(for:lineIndex:)`.
    public var address: MKGlyphAddress
    public var clusterID: MKClusterID
    public var provenanceKey: PathClusterProvenanceKey
    /// Arc length (points from path start) of this glyph's ANCHOR ، the
    /// advance-span midpoint for a base glyph, or the base's own anchor
    /// arc length for a mark (task 4c/4d).
    public var arcLength: CGFloat
    /// Final composition-local position (frame point + baseline-side
    /// offset + rotated user offset).
    public var position: CGPoint
    /// Final rotation, radians, CCW-positive (`MKTransform2D.rotation`
    /// convention) ، local tangent angle (join-clamped per task 8) plus
    /// `userRotation`.
    public var rotation: CGFloat
    public var userOffset: CGPoint
    public var userRotation: CGFloat
    public var isMark: Bool
    /// The base glyph's cluster id, for marks that resolved to a base
    /// (`nil` for base glyphs themselves, and for free/detached marks that
    /// had no preceding base to resolve to ، §6.3).
    public var baseClusterID: MKClusterID?

    public init(
        address: MKGlyphAddress, clusterID: MKClusterID, provenanceKey: PathClusterProvenanceKey,
        arcLength: CGFloat, position: CGPoint, rotation: CGFloat,
        userOffset: CGPoint = .zero, userRotation: CGFloat = 0,
        isMark: Bool = false, baseClusterID: MKClusterID? = nil
    ) {
        self.address = address
        self.clusterID = clusterID
        self.provenanceKey = provenanceKey
        self.arcLength = arcLength
        self.position = position
        self.rotation = rotation
        self.userOffset = userOffset
        self.userRotation = userRotation
        self.isMark = isMark
        self.baseClusterID = baseClusterID
    }
}

/// Task 4e: overflow is always recorded, never silently dropped.
public struct OverflowInfo: Hashable, Sendable {
    public var isOverflowing: Bool
    /// UTF-16 range (into the shaped line's source text) of clusters that
    /// overflowed the path ، under `.clip` these produced no placement;
    /// under `.continueTangent` they were placed via straight extension
    /// past the path's end. `nil` when `isOverflowing == false`.
    public var overflowUTF16Range: Range<Int>?
    /// `true` when the overflowing glyphs were placed via straight
    /// extension along the exit tangent (`.continueTangent`); `false` when
    /// they were clipped (`.clip`, no placement emitted).
    public var continuedStraight: Bool

    public init(isOverflowing: Bool = false, overflowUTF16Range: Range<Int>? = nil, continuedStraight: Bool = false) {
        self.isOverflowing = isOverflowing
        self.overflowUTF16Range = overflowUTF16Range
        self.continuedStraight = continuedStraight
    }

    public static let none = OverflowInfo()
}

/// `PathLayoutEngine.layout`'s full output (task 3).
public struct PathLayoutResult: Sendable {
    /// In path-traversal (global logical reading) order ، T-PTH-2's "dump
    /// per-glyph arc offsets in path-traversal order" contract.
    public var placements: [PathGlyphPlacement]
    public var overflow: OverflowInfo
    public var pathLength: CGFloat
    /// Task 8(3): set when any adjacent base-glyph pair's rotation differs
    /// by more than `PathLayoutOptions.curvatureWarningThresholdDegrees`.
    public var curvatureWarning: Bool
    /// Highlight-ribbon support (path-text highlight painting, render +
    /// export ، see `PathHighlightRibbon`). Arc length (points) where the
    /// pen STARTED, before any glyph was placed ، `layout`'s own local
    /// `penStart` (resolves alignment + `startOffset`) for an open path,
    /// `options.startOffset` verbatim for a closed path. Additive,
    /// runtime-only field (this struct is deliberately not `Codable`, see
    /// the file header) ، defaults to `0` so every existing direct
    /// `PathLayoutResult(...)` call site (this file's own
    /// degenerate-geometry branch, and `PathPlacementProviderTests.swift`'s
    /// fixture construction) keeps compiling unchanged.
    public var penStartArcLength: CGFloat
    /// Arc length (points) where the pen FINISHED, after the last glyph's
    /// span ، `penStartArcLength + effectiveTotal` for an open path (may
    /// exceed `pathLength` under `.continueTangent` overflow ، never
    /// clamped here), the closed-path pen's final (unwrapped) cursor value
    /// for a closed path (may exceed one full `pathLength + closedPathGap`
    /// cycle if the text wraps more than once around the loop). Consumers
    /// that need the ribbon to stop at the path's physical geometry (the
    /// `.clip` overflow policy, or a closed-path partial wrap) resolve
    /// that against `pathLength`/`closedPathGap` themselves ، see
    /// `PathHighlightRibbon`'s and `PathTextDrawer`'s own doc comments for
    /// exactly how.
    public var penEndArcLength: CGFloat

    public init(
        placements: [PathGlyphPlacement], overflow: OverflowInfo, pathLength: CGFloat, curvatureWarning: Bool,
        penStartArcLength: CGFloat = 0, penEndArcLength: CGFloat = 0
    ) {
        self.placements = placements
        self.overflow = overflow
        self.pathLength = pathLength
        self.curvatureWarning = curvatureWarning
        self.penStartArcLength = penStartArcLength
        self.penEndArcLength = penEndArcLength
    }
}
