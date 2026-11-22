import MKAnalytics
import MKDesignSystem
import MKFoundation
import MKStore
import SwiftUI

/// The real paywall (WS-10 T10, replacing `PaywallPlaceholderView`).
/// Renders `MKPaywallStateMachine` + `MKProductCatalog` against the PW-01…
/// PW-10 invariants documented in `MakhtootKit/Sources/MKStore/Docs/PaywallRequirements.md`:
///
/// - PW-01: `closeBar` is always present, at the top, never nested inside
///   any other dismiss-gated control.
/// - PW-02/PW-03/PW-04: every product from `MKProductCatalog.load()` (all
///   three, never a subset) renders with `displayPrice` directly beside
///   its own CTA, and the auto-renew disclosure sits directly under a
///   subscription's price.
/// - PW-05/PW-06: `legalLinks` ، Privacy Policy / Terms links.
/// - PW-07: `restoreButton`, unconditionally visible.
/// - PW-08: this view never appears except via an explicit
///   `nav.presentPaywall(_:)` call from user action (onboarding's own
///   "عرض الباقات" link, a feature tap, or Settings) ، never on cold
///   launch.
/// - PW-09: no countdown/urgency copy anywhere below.
/// - PW-10: `freeTierNote` states the free tier remains usable.
struct PaywallView: View {
    @Environment(\.mkTheme) private var theme
    @Environment(AppContainer.self) private var container
    let context: PaywallContext
    var onClose: () -> Void

