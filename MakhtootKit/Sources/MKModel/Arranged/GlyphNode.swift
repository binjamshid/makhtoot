import CoreGraphics
import Foundation
import MKFoundation

// WS-02 packet §5 task 4. One arranged base glyph (glossary: Glyph Node) ،
// the both-levels contract's shaped-glyph half (D-106). `MKGlyphRef` and
// `MKProvenance` are declared here (not split into their own undeclared
// files) since `MKGlyphNode` is their only real owner in this packet's
// deliverable list ، `MKMarkNode`/`MKLigatureGroup` (sibling files) reuse
// both types directly.

/// Stable pointer to one glyph within one font (D-106: "glyph id, font
/// ref"). `fontChecksum` guards against silent re-render drift if the
/// referenced font file is ever replaced on disk with different outlines
/// (risk RSK-03) ، a mismatch is a signal to WS-09/WS-07, not a decode
/// failure; this type stores the checksum unconditionally regardless of
/// whether anything currently checks it.
public struct MKGlyphRef: Hashable, Sendable, Codable, Equatable {
    /// `CGGlyph` is a `UInt16` typealias; stored as `UInt16` directly so
    /// this type has no CoreText/CoreGraphics-glyph-API dependency beyond
    /// the numeric id itself.
    public var glyphID: UInt16
    public var font: MKFontRef
    /// Hex string of the font's `sfnt` `head.checkSumAdjustment`.
    public var fontChecksum: String
    /// Variable-font axis values, if the font instance is non-default.
    public var variationCoordinates: [String: Double]?

    public init(glyphID: UInt16, font: MKFontRef, fontChecksum: String, variationCoordinates: [String: Double]? = nil) {
        self.glyphID = glyphID
        self.font = font
        self.fontChecksum = fontChecksum
        self.variationCoordinates = variationCoordinates
    }
}

/// Shaped position/advance/path-tangent captured at Arrange derivation time
/// (D-106: "path, position, advance").
public struct MKGlyphLayout: Hashable, Sendable, Codable, Equatable {
    /// Composition-space position at derivation.
    public var position: CGPoint
    /// `CTRunGetAdvances` result.
    public var advance: CGSize
    /// Local path tangent angle (radians) ، set only for path-derived
    /// glyphs (D-110); `nil` for glyphs arranged from plain Live Text.
    public var pathTangentAngle: Double?

    public init(position: CGPoint, advance: CGSize, pathTangentAngle: Double? = nil) {
        self.position = position
        self.advance = advance
        self.pathTangentAngle = pathTangentAngle
    }
}

/// Exact link back to Unicode ، the "both levels supported" contract
/// (D-106/BRIEF: "store codepoint sequences + resolved glyph/shaping-form
/// references so switching level loses nothing"). Shared by
/// `MKGlyphNode`/`MKMarkNode`/`MKLigatureGroup` (task 4's "provenance
/// fields all non-optional where D-106 requires").
public struct MKProvenance: Hashable, Sendable, Codable, Equatable {
    /// Key into the owning `ArrangedComposition`'s cluster grouping ، see
    /// note on cluster-table scope in `ArrangedComposition.swift`.
    public var clusterID: MKClusterID
    /// Unicode scalar values this node realizes (D-105/D-106: "source
    /// codepoints"), in logical (typed) order.
    public var codepoints: [UInt32]
    /// UTF-16 range of `codepoints` within `MKSourceTextBackup.sourceString`.
    public var utf16Start: Int
    public var utf16Length: Int
    /// Unicode Bidi Algorithm embedding level (0...125, D-109).
    public var bidiLevel: UInt8
    /// Index in the arranged composition's visual (paint) order.
    public var visualIndex: Int
    /// Index in logical (typed/reading) order.
    public var logicalIndex: Int
    /// WS-16 (D-222 step 8 / `docs/impl-log/WS-16-cursive.md`, ADR
    /// WS16-A2): `true` when this node's glyph is a member of its font's
    /// GPOS 'curs' (LookupType 3, cursive attachment) coverage ، mirrors
    /// `MKTextEngine.MKShapedRun.cursiveAttached` at the exact glyph the
    /// consuming deriver (`MKArrange.ArrangeDeriver`, see CONTRACTS.md's
    /// WS-16 follow-up section) captured this node from. Pure provenance:
    /// `layout.position`/`relativeOffset` already carry the real,
    /// Core-Text-computed cursive-adjusted placement regardless of this
    /// flag's value (D-105 ، "the shaped positions already encode the
    /// answer"); this field exists only so join-break/restore and ligature-
    /// decompose logic (which RESHAPES a glyph via D-107's synthetic-ZWJ-
    /// context technique, unable to reproduce a contextual cursive-variant
    /// glyph a real neighbor would have triggered) can recognize the case
    /// and treat it as the same accepted-by-design, documented fidelity
    /// limitation D-222 already establishes for single-glyph scale inside a
    /// joined word, instead of silently claiming an exact round-trip.
    /// Additive field: defaults to `false` on both the memberwise init and
    /// on decode (see `init(from:)` below) so every pre-existing call site
    /// and every already-persisted `scene.json` document ، which has no
    /// `cursiveAttached` key at all ، keeps compiling/decoding unchanged,
    /// with no `schemaVersion` bump needed (same "new, defaulted, additive
    /// field" pattern this file's sibling `ArrangedComposition.swift`
    /// already documents for its own future fields).
    public var cursiveAttached: Bool

