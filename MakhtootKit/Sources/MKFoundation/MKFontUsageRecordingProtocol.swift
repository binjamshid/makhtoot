import Foundation

/// Protocol seam allowing `MKAnalytics` to receive font-usage events from
/// the app shell/editor without creating an upward MKFoundation←MKAnalytics
/// import cycle. WS-12 T16.
///
/// ## Parameter type note
/// The `fontID` parameter is declared as `String` here rather than
/// `MKFonts.MKFontID` to avoid an MKFoundation←MKFonts import cycle.
/// `MKFontID` is a plain `public typealias MKFontID = String` in MKFonts,
/// so `String` and `MKFontID` are the same type ، conformers declared in
/// modules that import `MKFonts` may use either spelling interchangeably,
/// and Swift resolves conformance by type identity.
///
/// ## Call site contract (for WS-13 / any editor code):
/// - Call `recordFontUsed(_:)` when a font is **applied** to a text object
///   (e.g. user picks a font from the picker and taps Apply, or a preset is
///   applied on canvas creation). Do NOT call on preview or browse ، only on
///   confirmed apply actions (D-125 minimization rule).
/// - The implementation debounces identical consecutive fontID values within
///   5 seconds, so rapid re-apply of the same font does not inflate counters.
/// - All calls are fire-and-forget async; no return value to inspect.
/// - If the user has not granted analytics consent, the call is a no-op with
///   zero observable side-effects and zero CloudKit activity.
public protocol MKFontUsageRecording: Sendable {
    /// Record that the given font was applied to a text object.
    /// `fontID` matches `MKFonts.MKFontID` (a plain `String`).
    /// No-ops if the user has not granted analytics consent.
    /// Debounces identical consecutive calls within 5 s.
    func recordFontUsed(_ fontID: String) async
}

/// No-op stub for use before analytics consent is granted, in previews, or
/// in tests that do not require analytics behavior. `MKAnalytics` ships the
/// real conformer (`MKAnalyticsService`).
public struct MKNoOpFontUsageRecorder: MKFontUsageRecording {
    public init() {}
    public func recordFontUsed(_ fontID: String) async {}
}
