import MKDesignSystem
import MKFoundation
import SwiftUI
import UIKit

/// عام ، General preferences (WS-12 T11).
///
/// v1-minimal: default canvas preset choice, autosave status visibility
/// toggle, language row (fixed "العربية" ، Arabic-only per D-100), plus
/// P7.5's app-icon switcher.
/// All preferences are persisted via `UserDefaults` with MK-prefixed keys
/// (full SwiftData prefs integration is a WS-12 deviation, logged in
/// docs/impl-log/WS-12.md §5).
struct GeneralSettingsView: View {
    @Environment(\.mkTheme) private var theme
    @Environment(AppContainer.self) private var container
    /// 2026-07-29 crash-report defensive fix: this view previously declared
    /// its own `@Environment(AppNavigationModel.self)` solely to call
    /// `resetOnboarding()` from the button below. Every other reader of
    /// that environment value (`ProjectBrowserView`, `EditorScene`,
    /// `ToolRailView`) sits directly under `RootShellView`'s
    /// `.environment(nav)`; this view is the only one reached two levels
    /// deep through a `NavigationLink` inside `SettingsPlaceholderView`, an
    /// intermediate view that itself never needed `nav`. Rather than trust
    /// that specific propagation path (unverifiable right now — no
    /// reliable live-simulator reproduction was possible while
    /// investigating the report), this threads the one action actually
    /// needed as a plain closure from `RootShellView`, which unconditionally
    /// has `nav` — removing the dependency entirely instead of re-affirming
    /// it, matching `ProjectBrowserView`'s own `onOpenSettings` closure
    /// convention in this same file tree.
    var onResetOnboarding: () -> Void
    @AppStorage("mk.general.showAutosaveIndicator") private var showAutosaveIndicator: Bool = true
    @AppStorage("mk.general.defaultCanvasPreset") private var defaultCanvasPreset: String = "social.square"
    @AppStorage("mk.appearance.themeID") private var themeIDRaw: String = MKThemeID.hibr.rawValue
    @AppStorage("mk.brand.markStyle") private var brandMarkStyleRaw: String = MKBrandMarkStyle.wordmarkOnly.rawValue
    @AppStorage("mk.appearance.colorScheme") private var colorSchemeRaw: String = "system"

    /// P7.5 (Bug 17): mirrors `UIApplication.shared.alternateIconName`
    /// (`nil` = the primary asset-catalog icon, hibr's own). Read on
    /// appear rather than at `init` time so this reflects whatever the
    /// system last confirmed (e.g. after a prior alert-declined switch),
    /// not a value captured once at view construction.
    @State private var currentIconName: String?
    @State private var isSwitchingIcon = false
    @State private var iconSwitchErrorText: String?
    @State private var showsIconPaywall = false
    @State private var entitlementState: MKEntitlementState = .free

    private let canvasPresets: [(id: String, label: String)] = [
        ("social.square",    "مربع ، ١٠٨٠×١٠٨٠"),   // square
        ("social.portrait",  "عمودي ، ١٠٨٠×١٣٥٠"),  // portrait
        ("social.landscape", "أفقي ، ١٩٢٠×١٠٨٠"),   // landscape
        ("a4.portrait",      "A4 عمودي"),
        ("a4.landscape",     "A4 أفقي"),
    ]

    /// One option per design-system theme (P7.5's "3–5 icons, one per
    /// design-system theme"): `id == nil` is the PRIMARY asset-catalog
    /// icon (hibr, the app's default theme ، `setAlternateIconName(nil)`
    /// always resets to this exact icon, so hibr needs no loose alternate
    /// files of its own). The other four are premium-gated alternates,
    /// each a loose-file set at the bundle root named
    /// `AppIcon-<ThemeName><size>@<scale>x.png` (`Makhtoot/AltIcons/`),
    /// declared in `Info.plist`'s `CFBundleAlternateIcons`/
    /// `CFBundleAlternateIcons~ipad`.
    private struct AppIconOption: Identifiable {
        let id: String?
        let displayName: String
        let isPremium: Bool
    }
    private let appIconOptions: [AppIconOption] = [
        AppIconOption(id: nil, displayName: "حِبر (افتراضي)", isPremium: false),
        AppIconOption(id: "Naqsh", displayName: "نَقش", isPremium: true),
        AppIconOption(id: "Raml", displayName: "رمل", isPremium: true),
        AppIconOption(id: "Tayf", displayName: "طيف", isPremium: true),
        AppIconOption(id: "Kufi", displayName: "كوفي", isPremium: true),
    ]

