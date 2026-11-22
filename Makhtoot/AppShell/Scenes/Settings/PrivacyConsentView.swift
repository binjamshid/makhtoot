import MKAnalytics
import MKDesignSystem
import MKFoundation
import SwiftUI

/// الخصوصية ، Analytics consent screen (WS-12 T10).
///
/// Shows the Arabic disclosure text (T6/MKDisclosureContent.v1), the
/// single opt-in toggle (default OFF per D-125/Q43/Q79), the last-upload
/// status line, the data-deletion action, and the legal links (T14).
///
/// The toggle state is synchronised with `MKConsentManager` inside
/// `container.analyticsService`. All state transitions are async to keep
/// the actor-isolated consent writes off the main thread, with the UI
/// updated on `.mainActor` after each transition.
struct PrivacyConsentView: View {
    @Environment(\.mkTheme) private var theme
    @Environment(AppContainer.self) private var container

    @State private var isConsentGranted: Bool = false
    @State private var lastUploadWeek: String? = nil
    @State private var isTogglingConsent = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            // MARK: Disclosure section
            Section {
                Text(disclosureText)
                    .mkTypeStyle(theme.typeRamp.style(for: .body))
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text(disclosureSectionHeader)
            }

            // MARK: Consent toggle
            Section {
                Toggle(isOn: Binding(
                    get: { isConsentGranted },
                    set: { newValue in
                        Task { await toggleConsent(on: newValue) }
                    }
                )) {
                    Label(consentToggleLabel, systemImage: "chart.bar")
                }
                .disabled(isTogglingConsent)

                if let week = lastUploadWeek {
                    HStack {
                        Text(lastUploadLabel)
                            .mkTypeStyle(theme.typeRamp.style(for: .caption))
                            .foregroundStyle(theme.inkMuted)
                        Spacer()
                        Text(week)
                            .mkTypeStyle(theme.typeRamp.style(for: .caption))
                            .foregroundStyle(theme.inkMuted)
                    }
                } else if isConsentGranted {
                    Text(noUploadYetLabel)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                }
            } footer: {
                Text(consentFooter)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
            }

            // MARK: Data deletion
            if isConsentGranted {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label(deleteDataLabel, systemImage: "trash")
                    }
                } footer: {
                    Text(deleteDataFooter)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                }
            }

            // MARK: Legal links (T14 / Guideline 3.1.2)
            Section {
                if let privacyURL = URL(string: MKLegalLinks.privacyPolicyURL) {
                    Link(destination: privacyURL) {
                        Label(privacyPolicyLabel, systemImage: "doc.text")
                    }
                }
                if let termsURL = URL(string: MKLegalLinks.termsOfUseURL) {
                    Link(destination: termsURL) {
                        Label(termsLabel, systemImage: "doc.text")
                    }
                }
            } header: {
                Text(legalSectionHeader)
            }
        }
        .mkDefaultFont(theme)
        .navigationTitle(Text(navTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .confirmationDialog(
            deleteConfirmTitle,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(deleteConfirmAction, role: .destructive) {
                Task { await revokeAndDelete() }
            }
            Button(cancelLabel, role: .cancel) {}
        } message: {
            Text(deleteConfirmMessage)
        }
        .task { await loadState() }
    }

    // MARK: - Actions

    private func loadState() async {
        isConsentGranted = await container.analyticsService.isConsentGranted
        lastUploadWeek = await container.analyticsService.lastRecordedWeek
    }

    private func toggleConsent(on newValue: Bool) async {
        isTogglingConsent = true
        defer { isTogglingConsent = false }
        if newValue {
            try? await container.analyticsService.grantConsent()
        } else {
            try? await container.analyticsService.revokeConsent()
        }
        await loadState()
    }

    private func revokeAndDelete() async {
        try? await container.analyticsService.revokeConsent()
        await loadState()
    }

    // MARK: - Strings (ar only ، D-100)

    private var navTitle: String { "الخصوصية" }
    private var disclosureSectionHeader: String { "ما نجمعه" }
    private var disclosureText: String { MKDisclosureContent.v1 }
    private var consentToggleLabel: String { "مشاركة بيانات الاستخدام" }
    private var consentFooter: String {
        "إيقاف هذا المفتاح في أي وقت يُوقف الجمع ويحذف البيانات المحلية فورًا."
    }
    private var lastUploadLabel: String { "آخر رفع:" }
    private var noUploadYetLabel: String { "لم يُرفع أي بيانات بعد." }
    private var deleteDataLabel: String { "حذف البيانات المحلية" }
    private var deleteDataFooter: String {
        "يُوقف المشاركة ويحذف جميع العدادات المحلية."
    }
    private var legalSectionHeader: String { "القانونية" }
    private var privacyPolicyLabel: String { "سياسة الخصوصية" }
    private var termsLabel: String { "شروط الاستخدام" }
    private var deleteConfirmTitle: String { "حذف البيانات المحلية؟" }
    private var deleteConfirmMessage: String {
        "سيُوقف هذا المشاركة ويحذف جميع بيانات الاستخدام المحلية."
    }
    private var deleteConfirmAction: String { "حذف" }
    private var cancelLabel: String { "إلغاء" }
}
