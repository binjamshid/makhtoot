import Foundation

// P16 (MASTER-PLAN P5.1, Bug 10 fix). RGB<->HSB conversion, kept in
// `MKColor` (not `MKModel`, matching `MKColorSpec.swift`'s own "MKColor
// owns conversion" boundary) so `MKColorPickerSheet` (Makhtoot app target)
// has ONE testable, non-UI-framework conversion to call instead of hand-
// rolling hue/saturation math inline in a SwiftUI view. That inline math
// (the previous `MKColorPickerSheet.init`) is exactly how Bug 10 shipped:
// the sheet computed a `saturation` from the seed color but never exposed
// a control to CHANGE it, and the computation itself lived nowhere a unit
// test could reach it.
//
// Achromatic edge case (`r == g == b`, `delta == 0`): `hue` is
// mathematically undefined here; this type returns `0` rather than NaN or
// garbage, matching AppKit's own
// `NSColor.getHue(_:saturation:brightness:alpha:)` convention. A caller
// that wants to REMEMBER a hue across an achromatic edit (so dragging
// brightness on a gray swatch doesn't silently reset an on-screen hue
// slider to red) owns that as its OWN UI state ، this type is pure,
// stateless math with no such memory, and in particular holds no `static`
// state (the previous `MKColorPickerSheet.previousHue: static var` bug ،
// shared mutable state leaking a hue between independent picker instances
// ، has no equivalent here by construction).

/// Hue/saturation/brightness/alpha, each nominally `0...1` (`hue` wraps:
/// `0` and `1` name the same red). Pure value type, no CoreGraphics/UIKit
/// dependency ، safe to unit test directly.
public struct MKHSBAComponents: Hashable, Sendable, Equatable {
    public var hue: Double
    public var saturation: Double
    public var brightness: Double
    public var alpha: Double

    public init(hue: Double, saturation: Double, brightness: Double, alpha: Double = 1) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.alpha = alpha
    }
}

extension MKColorSpec {
    /// RGB → HSB. Input components are clamped to `0...1` first ، D-117's
    /// extended-range sRGB (components may exceed `0...1`) has no
    /// meaningful HSB analogue outside the unit cube, and this conversion
    /// exists for picker UI only (never round-tripped through document
    /// storage, which stays RGBA per D-117).
    public var hsba: MKHSBAComponents {
        let r = min(1, max(0, self.r))
        let g = min(1, max(0, self.g))
        let b = min(1, max(0, self.b))
        let a = min(1, max(0, self.a))
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC

        let brightness = maxC
        let saturation = maxC > 0 ? delta / maxC : 0

        var hue: Double = 0
        if delta > .ulpOfOne {
            if maxC == r {
                hue = (g - b) / delta
                if hue < 0 { hue += 6 }
            } else if maxC == g {
                hue = (b - r) / delta + 2
            } else {
                hue = (r - g) / delta + 4
            }
            hue /= 6
        }
        return MKHSBAComponents(hue: hue, saturation: saturation, brightness: brightness, alpha: a)
    }

    /// HSB → RGB (standard sector formula, e.g. Foley & van Dam). `hue` is
    /// taken modulo `1` first so a value that's momentarily outside
    /// `0...1` (a slider drag that overshoots by a fraction of a pixel)
    /// still resolves to a valid color instead of falling through the
    /// sector `switch`.
    public init(hsba: MKHSBAComponents) {
        var h = hsba.hue.truncatingRemainder(dividingBy: 1)
        if h < 0 { h += 1 }
        let s = min(1, max(0, hsba.saturation))
        let v = min(1, max(0, hsba.brightness))

        let c = v * s
        let hPrime = h * 6
        let x = c * (1 - abs(hPrime.truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c

        let components: (r: Double, g: Double, b: Double)
        switch hPrime {
        case 0..<1: components = (c, x, 0)
        case 1..<2: components = (x, c, 0)
        case 2..<3: components = (0, c, x)
        case 3..<4: components = (0, x, c)
        case 4..<5: components = (x, 0, c)
        default: components = (c, 0, x)
        }
        self.init(r: components.r + m, g: components.g + m, b: components.b + m, a: hsba.alpha)
    }
}
