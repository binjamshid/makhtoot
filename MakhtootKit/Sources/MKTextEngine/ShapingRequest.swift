import CoreGraphics
import MKFoundation
import MKModel

// P3-completion pass (WS-03 packet §5 task 1 signature; ADR WS03-A1 seam
// resolution): the early spike's local `MKTE*` stand-in request types are
// gone ، the engine now consumes the real MKModel types directly:
// `MKSourceText` (string + per-range style runs), `MKTextStyle` (font ref,
// size, tracking, baseline, line height, ligature setting, base
// direction), and `MKTextFrameSpec` (.singleLine | .widthConstrained).
// `MKFontHandle` remains the WS-01 `MKFontProviding` seam type the engine
// resolves `MKFontRef` through until WS-09 ships the real registry.

/// Everything `MKShapingEngine`/`MKShapingService` needs to shape one text
/// object. Hashable so `MKShapingService`'s LRU cache can key on the whole
/// request (ARCHITECTURE §4.7: "Key: full MKShapingRequest hash").
public struct MKShapingRequest: Hashable, Sendable {
    public var text: MKSourceText
    public var style: MKTextStyle
    public var frame: MKTextFrameSpec

    public init(text: MKSourceText, style: MKTextStyle, frame: MKTextFrameSpec = .singleLine) {
        self.text = text
        self.style = style
        self.frame = frame
    }

    /// Convenience: plain string, no per-range style runs.
    public init(string: String, style: MKTextStyle, frame: MKTextFrameSpec = .singleLine) {
        self.init(text: MKSourceText(string: string), style: style, frame: frame)
    }
}

extension MKTextStyle {
    /// The `MKFontProviding` handle for this style's font at this style's
    /// size ، the engine's single font-resolution path (E-F1 seam).
    var fontHandle: MKFontHandle {
        MKFontHandle(postScriptName: font.postScriptName, pointSize: CGFloat(pointSize))
    }
}
