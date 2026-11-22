import SwiftUI
import Testing
@testable import MKDesignSystem

/// UX-3 (AUDIT_2026-07-28.md): "No Reduce Motion, Reduce Transparency, or
/// Differentiate Without Color support... `MKMotionTokens.animation(duration:)`
/// returns a fixed `.easeInOut` with no accessibility branch."
///
/// `MKMotionTokens` is a plain `Sendable` value type with no ambient
/// `@Environment` access of its own (see `MKMotion.swift`'s own doc comment
/// on `reducesMotion` for why the flag is threaded in as data, not read
/// live from `UIAccessibility` inside this struct) ، so these tests drive
/// the flag directly rather than simulating a live system setting, exactly
/// what the plan's own Verify step calls for ("zero-duration animation when
/// reduceMotion simulated true").
@Suite("MKMotionTokens Reduce Motion (UX-3)")
struct MKMotionAccessibilityTests {
    @Test func defaultTokensDoNotReduceMotion() {
        let tokens = MKMotionTokens.default
        #expect(tokens.reducesMotion == false)
        #expect(tokens.fast == .easeInOut(duration: tokens.fastDuration))
        #expect(tokens.standard == .easeInOut(duration: tokens.standardDuration))
        #expect(tokens.modal == .easeInOut(duration: tokens.modalDuration))
    }

    @Test func reducesMotionShortCircuitsFastToZeroDurationLinear() {
        var tokens = MKMotionTokens.default
        tokens.reducesMotion = true
        #expect(tokens.fast == .linear(duration: 0))
    }

    @Test func reducesMotionShortCircuitsStandardToZeroDurationLinear() {
        var tokens = MKMotionTokens.default
        tokens.reducesMotion = true
        #expect(tokens.standard == .linear(duration: 0))
    }

    @Test func reducesMotionShortCircuitsModalToZeroDurationLinear() {
        var tokens = MKMotionTokens.default
        tokens.reducesMotion = true
        #expect(tokens.modal == .linear(duration: 0))
    }

    @Test func reducesMotionIsInjectableViaInit() {
        let tokens = MKMotionTokens(reducesMotion: true)
        #expect(tokens.fast == .linear(duration: 0))
        #expect(tokens.standard == .linear(duration: 0))
        #expect(tokens.modal == .linear(duration: 0))
    }

    @Test func togglingReducesMotionBackOffRestoresTheConfiguredCurve() {
        var tokens = MKMotionTokens.default
        tokens.reducesMotion = true
        #expect(tokens.fast == .linear(duration: 0))

        tokens.reducesMotion = false
        #expect(tokens.fast == .easeInOut(duration: tokens.fastDuration))
    }
}
