import Foundation
import MKFoundation

// WS-02 packet §5 task 4. Multi-codepoint single-glyph cluster (glossary:
// Ligature Group). D-108: decomposing reshapes constituents with
// joining-preserving context, positions them to match the original
// ligature's visual bounds by default, and recomposition restores the
// stored original ligature glyph exactly ، hence `MKLigatureState` models
// composed/decomposed as a closed two-case state machine (not a flag) so
// "restore the stored original" is a type-level guarantee: the original
// composed glyph is *retained inside* the decomposed case, never discarded.

public struct MKComposedLigature: Hashable, Sendable, Codable, Equatable {
    public var glyph: MKGlyphRef
    public var outline: MKPathData?
    public var layout: MKGlyphLayout
    /// `false` if constituents cannot be reshaped in this font/context
    /// (risk RSK-02) ، decompose UI should disable itself when `false`.
    public var decomposable: Bool

    public init(glyph: MKGlyphRef, outline: MKPathData? = nil, layout: MKGlyphLayout, decomposable: Bool) {
        self.glyph = glyph
        self.outline = outline
        self.layout = layout
        self.decomposable = decomposable
    }
}

public enum MKFidelityMode: String, Hashable, Sendable, Codable {
    /// Constituents positioned to match the original ligature's bounds
    /// (default, D-108).
    case matchOriginal
    /// Constituents use default spacing/forms (explicit user opt-out).
    case defaultForms
}

public struct MKDecomposedLigature: Hashable, Sendable, Codable, Equatable {
    /// Reshaped constituent glyphs, joining-preserving.
    public var components: [MKGlyphNode]
    /// Per-component nudge (keyed by `MKGlyphNode.id`) matching the
    /// original ligature's bounds when `fidelityMode == .matchOriginal`.
    public var fidelityOffsets: [MKNodeID: CGSize]
    public var fidelityMode: MKFidelityMode
    /// The original composed ligature, retained so recomposition is exact
    /// (D-108: "Recomposition restores the stored original ligature
    /// glyph").
    public var original: MKComposedLigature

    public init(
        components: [MKGlyphNode],
        fidelityOffsets: [MKNodeID: CGSize] = [:],
        fidelityMode: MKFidelityMode = .matchOriginal,
        original: MKComposedLigature
    ) {
        self.components = components
        self.fidelityOffsets = fidelityOffsets
        self.fidelityMode = fidelityMode
        self.original = original
    }
}

/// Combined (one glyph, selectable as a unit) vs. decomposed (constituent
/// glyph nodes + fidelity offsets) state (D-108, glossary: "combined
/// selectable object AND decomposable components").
public enum MKLigatureState: Hashable, Sendable, Codable, Equatable {
    case composed(MKComposedLigature)
    case decomposed(MKDecomposedLigature)
}

/// One ligature cluster (glossary: Ligature Group).
public struct MKLigatureGroup: Hashable, Sendable, Codable, Equatable {
    public var id: MKNodeID
    public var state: MKLigatureState
    /// `codepoints` here are ALL constituent codepoints of the ligature
    /// (e.g. lam + alif for لا), per D-106.
    public var provenance: MKProvenance
    public var transform: MKTransform2D
    public var style: MKStyle
    /// Marks positioned against the ligature as a whole (e.g. shadda over
    /// a lam-alif) ، owned here (not on individual components) so mark
    /// anchoring survives decomposition; on decompose, each mark's
    /// `attachedTo` is re-pointed to its nearest component (§7.5 step 6,
    /// implemented by WS-04, not this packet).
    public var attachedMarks: [MKNodeID]
    public var isHidden: Bool
    public var isLocked: Bool

    public init(
        id: MKNodeID = MKNodeID(),
        state: MKLigatureState,
        provenance: MKProvenance,
        transform: MKTransform2D = .identity,
        style: MKStyle = .default,
        attachedMarks: [MKNodeID] = [],
        isHidden: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.state = state
        self.provenance = provenance
        self.transform = transform
        self.style = style
        self.attachedMarks = attachedMarks
        self.isHidden = isHidden
        self.isLocked = isLocked
    }
}
