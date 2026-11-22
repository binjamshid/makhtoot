#if MAKHTOOT_REFERRAL_ENABLED
import MKDesignSystem
import MKFoundation
import MKStore
import SwiftUI

/// الدعوات ، Referral screen (D-327, activating D-124/T14).
///
/// Every Arabic string here is an in-file literal, never an entry in
/// `Localizable.xcstrings`. That is D-225's string-catalog isolation rule,
/// which D-327 deliberately **retains** even though it drops D-225's
/// Release-exclusion rule: referral vocabulary must stay out of localization
/// extraction regardless of whether the feature ships.
///
/// The whole file is `#if MAKHTOOT_REFERRAL_ENABLED`-gated, so removing the
/// two flag definitions (Package.swift + project.pbxproj) restores D-225's
/// behaviour without deleting anything.
struct ReferralSection: View {
    @Environment(\.mkTheme) private var theme
    @Environment(AppContainer.self) private var container

    @State private var myCode: String?
    @State private var enteredCode: String = ""
    @State private var extensionsGranted: Int = 0
    @State private var isRedeeming = false
    /// `nil` = nothing to report yet. Success and failure share one slot
    /// because only the most recent attempt is worth showing.
    @State private var outcome: Outcome?

    private enum Outcome: Equatable {
        case granted
        case recordedWithoutGrant
        case failed(String)
    }

    private var identity: MKReferralIdentity { MKReferralIdentity() }
    private var ledger: MKReferralLedger {
        MKReferralLedger(trialManager: container.trialManager)
    }

    var body: some View {
        List {
            myCodeSection
            enterCodeSection
            statusSection
        }
        .mkDefaultFont(theme)
        .tint(theme.primary)
        .scrollContentBackground(.hidden)
        .background(theme.bgAlt)
        .navigationTitle(Text(navTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            myCode = await identity.myCode()
            extensionsGranted = await ledger.extensionsGranted()
        }
    }

    // MARK: - My code

    @ViewBuilder
    private var myCodeSection: some View {
        Section {
            if let myCode {
                HStack {
                    Text(myCode)
                        .mkTypeStyle(theme.typeRamp.style(for: .title))
                        .foregroundStyle(theme.ink)
                        // The code is Latin/digits; force LTR so it doesn't
                        // get reordered inside the RTL layout (D-108).
                        .environment(\.layoutDirection, .leftToRight)
                    Spacer()
                    ShareLink(item: shareMessage(code: myCode)) {
                        Label(shareLabel, systemImage: "square.and.arrow.up")
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel(Text(shareLabel))
                }
            } else {
                ProgressView()
            }
        } header: {
            Text(myCodeHeader)
        } footer: {
            Text(myCodeFooter)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted)
        }
    }

    // MARK: - Enter a code

    @ViewBuilder
    private var enterCodeSection: some View {
        Section {
            TextField(enterCodePlaceholder, text: $enteredCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .environment(\.layoutDirection, .leftToRight)
                .multilineTextAlignment(.leading)
                .disabled(isRedeeming)

            Button {
                redeem()
            } label: {
                if isRedeeming {
                    ProgressView()
                } else {
                    Text(redeemLabel)
                }
            }
            .disabled(isRedeeming || enteredCode.trimmingCharacters(in: .whitespaces).isEmpty)

            if let outcome {
                outcomeRow(outcome)
            }
        } header: {
            Text(enterCodeHeader)
        } footer: {
            Text(enterCodeFooter)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted)
        }
    }

    @ViewBuilder
    private func outcomeRow(_ outcome: Outcome) -> some View {
        switch outcome {
        case .granted:
            Label(grantedMessage, systemImage: "checkmark.circle")
                .foregroundStyle(theme.primary)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
        case .recordedWithoutGrant:
            Label(capReachedMessage, systemImage: "info.circle")
                .foregroundStyle(theme.inkMuted)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.circle")
                .foregroundStyle(theme.destructive)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusSection: some View {
        Section {
            HStack {
                Text(extensionsLabel)
                Spacer()
                Text("\(extensionsGranted) / \(MKReferralLedger.maxExtensions)")
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
                    .environment(\.layoutDirection, .leftToRight)
            }
        } footer: {
            Text(statusFooter)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted)
        }
    }

    // MARK: - Actions

    private func redeem() {
        guard let myCode else { return }
        let entry = enteredCode
        isRedeeming = true
        outcome = nil
        Task {
            let ledger = self.ledger
            let before = await ledger.extensionsGranted()
            do {
                try await MKReferralRedemption.redeem(
                    enteredCode: entry,
                    myOwnCode: myCode,
                    ledger: ledger
                )
                let after = await ledger.extensionsGranted()
                // `redeem` succeeding means the code was new and recorded; it
                // does NOT mean days were granted — the cap and the
                // dormant-revival window can both swallow the grant silently
                // (MKReferralLedger.recordRedemption). Comparing the count is
                // the only honest way to tell the user which happened.
                extensionsGranted = after
                outcome = after > before ? .granted : .recordedWithoutGrant
                enteredCode = ""
            } catch let error as MKReferralRedemptionError {
                outcome = .failed(error.errorDescription ?? invalidFallback)
            } catch {
                outcome = .failed(invalidFallback)
            }
            isRedeeming = false
        }
    }

    private func shareMessage(code: String) -> String {
        "جرّب مخطوط ، تطبيق تصميم الخط العربي. استخدم رمز الدعوة: \(code)"
    }

    // MARK: - Strings (ar only ، D-100; in-file literals ، D-225/D-327)

    private var navTitle: String { "الدعوات" }
    private var myCodeHeader: String { "رمز الدعوة الخاص بك" }
    private var myCodeFooter: String {
        "شارك هذا الرمز مع من تدعوه. عندما يُدخل صديقك رمزك، تحصل أنت على ٧ أيام إضافية من التجربة."
    }
    private var shareLabel: String { "مشاركة" }
    private var enterCodeHeader: String { "أدخل رمز دعوة" }
    private var enterCodePlaceholder: String { "MK-XXXXXXXX" }
    private var enterCodeFooter: String {
        "أدخل رمز دعوة وصلك من شخص آخر. لا يمكنك إدخال رمزك أنت، ولا إدخال الرمز نفسه مرتين."
    }
    private var redeemLabel: String { "تفعيل الرمز" }
    private var grantedMessage: String { "تمت إضافة ٧ أيام إلى فترة التجربة." }
    private var capReachedMessage: String {
        "تم تسجيل الرمز، لكن لم تُضف أيام ، إمّا لبلوغك الحد الأقصى أو لانتهاء فترة التجربة منذ مدة طويلة."
    }
    private var invalidFallback: String { "رمز الدعوة غير صالح." }
    private var extensionsLabel: String { "الأيام المُضافة" }
    private var statusFooter: String {
        "الحد الأقصى \(MKReferralLedger.maxExtensions) دعوات ، أي \(MKReferralLedger.maxExtensions * 7) يومًا إضافيًا كحدٍّ أعلى."
    }
}
#endif
