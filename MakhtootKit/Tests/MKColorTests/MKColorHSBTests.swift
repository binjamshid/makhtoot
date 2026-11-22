import Testing
import Foundation
@testable import MKColor

// MASTER-PLAN P5.1 (Bug 10) accept: "unit-test the round-trip (RGB→HSB→RGB)
// including the achromatic edge case that caused this bug." The achromatic
// case IS the bug: `MKColorPickerSheet`'s old inline math computed
// `saturation = 0` for any near-gray seed and shipped no control to raise
// it, so every "black" text color opened the sheet already stuck at
// saturation 0 ، these tests pin the pure conversion so that class of bug
// can't silently regress in the new `MKColorPickerSheet` (which now reads
// `MKColorSpec.hsba`/`MKColorSpec(hsba:)` instead of hand-rolling this).
@Suite struct MKColorHSBTests {
    private func expectClose(_ a: Double, _ b: Double, tolerance: Double = 1e-9, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(abs(a - b) < tolerance, "\(a) !≈ \(b)", sourceLocation: sourceLocation)
    }

    // MARK: - Achromatic edge case (the actual Bug 10 repro)

    @Test func pureBlackRoundTrips() {
        let spec = MKColorSpec(r: 0, g: 0, b: 0, a: 1)
        let hsba = spec.hsba
        #expect(hsba.saturation == 0)
        #expect(hsba.brightness == 0)
        let back = MKColorSpec(hsba: hsba)
        expectClose(back.r, 0)
        expectClose(back.g, 0)
        expectClose(back.b, 0)
    }

    @Test func pureWhiteRoundTrips() {
        let spec = MKColorSpec(r: 1, g: 1, b: 1, a: 1)
        let hsba = spec.hsba
        #expect(hsba.saturation == 0)
        expectClose(hsba.brightness, 1)
        let back = MKColorSpec(hsba: hsba)
        expectClose(back.r, 1)
        expectClose(back.g, 1)
        expectClose(back.b, 1)
    }

    @Test func midGrayIsAchromaticButRoundTripsExactly() {
        // The exact seed the old bug's nil-fallback path produced
        // ((0.5, 0.5, 0.5, 0.3)) ، delta == 0 exactly, saturation == 0
        // exactly, hue mathematically undefined (this type returns 0).
        let spec = MKColorSpec(r: 0.5, g: 0.5, b: 0.5, a: 0.3)
        let hsba = spec.hsba
        #expect(hsba.saturation == 0)
        #expect(hsba.hue == 0)
        let back = MKColorSpec(hsba: hsba)
        expectClose(back.r, 0.5)
        expectClose(back.g, 0.5)
        expectClose(back.b, 0.5)
        expectClose(back.a, 0.3)
    }

    @Test func nearAchromaticColorDoesNotProduceNaNOrInfinite() {
        // delta just above the `.ulpOfOne` chromatic threshold ، guards
        // against a division blowing up right at the boundary.
        let spec = MKColorSpec(r: 0.5, g: 0.5 + 1e-12, b: 0.5, a: 1)
        let hsba = spec.hsba
        #expect(!hsba.hue.isNaN && !hsba.hue.isInfinite)
        #expect(!hsba.saturation.isNaN && !hsba.saturation.isInfinite)
    }

    // MARK: - Chromatic round trips

    @Test func primaryRedRoundTrips() {
        let spec = MKColorSpec(r: 1, g: 0, b: 0, a: 1)
        let hsba = spec.hsba
        expectClose(hsba.hue, 0)
        expectClose(hsba.saturation, 1)
        expectClose(hsba.brightness, 1)
        let back = MKColorSpec(hsba: hsba)
        expectClose(back.r, 1)
        expectClose(back.g, 0)
        expectClose(back.b, 0)
    }

    @Test func primaryGreenRoundTrips() {
        let spec = MKColorSpec(r: 0, g: 1, b: 0, a: 1)
        let hsba = spec.hsba
        expectClose(hsba.hue, 1.0 / 3.0, tolerance: 1e-6)
        let back = MKColorSpec(hsba: hsba)
        expectClose(back.r, 0, tolerance: 1e-6)
        expectClose(back.g, 1, tolerance: 1e-6)
        expectClose(back.b, 0, tolerance: 1e-6)
    }

    @Test func primaryBlueRoundTrips() {
        let spec = MKColorSpec(r: 0, g: 0, b: 1, a: 1)
        let hsba = spec.hsba
        expectClose(hsba.hue, 2.0 / 3.0, tolerance: 1e-6)
        let back = MKColorSpec(hsba: hsba)
        expectClose(back.r, 0, tolerance: 1e-6)
        expectClose(back.g, 0, tolerance: 1e-6)
        expectClose(back.b, 1, tolerance: 1e-6)
    }

    @Test func arbitraryChromaticColorsRoundTripWithinTolerance() {
        let samples: [(Double, Double, Double, Double)] = [
            (0.8, 0.2, 0.4, 1.0),      // rose
            (0.1, 0.6, 0.55, 0.75),    // teal, partial alpha
            (0.9, 0.7, 0.1, 0.5),      // gold, half alpha
            (0.3, 0.1, 0.9, 1.0),      // violet
        ]
        for (r, g, b, a) in samples {
            let spec = MKColorSpec(r: r, g: g, b: b, a: a)
            let back = MKColorSpec(hsba: spec.hsba)
            expectClose(back.r, r, tolerance: 1e-6)
            expectClose(back.g, g, tolerance: 1e-6)
            expectClose(back.b, b, tolerance: 1e-6)
            expectClose(back.a, a, tolerance: 1e-6)
        }
    }

    // MARK: - Hue wraparound

    @Test func hueZeroAndHueOneProduceTheSameColor() {
        let atZero = MKColorSpec(hsba: MKHSBAComponents(hue: 0, saturation: 1, brightness: 1))
        let atOne = MKColorSpec(hsba: MKHSBAComponents(hue: 1, saturation: 1, brightness: 1))
        expectClose(atZero.r, atOne.r, tolerance: 1e-6)
        expectClose(atZero.g, atOne.g, tolerance: 1e-6)
        expectClose(atZero.b, atOne.b, tolerance: 1e-6)
    }

    @Test func slightlyOvershootingHueStillResolvesToAValidColor() {
        let overshoot = MKColorSpec(hsba: MKHSBAComponents(hue: 1.02, saturation: 0.5, brightness: 0.9))
        #expect(overshoot.r >= 0 && overshoot.r <= 1)
        #expect(overshoot.g >= 0 && overshoot.g <= 1)
        #expect(overshoot.b >= 0 && overshoot.b <= 1)
    }

    // MARK: - Alpha independence

    @Test func alphaPassesThroughUnaffectedByHueSaturationBrightness() {
        let spec = MKColorSpec(r: 0.2, g: 0.4, b: 0.6, a: 0.42)
        #expect(spec.hsba.alpha == 0.42)
        let back = MKColorSpec(hsba: spec.hsba)
        #expect(back.a == 0.42)
    }
}
