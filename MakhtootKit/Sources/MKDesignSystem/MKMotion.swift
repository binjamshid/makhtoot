import SwiftUI

/// The easing curve family used by MakhtootKit motion. A single case today
/// (D-126 specifies ease-in-out for all three durations); kept as an enum
/// rather than hardcoding `.easeInOut` at every call site so a future theme
/// can introduce a different curve without touching component code.
public enum MKMotionCurve: Sendable {
    case easeInOut
}

/// Motion durations (D-126): fast for micro-interactions (button press,
/// chip selection), standard for panel/section transitions, modal for
/// sheet/paywall presentation. All three share one easing curve.
public struct MKMotionTokens: Sendable {
    public var fastDuration: TimeInterval = 0.15
    public var standardDuration: TimeInterval = 0.25
    public var modalDuration: TimeInterval = 0.35
    public var curve: MKMotionCurve = .easeInOut

    /// UX-3 (AUDIT_2026-07-28.md): Reduce Motion support. `MKTheme`'s own
    /// header doc comment is explicit that theme values (this struct
    /// included, via `MKTheme.motion`) "may be read from both `@MainActor`
    /// UI code and background-scheduled work" — so this struct cannot read
    /// `@Environment(\.accessibilityReduceMotion)` directly (that property
    /// wrapper only resolves inside a live SwiftUI `View`/`ViewModifier`
    /// render pass, which this plain `Sendable` value type is not, and
    /// reading the MainActor-isolated `UIAccessibility.isReduceMotionEnabled`
    /// unconditionally would break that documented "usable from background
    /// contexts" contract). The flag is threaded in as plain data instead:
    /// whoever constructs/consumes a token value at an actual SwiftUI
    /// render seam (where the environment value IS readable) copies it in
    /// before asking for `.fast`/`.standard`/`.modal`. Defaults to `false`
    /// so every existing call site's behavior is BYTE-FOR-BYTE unchanged
    /// until it opts in.
    public var reducesMotion = false

    public init(
        fastDuration: TimeInterval = 0.15,
        standardDuration: TimeInterval = 0.25,
        modalDuration: TimeInterval = 0.35,
        curve: MKMotionCurve = .easeInOut,
        reducesMotion: Bool = false
    ) {
        self.fastDuration = fastDuration
        self.standardDuration = standardDuration
        self.modalDuration = modalDuration
        self.curve = curve
        self.reducesMotion = reducesMotion
    }

    /// The FOUNDATION §9 / D-126 default motion tokens.
    public static let `default` = MKMotionTokens()

    /// SwiftUI `Animation` for fast interactions (0.15s).
    public var fast: Animation { animation(duration: fastDuration) }
    /// SwiftUI `Animation` for standard transitions (0.25s).
    public var standard: Animation { animation(duration: standardDuration) }
    /// SwiftUI `Animation` for modal/sheet presentation (0.35s).
    public var modal: Animation { animation(duration: modalDuration) }

    /// UX-3: short-circuits to a zero-duration linear animation when
    /// `reducesMotion` is set, regardless of `curve`/`duration` — a
    /// `0`-length `Animation` still runs the value change (unlike removing
    /// the `.animation()` modifier entirely), it just does so without any
    /// perceptible motion, matching Apple's own Reduce Motion guidance.
    private func animation(duration: TimeInterval) -> Animation {
        guard !reducesMotion else { return .linear(duration: 0) }
        switch curve {
        case .easeInOut:
            return .easeInOut(duration: duration)
        }
    }
}
