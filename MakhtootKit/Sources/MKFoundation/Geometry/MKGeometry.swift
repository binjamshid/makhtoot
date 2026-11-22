import CoreGraphics

/// Canonical 2-D point type used across the scene graph, canvas, and export
/// pipelines. Bridges directly to `CGPoint` so callers can move between
/// MakhtootKit APIs and CoreGraphics/UIKit without conversion ceremony.
public typealias MKPoint = CGPoint

/// Canonical 2-D size type. See `MKPoint`.
public typealias MKSize = CGSize

/// Canonical rectangle type. See `MKPoint`.
public typealias MKRect = CGRect

/// Small geometry helpers shared by the canvas, path-text, and export
/// modules (WS-05/06/08) that don't belong on `MKTransform2D` itself.
public enum MKGeometryMath {
    /// Normalizes an angle in radians into the `[0, 2π)` range.
    public static func normalizeAngle(_ radians: CGFloat) -> CGFloat {
        let twoPi = CGFloat.pi * 2
        var angle = radians.truncatingRemainder(dividingBy: twoPi)
        if angle < 0 { angle += twoPi }
        return angle
    }

    /// Returns the smallest rectangle that contains both inputs.
    public static func union(_ a: MKRect, _ b: MKRect) -> MKRect {
        a.union(b)
    }

    /// Fits `size` inside `bounds` preserving aspect ratio (contain, not
    /// cover) ، used by canvas presets and thumbnail generation.
    public static func aspectFit(_ size: MKSize, in bounds: MKSize) -> MKSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        return MKSize(width: size.width * scale, height: size.height * scale)
    }
}
