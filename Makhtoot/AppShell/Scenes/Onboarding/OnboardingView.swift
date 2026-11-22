import MKDesignSystem
import MKFoundation
import MKStore
import SwiftUI

/// First-launch onboarding (WS-13 packet §5 T9 structure; WS-10 T6/T7 adds
/// the real trial-start screen this session). Four screens ، the Arrange
/// Mode differentiator, a typing/tashkeel teaser, the real D-123 trial-
/// start moment, and a closing screen ، end in "ابدأ التصميم" (always
/// skips straight to the browser, no purchase) and an optional "عرض
/// الباقات" that opens the real paywall.
///
/// **The trial-start screen is now real, not fabricated.** WS-13 explicitly
/// deferred this ("Showing that copy today would mean fabricating a trial
/// date with no `MKStore`/Keychain record behind it ، a paywall-compliance
/// honesty violation"): `MKTrialManager.peek()` reads the actual merged
/// Keychain+iCloud-KVS record (the trial itself already started at process
/// launch ، D-123/Q37, `AppContainer.init` kicks off the first
/// `MKEntitlementResolver.resolve()`, which resolves the trial as a side
/// effect ، this screen never STARTS the trial, only reads its already-
/// true state). `peek()` (not `resolve()`) is deliberate: this is a
/// read-only display, so it doesn't perturb the D-224 high-water mark.
struct OnboardingView: View {
    @Environment(\.mkTheme) private var theme
    @Environment(AppContainer.self) private var container
    @State private var pageIndex = 0
    @State private var trialDaysLeft: Int?
    @ScaledMetric(relativeTo: .body) private var pageIconSize: CGFloat = 52

    var onFinished: () -> Void
    var onShowPaywall: () -> Void

    private struct Page {
        let symbol: String
        let title: String
        let subtitle: String
    }

    private var pages: [Page] {
        var result = [
            Page(symbol: "wand.and.stars", title: page1Title, subtitle: page1Subtitle),
            Page(symbol: "textformat", title: page2Title, subtitle: page2Subtitle),
        ]
        if let trialDaysLeft {
            result.append(Page(symbol: "clock.badge.checkmark", title: trialTitle, subtitle: trialSubtitle(daysLeft: trialDaysLeft)))
        }
        result.append(Page(symbol: "sparkles", title: page3Title, subtitle: page3Subtitle))
        return result
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
        .task {
            let state = await container.trialManager.peek()
            if case .active(let daysLeft) = state {
                trialDaysLeft = daysLeft
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
        VStack(spacing: theme.spacing.md) {
            if pageIndex < pages.count - 1 {
                Button(nextLabel) {
                    withAnimation(.easeInOut(duration: 0.3)) { pageIndex += 1 }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
                .frame(maxWidth: .infinity)
            } else {
                Button(startDesigningLabel, action: onFinished)
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary)
                    .frame(maxWidth: .infinity)

                Button(showPlansLabel, action: onShowPaywall)
                    .mkTypeStyle(theme.typeRamp.style(for: .footnote))
                    .foregroundStyle(theme.inkMuted)
            }
        }
    }

    // MARK: - Strings

    private var page1Title: String { "رتّب كل حرف كما تشاء" }
    private var page1Subtitle: String { "ميزة مخطوط الفريدة: حوّل نصك العربي إلى تشكيل حر تحرّكه حرفًا حرفًا" }
    private var page2Title: String { "كتابة عربية طبيعية" }
    private var page2Subtitle: String { "التشكيل والحروف المتصلة تمامًا كما تتوقعها" }
    private var trialTitle: String { "بدأت تجربتك المجانية لأسبوع" }

    private func trialSubtitle(daysLeft: Int) -> String {
        let ordinal = MKRTLUtilities.toArabicIndicDigits(String(daysLeft))
        return "كل المزايا المميزة مجانًا لمدة \(ordinal) أيام أخرى ، بدون أي عملية شراء"
    }

    private var page3Title: String { "ابدأ رحلتك مع مخطوط" }
    private var page3Subtitle: String { "استكشف الأدوات وابدأ أول تصميم لك" }
    private var skipLabel: String { "تخطى" }
    private var nextLabel: String { "التالي" }
    private var startDesigningLabel: String { "ابدأ التصميم" }
    private var showPlansLabel: String { "عرض الباقات" }
}

#Preview {
    OnboardingView(onFinished: {}, onShowPaywall: {})
        .environment(\.mkTheme, HibrTheme.default)
        .environment(AppContainer())
}
