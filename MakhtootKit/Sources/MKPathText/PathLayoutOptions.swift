import CoreGraphics
import MKModel

// WS-05 packet §5 tasks 6/7/8. `MKModel.MKPathLayoutOptions`
// (`startOffset`/`side`/`spacingMode`) is the PERSISTED slice of these
// knobs ، the only path-layout fields `MKPathTextNode` currently stores
// (see `MKNode.swift`). This module's `PathLayoutOptions` is the fuller
// ENGINE-level options set the packet's tasks 6/7/8 ask for (alignment,
// numeric baseline-offset magnitude, overflow policy, inside-out flip,
// closed-path gap, extra letter spacing, join-continuity thresholds) ،
// every field beyond the three `MKModel` ones is **engine-only, not yet
// persisted** (see `README.md`'s "Known schema gap" section: `MKModel`
// would need a small additive field set to carry them across app
// launches; out of this packet's fence, which may only touch
// `MKPathText`/`Package.swift`). `PathLayoutEngine` still honors them
// fully within a session/test ، this is a real, tested capability, just
// one whose persistence needs a follow-up `MKModel` patch.
public enum PathAlignment: String, Hashable, Sendable {
    /// The laid text's arc-length start sits at `startOffset` ، in
    /// `rtlNatural`-style logical-order layout (DF-6a) this means the
    /// FIRST TYPED character sits at the path start, matching what an
    /// Arabic user expects when drawing a path start-to-end (task 6).
    case start
    /// The laid text is centered within the available path span (after
    /// `startOffset`).
    case center
    /// The laid text's arc-length end sits at the path's end (open path)
    /// or wraps to sit flush before `closedPathGap` (closed path).
    case end
}

public enum PathOverflowPolicy: String, Hashable, Sendable {
    /// Glyphs whose span exceeds the path's remaining length are excluded
    /// from `PathLayoutResult.placements`; `OverflowInfo.clippedUTF16Range`
    /// records exactly what was clipped (never silently dropped without a
    /// record ، task 4e).
    case clip
    /// Glyphs beyond the end continue in a straight line along the exit
    /// tangent (task 4e's "glyphs beyond end continue along the end
    /// tangent (straight extension, flagged)") ، never clipped, always
    /// flagged via `OverflowInfo.isOverflowing`.
    case continueTangent
}

public struct PathLayoutOptions: Hashable, Sendable {
    // MARK: Persisted slice (mirrors MKModel.MKPathLayoutOptions)
    public var startOffset: Double
    public var side: MKPathSide
    public var spacingMode: MKPathSpacingMode

    // MARK: Engine-only (not yet persisted ، see file header)
    /// Points, magnitude only ، sign/side is resolved from `side`
    /// (`.above` = `+magnitude` along the left normal, `.below` =
    /// `-magnitude`, `.center` = `0` regardless of this field).
    public var baselineOffsetMagnitude: Double
    public var alignment: PathAlignment
    public var overflow: PathOverflowPolicy
    /// Task 7: "flipping text to the inside of a circle = rotate
    /// placement by π" ، flips both the baseline-offset sign and adds π to
    /// every glyph's rotation so glyphs stay upright on the path's inner
    /// side instead of reading upside-down.
    public var insideOut: Bool
    /// Points of blank arc length inserted once per revolution on a closed
    /// path before the text wraps back to its own start (task 4e).
    public var closedPathGap: Double
    /// Extra points of advance added per glyph span, on top of the
    /// captured (already kerned/tracked) advance ، task 5's "useful on
    /// tight curves" knob. May be negative (the README's "joint overlap"
    /// mitigation slider).
    public var letterSpacingExtra: Double
    /// Task 8(2): if the tangent swings by more than this many degrees
    /// across one base glyph's own arc span, its rotation source switches
    /// from the span-midpoint tangent to the average of its two span-edge
    /// tangents (smooths the glyph's own rotation across a locally sharp
    /// turn). Default 25°, matching the packet's stated default.
    public var maxJoinAngleDegrees: Double
    /// Task 8(3): if the (already-clamped) rotation of two adjacent base
    /// glyphs differs by more than this many degrees, `curvatureWarning`
    /// is set on the result. Default 40°.
    public var curvatureWarningThresholdDegrees: Double

    public init(
        startOffset: Double = 0,
        side: MKPathSide = .center,
        spacingMode: MKPathSpacingMode = .natural,
        baselineOffsetMagnitude: Double = 0,
        alignment: PathAlignment = .start,
        overflow: PathOverflowPolicy = .continueTangent,
        insideOut: Bool = false,
        closedPathGap: Double = 0,
        letterSpacingExtra: Double = 0,
        maxJoinAngleDegrees: Double = 25,
        curvatureWarningThresholdDegrees: Double = 40
    ) {
        self.startOffset = startOffset
        self.side = side
        self.spacingMode = spacingMode
        self.baselineOffsetMagnitude = baselineOffsetMagnitude
        self.alignment = alignment
        self.overflow = overflow
        self.insideOut = insideOut
        self.closedPathGap = closedPathGap
        self.letterSpacingExtra = letterSpacingExtra
        self.maxJoinAngleDegrees = maxJoinAngleDegrees
        self.curvatureWarningThresholdDegrees = curvatureWarningThresholdDegrees
    }

    /// Seeds the persisted slice from a `pathText` node's stored
    /// `MKPathLayoutOptions`, engine-only fields at their documented
    /// defaults.
    public init(node: MKPathLayoutOptions) {
        self.init(startOffset: node.startOffset, side: node.side, spacingMode: node.spacingMode)
    }

    /// The persisted slice, for writing back into `MKPathTextNode.layout`.
    public var persistedSlice: MKPathLayoutOptions {
        MKPathLayoutOptions(startOffset: startOffset, side: side, spacingMode: spacingMode)
    }

    /// Signed baseline offset (points, along the frame's left normal) ،
    /// resolves `side` + `baselineOffsetMagnitude` + `insideOut` into one
    /// number `PathLayoutEngine` adds along `frame.normal`. `public`
    /// (widened from module-internal for `PathHighlightRibbon`'s highlight
    /// pass, `MKRender/Drawers/PathTextDrawer.swift`): the ribbon MUST use
    /// this exact resolved value rather than re-deriving its own copy of
    /// the `side`/`baselineOffsetMagnitude`/`insideOut` resolution, or the
    /// two can silently drift the next time this formula changes in one
    /// place and not the other.
    public var signedBaselineOffset: Double {
        let base: Double
        switch side {
        case .above: base = baselineOffsetMagnitude
        case .below: base = -baselineOffsetMagnitude
        case .center: base = 0
        }
        return insideOut ? -base : base
    }
}
