import Foundation

// WS-02 packet §5 task 2. Per-object text styling: font reference, size,
// kerning/tracking/baseline/line-height, ligature setting, paragraph base
// direction. Applies both to `MKLiveTextNode`/`MKPathTextNode` (as the
// node's whole-run style + per-range overrides via `MKStyleRun`) and is
// retained verbatim inside `MKSourceTextBackup` for arranged nodes (task 5)
// so reverting an arrangement restores typography exactly.

/// D-108's "discretionary ligatures toggled via Core Text font features"
/// setting, exposed as the closed three-state enum the packet names
/// (`standard`/`discretionaryOn`/`off`) rather than raw OpenType feature
/// booleans ، `MKTextEngine` (WS-03) maps this to `kLigaturesType`/`dlig`
/// feature settings at shaping time.
public enum MKLigatureSetting: String, Hashable, Sendable, Codable {
    /// Standard ligatures only (font default contextual shaping).
    case standard
    /// Standard + discretionary ligatures enabled.
    case discretionaryOn
    /// Ligatures disabled entirely (debugging / stylistic choice).
    case off
}

/// Paragraph base direction (D-109). Default is `.rightToLeft` per D-109
/// ("paragraph base direction from `NSParagraphStyle` (default RTL)").
public enum MKBaseDirection: String, Hashable, Sendable, Codable {
    case rightToLeft
    case leftToRight
    /// Explicit RTL override regardless of first-strong-character detection
    /// (user-forced direction, e.g. an all-Latin RTL-context caption).
    case rightToLeftOverride
}

/// One cluster-pair kerning override (D-105's cluster model ، a "cluster
/// pair" is two adjacent shaped clusters). `clusterPairIndex` is a v1
/// simplification (positional index into the run's cluster-pair sequence
/// rather than a codepoint-pair key) ، sufficient for storing/round-tripping
/// user kerning nudges; `MKTextEngine`/`MKArrange` resolve the index against
/// the live shaped run.
public struct MKKernOverride: Hashable, Sendable, Codable, Equatable {
    public var clusterPairIndex: Int
    public var value: Double

    public init(clusterPairIndex: Int, value: Double) {
        self.clusterPairIndex = clusterPairIndex
        self.value = value
    }
}

/// Full per-object text style (task 2). All fields have documented v1
/// defaults so a freshly-created text node is well-formed with no caller
/// input beyond a font/size choice.
public struct MKTextStyle: Hashable, Sendable, Codable, Equatable {
    public var font: MKFontRef
    /// Points. Must be `> 0` ، callers (WS-03/WS-06) are responsible for
    /// clamping to a sane UI range; the model layer stores whatever is
    /// given.
    ///
    /// The `init` default below (`36`) is a deliberate MODEL-level
    /// fallback (raised from an earlier `24` in commit `e5d5a65`, "Default
    /// text size raised from 24pt to 36pt") for callers with no canvas in
    /// scope at all ، it is NOT a display default and `MKTextStyle` has no
    /// way to be canvas-size-aware (it doesn't know the canvas exists).
    /// Real insert paths (`EditorViewModel.insertTextFromSheet`,
    /// `.addPathText(preset:)`, `.addRectangleAtCenter()`) instead compute
    /// a canvas-scaled DISPLAY size off `min(canvas.width, canvas.height)`
    /// before constructing the node's actual `MKTextStyle` (P2.6).
    public var pointSize: Double
    public var kerningOverrides: [MKKernOverride]
    /// Points added per glyph advance (BRIEF "per-object tracking").
    public var tracking: Double
    /// Points, positive = upward (BRIEF "per-object baseline shift").
    public var baselineShift: Double
    /// Multiple of `pointSize` (BRIEF "per-object line height"; also
    /// overridable at the group level via `MKGroupNode.lineHeightOverride`).
    /// Default `1.2` ، a common comfortable-reading multiple for Arabic
    /// text with tashkeel ascenders/descenders.
    public var lineHeightMultiple: Double
    public var ligatureSetting: MKLigatureSetting
    /// Default `.rightToLeft` per D-109.
    public var baseDirection: MKBaseDirection
    /// Bold (weight override) — false by default.
    public var isBold: Bool
    /// Italic (slant override) — false by default.
    public var isItalic: Bool
    /// Underline — false by default.
    public var isUnderline: Bool
    /// Strikethrough — false by default.
    public var isStrikethrough: Bool
    /// Optional text background / highlight color, nil by default.
    public var highlightColor: MKSolidColor?

    public init(
        font: MKFontRef = .systemFallback,
        pointSize: Double = 36,
        kerningOverrides: [MKKernOverride] = [],
        tracking: Double = 0,
        baselineShift: Double = 0,
        lineHeightMultiple: Double = 1.2,
        ligatureSetting: MKLigatureSetting = .standard,
        baseDirection: MKBaseDirection = .rightToLeft,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isStrikethrough: Bool = false,
        highlightColor: MKSolidColor? = nil
    ) {
        self.font = font
        self.pointSize = pointSize
        self.kerningOverrides = kerningOverrides
        self.tracking = tracking
        self.baselineShift = baselineShift
        self.lineHeightMultiple = lineHeightMultiple
        self.ligatureSetting = ligatureSetting
        self.baseDirection = baseDirection
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isStrikethrough = isStrikethrough
        self.highlightColor = highlightColor
    }

    /// Documented default: system font, 36pt, no kerning/tracking/baseline
    /// adjustment, 1.2× line height, standard ligatures, RTL base direction.
    public static let `default` = MKTextStyle()
}
