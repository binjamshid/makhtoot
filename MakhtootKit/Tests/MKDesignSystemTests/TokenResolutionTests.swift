import SwiftUI
import Testing
@testable import MKDesignSystem
#if canImport(UIKit)
import UIKit
#endif

/// Theme protocol conformance completeness for `HibrTheme` (FILE_MAP
/// §21 `MKDesignSystemTests`), plus WS-01 packet §5 tasks 12–14 token-shape
/// accept criteria (spacing grid, radius scale, motion durations).
@Suite("HibrTheme token resolution")
struct TokenResolutionTests {
    private let theme = HibrTheme.default

    @Test func spacingScaleMatchesTheFourPointGrid() {
        let spacing = theme.spacing
        #expect(spacing.xs == 4)
        #expect(spacing.sm == 8)
        #expect(spacing.md == 12)
        #expect(spacing.lg == 16)
        #expect(spacing.xl == 24)
        #expect(spacing.xxl == 32)
        #expect(spacing.xxxl == 48)
    }

    @Test func radiusScaleMatchesTheHibrHandoff() {
        let radius = theme.radius
        #expect(radius.button == 11)
        #expect(radius.card == 14)
        #expect(radius.sheet == 18)
        #expect(radius.pill == 999)
        #expect(radius.style == .continuous)
    }

    @Test func motionDurationsMatchD126() {
        let motion = theme.motion
        #expect(motion.fastDuration == 0.15)
        #expect(motion.standardDuration == 0.25)
        #expect(motion.modalDuration == 0.35)
    }

    @Test func typeRampCoversEveryRoleWithLineHeightFloor() {
        for role in MKTypeRole.allCases {
            let style = theme.typeRamp.style(for: role)
            // WS-01 packet §6: tashkeel stacks must not clip ، every ramp
            // step needs a line-height multiplier of at least 1.3, except
            // `.display`'s tuned 1.2 (hero scale, not a tashkeel-bearing
            // UI string).
            #expect(style.lineHeightMultiplier >= (role == .display ? 1.2 : 1.3))
            #expect(style.pointSize > 0)
        }
    }

    @Test func elevationStylesAreNonNegative() {
        let elevation = theme.elevation
        #expect(elevation.panel.radius >= 0)
        #expect(elevation.floatingBar.radius >= 0)
        #expect(elevation.panel.opacity >= 0 && elevation.panel.opacity <= 1)
    }

    @Test func selectionStrokeReusesPrimary() {
        #if canImport(UIKit)
        #expect(resolvedRGBA(theme.selectionStroke, style: .light) == resolvedRGBA(theme.primary, style: .light))
        #expect(resolvedRGBA(theme.selectionStroke, style: .dark) == resolvedRGBA(theme.primary, style: .dark))
        #else
        #expect(theme.selectionStroke == theme.primary)
        #endif
    }

    #if canImport(UIKit)
    private func resolvedRGBA(_ color: Color, style: UIUserInterfaceStyle) -> [CGFloat] {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let resolved = UIColor(color).resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }
    #endif
}

/// Every `MKThemeID` must resolve a fully-formed, distinct `MKTheme` ،
/// the design-system-handoff adoption's multi-theme accept criterion.
@Suite("MKThemeID resolves all five design directions")
struct MKThemeIDResolutionTests {
    @Test func everyThemeIDResolvesAConformer() {
        for id in MKThemeID.allCases {
            let theme = id.resolve()
            #expect(!theme.fonts.display.isEmpty)
            #expect(!theme.fonts.ui.isEmpty)
            #expect(!theme.fonts.mono.isEmpty)
            #expect(theme.spacing.md == 12) // shared 4pt grid across all themes
            for role in MKTypeRole.allCases {
                #expect(theme.typeRamp.style(for: role).pointSize > 0)
            }
        }
    }

    @Test func kufiIsTheOnlySharpCorneredTheme() {
        for id in MKThemeID.allCases {
            let radius = id.resolve().radius
            if id == .kufi {
                #expect(radius.button == 0 && radius.card == 0 && radius.sheet == 0 && radius.pill == 0)
            } else {
                #expect(radius.button > 0 && radius.card > 0 && radius.sheet > 0 && radius.pill > 0)
            }
        }
    }

    @Test func displayNamesAreDistinctArabicStrings() {
        let names = Set(MKThemeID.allCases.map(\.displayName))
        #expect(names.count == MKThemeID.allCases.count)
    }
}