    public init(
        clusterID: MKClusterID,
        codepoints: [UInt32],
        utf16Start: Int,
        utf16Length: Int,
        bidiLevel: UInt8,
        visualIndex: Int,
        logicalIndex: Int,
        cursiveAttached: Bool = false
    ) {
        self.clusterID = clusterID
        self.codepoints = codepoints
        self.utf16Start = utf16Start
        self.utf16Length = utf16Length
        self.bidiLevel = bidiLevel
        self.visualIndex = visualIndex
        self.logicalIndex = logicalIndex
        self.cursiveAttached = cursiveAttached
    }

    private enum CodingKeys: String, CodingKey {
        case clusterID, codepoints, utf16Start, utf16Length, bidiLevel, visualIndex, logicalIndex, cursiveAttached
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clusterID = try container.decode(MKClusterID.self, forKey: .clusterID)
        codepoints = try container.decode([UInt32].self, forKey: .codepoints)
        utf16Start = try container.decode(Int.self, forKey: .utf16Start)
        utf16Length = try container.decode(Int.self, forKey: .utf16Length)
        bidiLevel = try container.decode(UInt8.self, forKey: .bidiLevel)
        visualIndex = try container.decode(Int.self, forKey: .visualIndex)
        logicalIndex = try container.decode(Int.self, forKey: .logicalIndex)
        // Additive field (see doc comment above): absent in any scene.json
        // written before WS-16 ، defaults to `false`, not a decode failure.
        cursiveAttached = try container.decodeIfPresent(Bool.self, forKey: .cursiveAttached) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clusterID, forKey: .clusterID)
        try container.encode(codepoints, forKey: .codepoints)
        try container.encode(utf16Start, forKey: .utf16Start)
        try container.encode(utf16Length, forKey: .utf16Length)
        try container.encode(bidiLevel, forKey: .bidiLevel)
        try container.encode(visualIndex, forKey: .visualIndex)
        try container.encode(logicalIndex, forKey: .logicalIndex)
        try container.encode(cursiveAttached, forKey: .cursiveAttached)
    }
}

/// One base glyph, independently selectable/transformable (glossary: Glyph
/// Node). D-106: "Glyph Nodes (glyph id, font ref, path, position, advance,
/// joining state, source codepoints)".
public struct MKGlyphNode: Hashable, Sendable, Codable, Equatable {
    public var id: MKNodeID
    public var glyph: MKGlyphRef
    /// Cached `CTFontCreatePathForGlyph` outline, persisted (not just
    /// cached) per §3.4 design notes ، arranged nodes stay render-complete
    /// even when the source font later locks or drifts. `nil` only
    /// transiently, before first extraction.
    public var outline: MKPathData?
    public var layout: MKGlyphLayout
    /// User-applied deltas on top of `layout.position` (independent
    /// per-glyph move/rotate/scale, BRIEF "per-object" manipulation).
    public var transform: MKTransform2D
    public var style: MKStyle
    public var provenance: MKProvenance
    public var joining: MKJoiningState
    public var isHidden: Bool
    public var isLocked: Bool

    public init(
        id: MKNodeID = MKNodeID(),
        glyph: MKGlyphRef,
        outline: MKPathData? = nil,
        layout: MKGlyphLayout,
        transform: MKTransform2D = .identity,
        style: MKStyle = .default,
        provenance: MKProvenance,
        joining: MKJoiningState = .isolatedDefault,
        isHidden: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.glyph = glyph
        self.outline = outline
        self.layout = layout
        self.transform = transform
        self.style = style
        self.provenance = provenance
        self.joining = joining
        self.isHidden = isHidden
        self.isLocked = isLocked
    }
}