    var body: some View {
        List {
            Section {
                Picker(themeLabel, selection: $themeIDRaw) {
                    ForEach(MKThemeID.allCases) { id in
                        Text(id.displayName).tag(id.rawValue)
                    }
                }
                Picker(brandMarkLabel, selection: $brandMarkStyleRaw) {
                    ForEach(MKBrandMarkStyle.allCases) { style in
                        Text(style.displayName).tag(style.rawValue)
                    }
                }
                Picker(colorSchemeLabel, selection: $colorSchemeRaw) {
                    Text(colorSchemeSystemLabel).tag("system")
                    Text(colorSchemeLightLabel).tag("light")
                    Text(colorSchemeDarkLabel).tag("dark")
                }
            } header: {
                Text(appearanceSectionHeader)
            }

            Section {
                Picker(canvasPresetLabel, selection: $defaultCanvasPreset) {
                    ForEach(canvasPresets, id: \.id) { preset in
                        Text(preset.label).tag(preset.id)
                    }
                }
            } header: {
                Text(canvasSectionHeader)
            }

            Section {
                Toggle(showAutosaveLabel, isOn: $showAutosaveIndicator)
            } header: {
                Text(autosaveSectionHeader)
            } footer: {
                Text(autosaveFooter)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
            }

            Section {
                HStack {
                    Text(languageLabel)
                    Spacer()
                    Text(languageValueLabel)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                }
            } header: {
                Text(languageSectionHeader)
            } footer: {
                Text(languageFooter)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
            }

            // EU-7 (AUDIT_2026-07-28.md): `hasCompletedOnboarding` was a
            // one-way latch with no reset path ، a user who tapped «تخطى»
            // on first launch (the common case) could never see the four
            // onboarding screens again. Mirrors `ToolRailView.swift:320`'s
            // "إعادة الجولة التعريفية" tour-restart `Button` pattern, one
            // level up (the app's first-run onboarding, not the in-editor
            // tour).
            Section {
                Button {
                    onResetOnboarding()
                } label: {
                    Label(resetOnboardingLabel, systemImage: "arrow.counterclockwise.circle")
                }
            } footer: {
                Text(resetOnboardingFooter)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
            }

            if MKFeatureFlags.default.alternateAppIcons {
                appIconSection
            }
        }
        .mkDefaultFont(theme)
        .navigationTitle(Text(navTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if MKFeatureFlags.default.alternateAppIcons {
                currentIconName = UIApplication.shared.alternateIconName
            }
            entitlementState = container.entitlementProvider.state
            for await state in await container.entitlementResolver.states() {
                entitlementState = state
            }
        }
        .sheet(isPresented: $showsIconPaywall) {
            PaywallView(context: .settingsUpgrade) { showsIconPaywall = false }
        }
    }

    // MARK: - App icon (P7.5, Bug 17)

    @ViewBuilder
    private var appIconSection: some View {
        Section {
            ForEach(appIconOptions) { option in
                appIconRow(option)
            }
            if isSwitchingIcon {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
            if let iconSwitchErrorText {
                Text(iconSwitchErrorText)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.destructive)
            }
        } header: {
            Text(appIconSectionHeader)
        } footer: {
            // The system consent alert on an icon switch can't be
            // suppressed (Bug 17's own risk note) ، this footer sets that
            // expectation up front instead of surprising the user with an
            // unexplained system dialog.
            Text(appIconSectionFooter)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted)
        }
    }

    @ViewBuilder
    private func appIconRow(_ option: AppIconOption) -> some View {
        let isCurrent = currentIconName == option.id
        let isLocked = option.isPremium && !entitlementState.grantsPremiumAccess
        Button {
            guard !isLocked else { showsIconPaywall = true; return }
            switchIcon(to: option.id)
        } label: {
            HStack {
                Text(option.displayName)
                    .foregroundStyle(theme.ink)
                Spacer()
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(theme.primary)
                } else if isCurrent {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.primary)
                }
            }
            .frame(minHeight: 44)
        }
        .disabled(isSwitchingIcon)
    }

    /// Surfaces the real error instead of a silent no-op (the same "surface
    /// `MKFontError` in an alert" spirit P7.3 applies to font install ،
    /// here it's whatever `Error` `setAlternateIconName` hands back, e.g.
    /// the app not declaring the requested icon name in `Info.plist`).
    private func switchIcon(to name: String?) {
        isSwitchingIcon = true
        iconSwitchErrorText = nil
        UIApplication.shared.setAlternateIconName(name) { error in
            Task { @MainActor in
                isSwitchingIcon = false
                if let error {
                    iconSwitchErrorText = "\(iconSwitchFailureText) (\(error.localizedDescription))"
                } else {
                    currentIconName = UIApplication.shared.alternateIconName
                }
            }
        }
    }

    // MARK: - Strings (ar only ، D-100)

    private var navTitle: String { "عام" }
    private var appearanceSectionHeader: String { "المظهر" }
    private var themeLabel: String { "نمط التصميم" }
    private var brandMarkLabel: String { "شعار العلامة" }
    private var colorSchemeLabel: String { "المظهر الفاتح/الداكن" }
    private var colorSchemeSystemLabel: String { "حسب النظام" }
    private var colorSchemeLightLabel: String { "فاتح" }
    private var colorSchemeDarkLabel: String { "داكن" }
    private var canvasSectionHeader: String { "الإعدادات الافتراضية" }
    private var canvasPresetLabel: String { "نسبة عرض اللوحة" }
    private var autosaveSectionHeader: String { "الحفظ التلقائي" }
    private var showAutosaveLabel: String { "إظهار مؤشر الحفظ التلقائي" }
    private var autosaveFooter: String { "يُظهر مؤشرًا صغيرًا عند كل حفظ تلقائي." }
    private var languageSectionHeader: String { "اللغة" }
    private var languageLabel: String { "لغة التطبيق" }
    private var languageValueLabel: String { "العربية" } // D-100: fixed, no switcher
    private var languageFooter: String {
        "مخطوط متاح باللغة العربية فقط في هذا الإصدار."
    }

    // EU-7: replay onboarding. Latin gloss: "replay the intro screens" /
    // "returns you to the four intro screens shown on first use."
    private var resetOnboardingLabel: String { "إعادة عرض الجولة التعريفية" }
    private var resetOnboardingFooter: String {
        "يعيدك هذا إلى شاشات التعريف الأربع التي تظهر عند أول استخدام للتطبيق."
    }

    // Latin gloss: app icon
    private var appIconSectionHeader: String { "أيقونة التطبيق" }
    private var appIconSectionFooter: String {
        // Latin gloss: changing the icon requires system approval, and other icons besides the default require a premium subscription.
        "تغيير الأيقونة يتطلب موافقة النظام، والأيقونات الأخرى غير الافتراضية تتطلب اشتراكًا مميزًا."
    }
    private var iconSwitchFailureText: String {
        // Latin gloss: could not change the app icon
        "تعذّر تغيير أيقونة التطبيق"
    }
}
