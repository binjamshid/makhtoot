import CoreGraphics
import Foundation
import MKFoundation

// WS-05 gap 2 (`Sources/MKPathText/README.md`'s "Known schema gap" section /
// `CONTRACTS.md`'s WS-05 "Known schema gap" section). `MKPathText.PathLayoutEngine`
// has always accepted a `[PathClusterProvenanceKey: PathGlyphUserOffset]`
// input and folded it into placement ، but `MKPathText.PathClusterProvenanceKey`
// / `PathGlyphUserOffset` (`Sources/MKPathText/PathGlyphPlacement.swift`) are
// deliberately NOT `Codable` ("Codable-free runtime type", that file's own
// words) and `MKModel` cannot import `MKPathText` to reuse them directly
// (the dependency edge runs the other way: `MKPathText -> MKModel`, per
// `CONTRACTS.md`'s WS-05 dependency-graph section). The two small value
// types below are the persisted, `Codable` counterparts `MKPathTextNode`
// stores ، a structural mirror across the module boundary, the same
// pattern `Makhtoot/AppShell/Scenes/Editor/MKArrangeEngineProviding.swift`'s
// `MKArrangeFormOption` already established for mirroring `MKArrange.MKFormOption`
// into `MKCanvas` without an import edge.

/// Persisted counterpart of `MKPathText.PathClusterProvenanceKey` ، same two
/// fields, same names, same stability contract: "the Nth cluster with these
/// exact codepoints" survives a full reshape (a fresh `MKClusterID` UUID is
/// minted on every shaping capture, so that id is NOT usable as a stable
/// persistence key) as long as the source text's relevant substring and its
/// ordinal position among identical clusters don't change.
public struct MKPathGlyphOffsetKey: Hashable, Sendable, Codable, Equatable {
    public var codepoints: [UInt32]
    public var occurrenceOrdinal: Int

    public init(codepoints: [UInt32], occurrenceOrdinal: Int) {
        self.codepoints = codepoints
        self.occurrenceOrdinal = occurrenceOrdinal
    }
}

/// Persisted counterpart of `MKPathText.PathGlyphUserOffset` ، a user-applied
/// per-glyph nudge (position + rotation) on top of a path-text glyph's
/// engine-computed placement. `rotation` is stored as `Double` rather than
/// the engine type's `CGFloat`, matching this module's own convention of
/// `Double` over `CGFloat` for persisted fields (see e.g.
/// `MKPathLayoutOptions.startOffset` in `MKNode.swift`) ، JSON has no native
/// `CGFloat`, and `Double` avoids the platform-width ambiguity `CGFloat`
/// carries on encode/decode.
public struct MKPathGlyphOffset: Hashable, Sendable, Codable, Equatable {
    public var offset: CGPoint
    public var rotation: Double

    public init(offset: CGPoint = .zero, rotation: Double = 0) {
        self.offset = offset
        self.rotation = rotation
    }

    public static let zero = MKPathGlyphOffset()
}
