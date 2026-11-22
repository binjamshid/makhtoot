import MKDesignSystem
import SwiftUI

/// The placeholder root scene (WS-01 packet §5 task 17): proves theme +
/// RTL + Arabic end-to-end before WS-13 replaces this with the real
/// project-browser shell (P1/P2). Shows the app name, a swatch of every
/// semantic color token, and a sample of every type-ramp step rendered
/// with the WS-01 packet §6 Arabic fixture strings (tashkeel stacks,
/// lam-alif ligature, mixed Arabic-Indic/Latin numerals).
struct RootView: View {
    @Environment(\.mkTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.xl) {
                    header
                    themeSwatchRow
                    typeRampSample
                    #if DEBUG
                    galleryLink
                    #endif
                }
                .padding(theme.spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.bg)
            .navigationTitle(Text("مخطوط", comment: "App name (Latin gloss: Makhtoot)"))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            MKBrandMark(style: .wordmarkOnly)
            Text("حِبر ، حِبر وقرطاس", comment: "Baseline theme name (Latin gloss: Hibr ، Ink & Parchment)")
                .mkTypeStyle(theme.typeRamp.style(for: .body))
                .foregroundStyle(theme.inkMuted)
        }
    }

    private var themeSwatchRow: some View {
        MKPanel(title: swatchSectionTitle) {
            HStack(spacing: theme.spacing.sm) {
                swatch(theme.bg, label: "الخلفية")
                swatch(theme.surface, label: "مرتفعة")
                swatch(theme.ink, label: "الحبر")
                swatch(theme.primary, label: "التمييز")
                swatch(theme.warning, label: "تحذير")
                swatch(theme.destructive, label: "خطر")
            }
        }
    }

    private var swatchSectionTitle: String {
        // Latin gloss: semantic colors
        "الألوان الدلالية"
    }

    private func swatch(_ color: Color, label: String) -> some View {
        VStack(spacing: theme.spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(theme.border, lineWidth: 1))
            Text(label)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted)
        }
    }

    private var typeRampSample: some View {
        // WS-01 packet §6 Arabic-correctness fixtures: tashkeel stacks
        // ("خَطٌّ عَرَبِيٌّ" ، Latin gloss: "an Arabic line/script"), the
        // lam-alif ligature ("لا إله إلا الله" ، Latin gloss: the shahada),
        // and mixed Arabic-Indic/Latin numerals in one RTL label
        // ("الإصدار 1.0 ، ٢٠٢٦" ، Latin gloss: "version 1.0 ، 2026").
        MKPanel(title: rampSectionTitle) {
            ForEach(MKTypeRole.allCases, id: \.self) { role in
                Text(verbatim: "خَطٌّ عَرَبِيٌّ ، لا إله إلا الله")
                    .mkTypeStyle(theme.typeRamp.style(for: role))
                    .foregroundStyle(theme.ink)
            }
            Text(verbatim: "الإصدار 1.0 ، ٢٠٢٦")
                .mkTypeStyle(theme.typeRamp.style(for: .footnote))
                .foregroundStyle(theme.inkMuted)
        }
    }

    private var rampSectionTitle: String {
        // Latin gloss: type ramp
        "سلّم الطباعة"
    }

    #if DEBUG
    private var galleryLink: some View {
        NavigationLink {
            DesignSystemGallery()
        } label: {
            Text("معرض عناصر التصميم", comment: "Debug-only link to the component gallery (Latin gloss: design elements gallery)")
                .mkTypeStyle(theme.typeRamp.style(for: .headline))
                .foregroundStyle(theme.primary)
        }
    }
    #endif
}

#Preview {
    RootView()
        .environment(\.mkTheme, HibrTheme.default)
}