    @State private var machine: MKPaywallStateMachine?
    @State private var products: [MKStoreProduct] = []
    @State private var catalogState: MKCatalogState = .loading
    @State private var showsRedundantSheet = false
    @ScaledMetric(relativeTo: .body) private var headerIconSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var featureIconSize: CGFloat = 16

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.lg) {
                closeBar
                header
                switch catalogState {
                case .loading:
                    ProgressView()
                        .padding(theme.spacing.xl)
                case .catalogUnavailable:
                    // T2 AC / DF-7: exact canonical string, no paraphrase.
                    MKBanner(message: "يتطلب الاتصال بالإنترنت", severity: .warning)
                case .loaded(let loadedProducts):
                    featuresSection
                    productList(loadedProducts)
                }
                restoreButton
                if let machine {
                    statusBanner(for: machine.state)
                }
                freeTierNote
                legalLinks
            }
            .padding(theme.spacing.xl)
        }
        .background(theme.bg)
        .task { await load() }
        .sheet(isPresented: $showsRedundantSheet) {
            RedundantSubscriptionSheet {
                showsRedundantSheet = false
                machine?.acknowledgeRedundantSubscriptionSheet()
            }
        }
    }

    // MARK: - Load

    private func load() async {
        let purchaseMachine = MKPaywallStateMachine(context: context.storeContext, purchaseController: container.purchaseController)
        machine = purchaseMachine
        catalogState = await container.productCatalog.load()
        if case .loaded(let loaded) = catalogState {
            products = loaded
        }
    }

    // MARK: - Sections

    private var closeBar: some View {
        HStack {
            Spacer()
            MKToolbarButton(systemImage: "xmark", accessibilityLabel: closeLabel, action: onClose)
        }
    }

    private var header: some View {
        VStack(spacing: theme.spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: headerIconSize))
                .foregroundStyle(theme.primary)
            Text(title)
                .mkTypeStyle(theme.typeRamp.style(for: .title2))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
            // T7: app-side-trial framing, never "free trial" alone (which
            // in App Store context implies an Apple introductory offer we
            // do not configure ، Docs/TrialModel.md).
            Text(trialFraming)
                .mkTypeStyle(theme.typeRamp.style(for: .callout))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
        }
    }

    private func productList(_ products: [MKStoreProduct]) -> some View {
        VStack(spacing: theme.spacing.md) {
            ForEach(products) { product in
                productRow(product)
            }
        }
    }

    private func productRow(_ product: MKStoreProduct) -> some View {
        Button {
            Task {
                await machine?.purchase(productID: product.id)
                if machine?.showsRedundantSubscriptionSheet == true {
                    showsRedundantSheet = true
                }
            }
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text(product.displayName)
                        .mkTypeStyle(theme.typeRamp.style(for: .headline))
                        .foregroundStyle(theme.ink)
                    if case .subscription = product.kind {
                        // PW-03: auto-renew disclosure directly under the
                        // price/CTA it belongs to.
                        Text(autoRenewDisclosure)
                            .mkTypeStyle(theme.typeRamp.style(for: .caption))
                            .foregroundStyle(theme.inkMuted)
                    }
                }
                Spacer(minLength: theme.spacing.md)
                // PW-02: price adjacent to the CTA, same row.
                Text(product.displayPrice)
                    .mkTypeStyle(theme.typeRamp.style(for: .headline))
                    .foregroundStyle(theme.primary)
            }
            .padding(theme.spacing.md)
            .frame(maxWidth: .infinity)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    /// One row of the free-vs-premium table. `free` describes what the
    /// free tier actually gives ، never "✗", because PW-10 requires the
    /// free tier to read as genuinely usable, and because several of these
    /// are limits rather than absences.
    private struct ComparisonRow: Identifiable {
        let id = UUID()
        let icon: String
        /// The capability being compared.
        let feature: String
        /// What free gets. `nil` means genuinely not included.
        let free: String?
        let premium: String
    }

    /// Bug fix (2026-07-29, user report: "make the free vs premium
    /// comparison clearer"). This used to be a one-sided list of premium
    /// features with no statement of what free includes, so the only way
    /// to work out the difference was to hit a lock somewhere in the app.
    /// Now every row states both sides.
    private let comparison: [ComparisonRow] = [
        ComparisonRow(
            icon: "textformat", feature: "الخطوط",
            free: "الخطوط الأساسية المضمّنة", premium: "أكثر من ٢٠ خطًا عربيًا أصيلاً"),
        ComparisonRow(
            icon: "wand.and.stars", feature: "الترتيب الحر",
            free: nil, premium: "تحكّم بكل حرف وحركة على حدة"),
        ComparisonRow(
            icon: "doc.richtext", feature: "النص على المسار",
            free: nil, premium: "كتابة منحنية ودائرية"),
        ComparisonRow(
            icon: "square.and.arrow.up", feature: "التصدير",
            free: "PNG و JPEG", premium: "إضافةً إلى SVG و PDF متجهي"),
        ComparisonRow(
            icon: "icloud", feature: "مزامنة iCloud",
            free: nil, premium: "مشاريعك على كل أجهزتك"),
        ComparisonRow(
            icon: "photo.on.rectangle", feature: "استيراد الخطوط",
            free: nil, premium: "أضف خطوطك الشخصية"),
        ComparisonRow(
            icon: "rectangle.portrait", feature: "أبعاد اللوحة",
            free: "المقاسات الجاهزة", premium: "أي مقاس مخصص تريده"),
        ComparisonRow(
            icon: "folder", feature: "المشاريع",
            free: "غير محدودة", premium: "غير محدودة"),
    ]

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text(featuresTitle)
                .mkTypeStyle(theme.typeRamp.style(for: .headline))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Column header ، without it the two values in each row have no
            // stated meaning.
            HStack(spacing: theme.spacing.sm) {
                Color.clear.frame(width: 24, height: 1)
                Text(featureColumnLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(freeColumnLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(premiumColumnLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(theme.primary)
            }
            .mkTypeStyle(theme.typeRamp.style(for: .caption))
            .foregroundStyle(theme.inkFaint)

            Divider().overlay(theme.border)

            ForEach(comparison) { row in
                HStack(alignment: .top, spacing: theme.spacing.sm) {
                    Image(systemName: row.icon)
                        .font(.system(size: featureIconSize))
                        .foregroundStyle(theme.primary)
                        .frame(width: 24)
                    Text(row.feature)
                        .mkTypeStyle(theme.typeRamp.style(for: .callout))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.free ?? notIncludedMark)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.premium)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                // One combined element per row: VoiceOver reading four
                // separate fragments per row loses the pairing entirely.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(row.feature) ، \(freeColumnLabel): \(row.free ?? notIncludedSpoken) ، \(premiumColumnLabel): \(row.premium)")
            }
        }
        .padding(theme.spacing.md)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style))
    }

    private var restoreButton: some View {
        Button(restoreLabel) {
            Task { await machine?.restore() }
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.primary)
        .disabled(isBusy)
    }

    @ViewBuilder
    private func statusBanner(for state: MKPaywallState) -> some View {
        switch state {
        case .nothingToRestore:
            MKBanner(message: "لا توجد مشتريات سابقة", severity: .info)
        case .failed(let error):
            MKBanner(message: error.errorDescription ?? failedGenericCopy, severity: .destructive)
        case .pendingApproval:
            MKBanner(message: "بانتظار موافقة العائلة", severity: .info)
        case .success:
            MKBanner(message: successCopy, severity: .info)
        case .browsing, .purchasing, .dismissed:
            EmptyView()
        }
    }

    private var isBusy: Bool {
        if case .purchasing = machine?.state { return true }
        return false
    }

    private var freeTierNote: some View {
        // PW-10: the free tier remains genuinely usable ، never imply the
        // app is unusable without purchasing.
        Text(freeTierCopy)
            .mkTypeStyle(theme.typeRamp.style(for: .caption))
            .foregroundStyle(theme.inkMuted)
            .multilineTextAlignment(.center)
    }

    private var legalLinks: some View {
        // PW-05/PW-06. P14 hardening pass (docs/impl-log/WS-07-p14-run3.md,
        // item 4): was hardcoding its own placeholder URLs
        // (`https://example.com/makhtoot/...`) instead of
        // `MKLegalLinks.privacyPolicyURL`/`.termsOfUseURL` ، the single
        // source of truth `MKLegalLinks.swift`'s own doc comment already
        // documents as "consumed by both Settings (T10) and the paywall
        // (WS-13...)" and whose T14 accept criterion is literally "grep
        // shows no duplicated URL literals; all surfaces reference these
        // constants." The drift meant a future FD-01 real-URL sweep
        // (`git grep PLACEHOLDER-FD-01`) would silently miss this screen
        // entirely, since the hardcoded strings carried no
        // `PLACEHOLDER-FD-01` marker at all. `PrivacyConsentView.swift`/
        // `SupportSettingsView.swift` already reference the shared
        // constants correctly ، this makes the paywall consistent with
        // them.
        HStack(spacing: theme.spacing.lg) {
            Link(privacyLabel, destination: URL(string: MKLegalLinks.privacyPolicyURL)!)
            Link(termsLabel, destination: URL(string: MKLegalLinks.termsOfUseURL)!)
        }
        .mkTypeStyle(theme.typeRamp.style(for: .caption))
    }

    // MARK: - Strings

    // Latin gloss: what you get in each plan
    private var featuresTitle: String { "ما الذي تحصل عليه في كل باقة" }
    // Latin gloss: feature
    private var featureColumnLabel: String { "الميزة" }
    // Latin gloss: free
    private var freeColumnLabel: String { "المجاني" }
    // Latin gloss: premium
    private var premiumColumnLabel: String { "المميّز" }
    /// Shown in the free column for capabilities the free tier genuinely
    /// does not include ، an em dash rather than a cross, which reads as a
    /// penalty.
    private var notIncludedMark: String { "—" }
    // Latin gloss: not included ، spoken form of `notIncludedMark`, since
    // VoiceOver reads a bare dash as nothing at all.
    private var notIncludedSpoken: String { "غير متاح" }
    private var title: String {
        // Latin gloss: premium plans
        "الباقات المميزة"
    }

    private var trialFraming: String {
        // T7: app-side trial framing (Docs/TrialModel.md) ، Latin gloss:
        // "7 free days, inside the app, on first launch"
        "٧ أيام مجانًا داخل التطبيق عند أول استخدام"
    }

    private var autoRenewDisclosure: String {
        // Latin gloss: renews automatically. Cancel anytime from Settings.
        "يتجدد تلقائيًا. يمكنك الإلغاء في أي وقت من الإعدادات."
    }

    private var restoreLabel: String {
        // Latin gloss: restore purchases
        "استعادة المشتريات"
    }

    private var privacyLabel: String {
        // Latin gloss: privacy policy
        "سياسة الخصوصية"
    }

    private var termsLabel: String {
        // Latin gloss: terms of use
        "شروط الاستخدام"
    }

    private var freeTierCopy: String {
        // Latin gloss: you can keep designing for free ، premium only adds
        // extra fonts, formats, and backgrounds
        "يمكنك الاستمرار في التصميم مجانًا ، الاشتراك يضيف فقط خطوطًا وصيغ تصدير وخلفيات إضافية"
    }

    private var successCopy: String {
        // Latin gloss: done ، premium features are now unlocked
        "تم ، تم فتح المزايا المميزة الآن"
    }

    private var failedGenericCopy: String {
        // Latin gloss: something went wrong
        "حدث خطأ ما."
    }

    private var closeLabel: String {
        // Latin gloss: close
        "إغلاق"
    }
}

