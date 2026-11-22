import CoreGraphics
import Foundation

// WS-02 (AGENT_TASK_PACKETS/WS-02-model-persistence.md §5 task 1). Node-level
// paint style: fill (v1 = solid color only, D-111/D-117), stroke, shadow.
// Every type here is `Hashable, Sendable, Codable, Equatable` per the task's
// accept criterion, and every `Decodable` conformance here is the
// compiler-synthesized kind, which already tolerates unknown JSON keys (it
// only looks up the keys it declares) ، satisfying "decode ignores unknown
// fields" without any custom container code.

/// Color working space tag persisted alongside every color value (D-117:
/// working space = extended sRGB; only `srgb` exists in v1 ، CMYK is an
/// export-time conversion in `MKColor`, never a storage format here).
public enum MKColorSpace: String, Hashable, Sendable, Codable {
    case srgb
}

/// Document-stored color: sRGB components (may exceed `0...1` ، values from
/// a P3-aware picker are preserved verbatim per D-117) plus an optional
/// named-swatch reference. This is distinct from the `MKColor` *module*
/// (color-space conversion, CMYK, ICC pipeline) ، deliberately named
/// `MKSolidColor` rather than `MKColor` to avoid confusion between "the
/// value stored on a node" and "the conversion engine," per FILE_MAP §6's
/// naming for this type.
public struct MKSolidColor: Hashable, Sendable, Codable, Equatable {
    public var space: MKColorSpace
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double
    /// Optional reference into a future named-swatch palette (D-117: "+
    /// optional named swatch"). No swatch catalog exists in v1; this is the
    /// storage slot a later workstream populates.
    public var swatch: String?

    public init(r: Double, g: Double, b: Double, a: Double = 1, swatch: String? = nil) {
        self.space = .srgb
        self.r = r
        self.g = g
        self.b = b
        self.a = a
        self.swatch = swatch
    }

    public static let black = MKSolidColor(r: 0, g: 0, b: 0)
    public static let white = MKSolidColor(r: 1, g: 1, b: 1)
    /// Default canvas/document ink color ، a warm near-black rather than
    /// pure black, matching the "حبر ورق" (Ink & Paper) baseline aesthetic's
    /// ink-dark foreground convention (D-126; exact token values live in
    /// `MKDesignSystem`, this is only the model-layer default).
    public static let defaultInk = MKSolidColor(r: 0.114, g: 0.098, b: 0.086)
}

/// v1 fill: solid color only (D-111). The `none` case exists for the many
/// nodes with no paint at all (e.g. an empty group).
public enum MKFill: Hashable, Sendable, Codable, Equatable {
    case none
    case solid(MKSolidColor)
}

public enum MKLineJoin: String, Hashable, Sendable, Codable {
    case miter, round, bevel
}

public enum MKLineCap: String, Hashable, Sendable, Codable {
    case butt, round, square
}

public struct MKStroke: Hashable, Sendable, Codable, Equatable {
    public var color: MKSolidColor
    public var width: Double
    public var join: MKLineJoin
    public var cap: MKLineCap

    public init(color: MKSolidColor, width: Double, join: MKLineJoin = .miter, cap: MKLineCap = .butt) {
        self.color = color
        self.width = width
        self.join = join
        self.cap = cap
    }
}

public struct MKShadow: Hashable, Sendable, Codable, Equatable {
    public var color: MKSolidColor
    public var blur: Double
    public var offset: CGSize

    public init(color: MKSolidColor, blur: Double, offset: CGSize) {
        self.color = color
        self.blur = blur
        self.offset = offset
    }
}

/// Node paint style bundle (D-111: "style (fill: solid color v1; stroke;
/// shadow)"). Opacity is deliberately **not** a member here ، D-111 lists
/// `opacity` as a sibling field of `style` on the node itself, not nested
/// inside it (see `MKNodeCore.opacity` in `MKNode.swift`), so this struct
/// stays exactly the three D-111-named paint concerns.
public struct MKStyle: Hashable, Sendable, Codable, Equatable {
    public var fill: MKFill
    public var stroke: MKStroke?
    public var shadow: MKShadow?

    public init(fill: MKFill = .none, stroke: MKStroke? = nil, shadow: MKShadow? = nil) {
        self.fill = fill
        self.stroke = stroke
        self.shadow = shadow
    }

    public static let `default` = MKStyle()
}
