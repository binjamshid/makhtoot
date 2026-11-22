import MKAnalytics
import MKDesignSystem
import MKFoundation
import SwiftUI

/// الدعم ، Support section (WS-12 T12).
/// Includes: حول التطبيق (About), تواصل معنا (Contact), التراخيص (Licensing).
struct SupportSettingsView: View {
    @Environment(\.mkTheme) private var theme

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            // MARK: About
            Section(header: Text(aboutHeader)) {
                HStack {
                    Text(appNameLabel)
                    Spacer()
                    Text(appNameValue)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                }
                HStack {
                    Text(versionLabel)
                    Spacer()
                    Text(appVersion)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                }
                Text(creditsLine)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
            }

            // MARK: Contact
            Section(header: Text(contactHeader)) {
                if let mailURL = URL(string: "mailto:\(MKLegalLinks.supportEmail)") {
                    Link(destination: mailURL) {
                        Label(contactLabel, systemImage: "envelope")
                    }
                }
            }

            // MARK: Licensing → T13
            Section {
                NavigationLink {
                    LicensingView()
                } label: {
                    Label(licensingLabel, systemImage: "doc.text")
                }
            } header: {
                Text(licensingHeader)
            } footer: {
                Text(licensingFooter)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .mkDefaultFont(theme)
        .navigationTitle(Text(navTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Strings (ar only ، D-100)

    private var navTitle: String { "الدعم" }
    private var aboutHeader: String { "حول التطبيق" }
    private var appNameLabel: String { "التطبيق" }
    private var appNameValue: String { "مخطوط ، Makhtoot" }
    private var versionLabel: String { "الإصدار" }
    private var creditsLine: String { "صُنع بحبٍّ للخط العربي." }
    private var contactHeader: String { "تواصل معنا" }
    private var contactLabel: String { "راسلنا" }
    private var licensingHeader: String { "التراخيص" }
    private var licensingLabel: String { "التراخيص وحقوق الخطوط" }
    private var licensingFooter: String {
        "جميع الخطوط المدمجة مرخّصة بموجب OFL 1.1 أو المستخدم مسؤول عن خطوطه المستوردة."
    }
}
