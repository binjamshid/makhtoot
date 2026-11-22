import SwiftUI
import Testing
@testable import MKDesignSystem

/// UX-2 (AUDIT_2026-07-28.md): "`MKTypeRamp` resolves every role to the
/// active theme's bundled font at a fixed point size... Across the entire
/// codebase there is exactly one use of `relativeTo:` against 27 fixed
/// `.system(size:)`/`Font.custom(size:)` call sites. Setting Larger Text in
/// iOS Settings changes nothing in Makhtoot." `MKTypeRamp.style(for:)` now
/// wires every role's `Font.custom(_:size:relativeTo:)` to a matching
/// `Font.TextStyle` (`MKTypeRamp.swift`, this fix).
@Suite("MKTypeRamp Dynamic Type (UX-2)")
struct MKTypeRampDynamicTypeTests {
    private let ramp = MKTypeRamp.default

    /// Structural regression guard: every role must construct its `Font`
    /// with the `relativeTo:` matching its semantic role (display/largeTitle
    /// → `.largeTitle`, title/title2 → `.title`/`.title2`, headline →
    /// `.headline`, body → `.body`, callout → `.callout`, footnote →
    /// `.footnote`, caption → `.caption`, mono → `.caption2`, per this
    /// fix's own mapping) ، `Font` is `Equatable`, so this pins the exact
    /// construction rather than only the point size, catching a future
    /// accidental drop of `relativeTo:` even if the literal size is left
    /// unchanged.
    @Test(arguments: MKTypeRole.allCases)
    func styleWiresRelativeToForItsRole(_ role: MKTypeRole) {
        let style = ramp.style(for: role)
        let fonts = HibrTheme.fontSet
        let expectedFont: Font
        switch role {
        case .display:
            expectedFont = .custom(fonts.display, size: 74, relativeTo: .largeTitle)
        case .largeTitle:
            expectedFont = .custom(fonts.display, size: 34, relativeTo: .largeTitle)
        case .title:
            expectedFont = .custom(fonts.ui, size: 28, relativeTo: .title)
        case .title2:
            expectedFont = .custom(fonts.ui, size: 22, relativeTo: .title2)
        case .headline:
            expectedFont = .custom(fonts.ui, size: 17, relativeTo: .headline)
        case .body:
            expectedFont = .custom(fonts.ui, size: 17, relativeTo: .body)
        case .callout:
            expectedFont = .custom(fonts.ui, size: 16, relativeTo: .callout)
        case .footnote:
            expectedFont = .custom(fonts.ui, size: 13, relativeTo: .footnote)
        case .caption:
            expectedFont = .custom(fonts.ui, size: 11, relativeTo: .caption)
        case .mono:
            expectedFont = .custom(fonts.mono, size: 10, relativeTo: .caption2)
        }
        #expect(style.font == expectedFont)
    }

    /// An empirical (render-and-measure) companion to
    /// `styleWiresRelativeToForItsRole` was attempted here originally:
    /// render the SAME `.mkTypeStyle(...)`-styled `Text` at two
    /// `DynamicTypeSize`s via `ImageRenderer` and compare rasterized pixel
    /// width. It does not work on this test host — empirically confirmed
    /// (not assumed) that `ImageRenderer` does not apply `dynamicTypeSize`
    /// scaling at all when run via plain `swift test` on macOS, for ANY
    /// font: a control experiment against `.font(.system(.body))` (no
    /// custom font, no `MKTypeRamp` involved at all) produced byte-identical
    /// image widths at `.large` and `.accessibility3` too, both via
    /// `.environment(\.dynamicTypeSize, _:)` and the `.dynamicTypeSize(_:)`
    /// modifier. This is a platform/host limitation of headless
    /// `ImageRenderer` snapshotting outside a live window on macOS, not a
    /// defect in `MKTypeRamp.swift` — Dynamic Type is a real, correctly-wired
    /// iOS behavior (see `styleWiresRelativeToForItsRole` above, which pins
    /// the exact `Font.custom(_:size:relativeTo:)` construction per role)
    /// that this specific test host cannot observe. Proving the *rendered*
    /// (not just constructed) behavior requires an iOS Simulator/device —
    /// see `EXECUTION_PLAN_2026-07-28.md`'s UX-2 Verify step, "Settings →
    /// Accessibility → Larger Text ... confirm layout holds", which is the
    /// manual check that actually closes this loop.
}