/// T19/D-228: one-time sheet after a lifetime purchase made while a
/// subscription was still active/grace/billingRetry.
private struct RedundantSubscriptionSheet: View {
    @Environment(\.mkTheme) private var theme
    var onDismiss: () -> Void
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 40

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: iconSize))
                .foregroundStyle(theme.primary)
            Text(title)
                .mkTypeStyle(theme.typeRamp.style(for: .title2))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
            Text(body_)
                .mkTypeStyle(theme.typeRamp.style(for: .callout))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
            Link(manageLabel, destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                .buttonStyle(.borderedProminent)
            Button(dismissLabel, action: onDismiss)
                .buttonStyle(.plain)
                .foregroundStyle(theme.inkMuted)
        }
        .padding(theme.spacing.xl)
        .presentationDetents([.medium])
    }

    private var title: String {
        // Latin gloss: you now have Makhtoot Lifetime
        "أصبح لديك الآن مخطوط مدى الحياة"
    }

    private var body_: String {
        // Latin gloss: your subscription is no longer needed ، cancel it
        // from Settings so you are not charged again
        "لم تعد بحاجة إلى اشتراكك ، يمكنك إلغاءه من الإعدادات حتى لا يتم خصم مبلغ إضافي."
    }

    private var manageLabel: String {
        // Latin gloss: manage subscription
        "إدارة الاشتراك"
    }

    private var dismissLabel: String {
        // Latin gloss: later
        "لاحقًا"
    }
}

#Preview {
    PaywallView(context: .onboardingTrialIntro) {}
        .environment(\.mkTheme, HibrTheme.default)
        .environment(AppContainer())
}
