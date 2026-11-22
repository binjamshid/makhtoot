import MKDesignSystem
import SwiftUI

/// Introduces the editing tools on first launch or when replayed from Settings.
struct OnboardingView: View {
    @Environment(\.mkTheme) private var theme
    @State private var pageIndex = 0
    @ScaledMetric(relativeTo: .body) private var pageIconSize: CGFloat = 52

    var onFinished: () -> Void

    private struct Page {
        let symbol: String
        let title: String
        let subtitle: String
    }

    private var pages: [Page] {
        [
            Page(symbol: "wand.and.stars", title: page1Title, subtitle: page1Subtitle),
            Page(symbol: "textformat", title: page2Title, subtitle: page2Subtitle),
            Page(symbol: "sparkles", title: page3Title, subtitle: page3Subtitle),
        ]
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(skipLabel, action: onFinished)
                        .mkTypeStyle(theme.typeRamp.style(for: .footnote))
                        .foregroundStyle(theme.inkMuted)
                        .padding(theme.spacing.lg)
                }

                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageView(page).tag(index)
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .animation(.easeInOut(duration: 0.3), value: pageIndex)

                pageIndicator
                    .padding(.vertical, theme.spacing.lg)

                actions
                    .padding(.horizontal, theme.spacing.xl)
                    .padding(.bottom, theme.spacing.xl)
            }
        }
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: theme.spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(theme.primary.opacity(0.1))
                    .frame(width: 128, height: 128)
                Circle()
                    .fill(theme.primary.opacity(0.06))
                    .frame(width: 164, height: 164)
                Image(systemName: page.symbol)
                    .font(.system(size: pageIconSize, weight: .light))
                    .foregroundStyle(theme.primary)
            }

            VStack(spacing: theme.spacing.md) {
                Text(page.title)
                    .mkTypeStyle(theme.typeRamp.style(for: .title))
                    .foregroundStyle(theme.ink)
                    .multilineTextAlignment(.center)
                Text(page.subtitle)
                    .mkTypeStyle(theme.typeRamp.style(for: .body))
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, theme.spacing.xxl)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(index == pageIndex ? theme.primary : theme.inkMuted.opacity(0.25))
                    .frame(width: index == pageIndex ? 20 : 6, height: 6)
                    .animation(.spring(duration: 0.3), value: pageIndex)
            }
        }
    }

    private var actions: some View {
        Button(pageIndex < pages.count - 1 ? nextLabel : startDesigningLabel) {
            if pageIndex < pages.count - 1 {
                withAnimation(.easeInOut(duration: 0.3)) { pageIndex += 1 }
            } else {
                onFinished()
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(theme.primary)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Strings

    private var page1Title: String { "رتّب كل حرف كما تشاء" }
    private var page1Subtitle: String { "ميزة مخطوط الفريدة: حوّل نصك العربي إلى تشكيل حر تحرّكه حرفًا حرفًا" }
    private var page2Title: String { "كتابة عربية طبيعية" }
    private var page2Subtitle: String { "التشكيل والحروف المتصلة تمامًا كما تتوقعها" }
    private var page3Title: String { "ابدأ رحلتك مع مخطوط" }
    private var page3Subtitle: String { "استكشف الأدوات وابدأ أول تصميم لك" }
    private var skipLabel: String { "تخطى" }
    private var nextLabel: String { "التالي" }
    private var startDesigningLabel: String { "ابدأ التصميم" }
}

#Preview {
    OnboardingView(onFinished: {})
        .environment(\.mkTheme, HibrTheme.default)
}
