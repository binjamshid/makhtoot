import MKAnalytics
import MKDesignSystem
import MKFoundation
import MKFonts
import MKModel
import MKStore
import SwiftUI

/// الإعدادات ، full Settings root view (WS-12 T7). Replaces the stub that
/// previously showed placeholder rows for Support and Licensing.
///
/// ## Section hierarchy
/// - الاشتراك (Subscription) ، real WS-10 entitlement states (T8)
/// - المزامنة (Sync) ، WS-11 status stub, real sync section (T9)
/// - الخصوصية (Privacy / Analytics consent) ، opt-in toggle + disclosure (T10)
/// - عام (General) ، canvas defaults + autosave pref (T11)
/// - الدعم (Support / About / Licensing) ، T12/T13
///
/// The file retains the name `SettingsPlaceholderView.swift` to avoid
/// a pbxproj rename (WS-12 §"SettingsPlaceholderView strategy").
struct SettingsPlaceholderView: View {
    @Environment(\.mkTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container

    /// `false` when embedded as a `NavigationSplitView` detail (iPad
    /// regular width ، nothing to dismiss); `true` when presented as a
    /// sheet (iPhone / compact width).
    var showsCloseButton: Bool
    /// 2026-07-29: threaded through to `GeneralSettingsView` rather than
    /// having it declare its own `@Environment(AppNavigationModel.self)`
    /// — see that view's own doc comment on `onResetOnboarding` for why.
    var onResetOnboarding: () -> Void

    @State private var entitlementState: MKEntitlementState = .free
    @State private var restoreOutcome: MKRestoreOutcome?
    @State private var isRestoring = false

    #if DEBUG
    @State private var seedStatus: String?
    @State private var isSeeding = false
    #endif

    var body: some View {
        List {
            subscriptionSection
            syncSection
            NavigationLink {
                PrivacyConsentView()
            } label: {
                Label(privacyTitle, systemImage: "hand.raised")
            }
            NavigationLink {
                GeneralSettingsView(onResetOnboarding: onResetOnboarding)
            } label: {
                Label(generalTitle, systemImage: "gearshape")
            }
            NavigationLink {
                FontManagementView()
            } label: {
                Label(fontsTitle, systemImage: "textformat")
            }
            NavigationLink {
                SupportSettingsView()
            } label: {
                Label(supportTitle, systemImage: "questionmark.circle")
            }
            #if MAKHTOOT_REFERRAL_ENABLED
            // D-327: FD-05 granted for iOS 2026-08-07. Present in Release ،
            // the amended clause of D-225. Two independent levers guard this
            // row: removing the compile flag deletes it from the binary;
            // setting `referralProgram = false` hides it at runtime without a
            // resubmission.
            if MKFeatureFlags.default.referralProgram {
                NavigationLink {
                    ReferralSection()
                } label: {
                    Label(referralTitle, systemImage: "person.2")
                }
            }
            #endif
            #if DEBUG
            Section(header: Text("Debug")) {
                NavigationLink {
                    DesignSystemGallery()
                } label: {
                    Label(designGalleryLabel, systemImage: "paintpalette")
                }
                NavigationLink {
                    RootView()
                } label: {
                    Label(ws01RootLabel, systemImage: "square.on.square")
                }
                NavigationLink {
                    ShapingHarnessView()
                } label: {
                    Label(shapingHarnessLabel, systemImage: "textformat.abc")
                }
                NavigationLink {
                    PathTextHarnessView()
                } label: {
                    Label(pathTextHarnessLabel, systemImage: "circle.dashed")
                }
                Button {
                    seedFixtureProjects()
                } label: {
                    if isSeeding {
                        ProgressView()
                    } else {
                        Label(seedLabel, systemImage: "square.stack.3d.up")
                    }
                }
                .disabled(isSeeding)
                if let seedStatus {
                    Text(seedStatus)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                }
            }
            #endif
        }
        .mkDefaultFont(theme)
        .tint(theme.primary)
        .scrollContentBackground(.hidden)
        .background(theme.bgAlt)
        .navigationTitle(Text(navTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeLabel) { dismiss() }
                }
            }
        }
        .task {
            entitlementState = container.entitlementProvider.state
            for await state in await container.entitlementResolver.states() {
                entitlementState = state
            }
        }
    }

    // MARK: - Subscription section (WS-10 T8)

    @ViewBuilder
    private var subscriptionSection: some View {
        Section(header: Text(subscriptionTitle)) {
            HStack {
                Label(subscriptionTitle, systemImage: "sparkles")
                    .foregroundStyle(theme.ink)
                Spacer()
                Text(entitlementStatusLabel)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
            }
            if entitlementState.grantsPremiumAccess == false || isTrial {
                NavigationLink {
                    PaywallView(context: .settingsUpgrade) { dismiss() }
                } label: {
                    Label(upgradeLabel, systemImage: "arrow.up.circle")
                }
            }
            if case .subscribed = entitlementState {
                Link(manageSubscriptionLabel, destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            }
            if case .inGracePeriod = entitlementState {
                MKBanner(message: gracePeriodBannerCopy, severity: .warning)
                Link(manageSubscriptionLabel, destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            }
            if case .inBillingRetry = entitlementState {
                MKBanner(message: billingRetryBannerCopy, severity: .destructive)
                Link(manageSubscriptionLabel, destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            }
            Button {
                restorePurchases()
            } label: {
                if isRestoring {
                    ProgressView()
                } else {
                    Label(restoreLabel, systemImage: "arrow.clockwise")
                }
            }
            .disabled(isRestoring)
            if let restoreOutcome {
                Text(restoreOutcomeCopy(restoreOutcome))
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
            }
        }
    }

    // MARK: - Sync section stub (T9 ، WS-11 stub, real SyncSettingsView)

    @ViewBuilder
    private var syncSection: some View {
        NavigationLink {
            SyncSettingsView()
        } label: {
            Label(syncTitle, systemImage: "icloud.and.arrow.up")
        }
    }

    // MARK: - Helpers

    private var isTrial: Bool {
        if case .trial = entitlementState { return true }
        return false
    }

    private func restorePurchases() {
        isRestoring = true
        restoreOutcome = nil
        Task {
            let outcome = await container.purchaseController.restore()
            restoreOutcome = outcome
            entitlementState = container.entitlementProvider.state
            isRestoring = false
        }
    }

    #if DEBUG
    private func seedFixtureProjects() {
        isSeeding = true
        seedStatus = nil
        Task {
            let clock = ContinuousClock()
            let start = clock.now
            for index in 1...500 {
                let ordinal = MKRTLUtilities.toArabicIndicDigits(String(index))
                _ = await container.projectLibrary.create(
                    name: "مشروع تجريبي \(ordinal)",
                    canvas: MKCanvasSpec(size: CGSize(width: 1080, height: 1080), presetID: "social.square")
                )
            }
            let elapsed = clock.now - start
            MKLog.app.info("T17 fixture seed: 500 projects in \(elapsed.description, privacy: .public)")
            seedStatus = "أُنشئ ٥٠٠ مشروع خلال \(elapsed)"
            isSeeding = false
        }
    }
    #endif

    // MARK: - Strings (ar only ، D-100)

    private var navTitle: String { "الإعدادات" }         // settings
    private var subscriptionTitle: String { "الاشتراك" } // subscription
    private var syncTitle: String { "المزامنة" }          // sync
    private var privacyTitle: String { "الخصوصية" }      // privacy
    private var generalTitle: String { "عام" }            // general
    private var fontsTitle: String { "الخطوط" }           // fonts
    private var supportTitle: String { "الدعم" }          // support
    #if MAKHTOOT_REFERRAL_ENABLED
    // D-327: in-file literal, never in Localizable.xcstrings ، D-225's
    // string-catalog isolation rule survives the Release-exclusion amendment.
    private var referralTitle: String { "الدعوات" }       // referrals
    #endif
    private var closeLabel: String { "إغلاق" }            // close

    private var entitlementStatusLabel: String {
        switch entitlementState {
        case .lifetime:      return "مدى الحياة"
        case .subscribed:    return "مفعّل"
        case .inGracePeriod: return "مشكلة في الدفع"
        case .inBillingRetry: return "إعادة محاولة الدفع"
        case .trial(let daysLeft):
            let ordinal = MKRTLUtilities.toArabicIndicDigits(String(daysLeft))
            return "تجريبي ، \(ordinal) أيام متبقية"
        case .free:          return "مجاني"
        }
    }

    private var upgradeLabel: String { "الترقية إلى مخطوط مميز" }
    private var manageSubscriptionLabel: String { "إدارة الاشتراك" }
    private var restoreLabel: String { "استعادة المشتريات" }
    private var gracePeriodBannerCopy: String {
        "توجد مشكلة في الدفع ، جدّد وسيلة الدفع للاستمرار"
    }
    private var billingRetryBannerCopy: String {
        "توجد مشكلة في الدفع ، جدّد وسيلة الدفع للاستمرار"
    }
    private func restoreOutcomeCopy(_ outcome: MKRestoreOutcome) -> String {
        switch outcome {
        case .restoredPremium:    return "تمت استعادة المشتريات."
        case .nothingToRestore:   return "لا توجد مشتريات سابقة."
        case .failed:             return "تعذّرت استعادة المشتريات. حاول مرة أخرى."
        }
    }

    #if DEBUG
    private var designGalleryLabel: String { "معرض عناصر التصميم" }
    private var ws01RootLabel: String { "شاشة WS-01 الأصلية" }
    private var shapingHarnessLabel: String { "مختبر التشكيل النصي" }
    private var pathTextHarnessLabel: String { "مختبر النص على مسار" }
    private var seedLabel: String { "توليد ٥٠٠ مشروع تجريبي" }
    #endif
}

#Preview {
    NavigationStack {
        SettingsPlaceholderView(showsCloseButton: true, onResetOnboarding: {})
    }
    .environment(\.mkTheme, HibrTheme.default)
}
