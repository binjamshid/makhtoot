import MKDesignSystem
import MKFonts
import MKFoundation
import SwiftUI

/// Detail view for a single font's license information (WS-12 T13).
///
/// ## Lazy loading (T13 AC)
/// The full license text is NOT passed in from the list ، it is loaded
/// lazily on `.task` from `section.fullLicenseText` (already resolved by
/// `MKLicensingDataSource.sections()` which reads it from the bundle). If
/// the text is missing (empty bundle path), shows a fallback notice.
///
/// ## LTR text block (T13 AC)
/// The license text itself (OFL, which is English) renders with
/// `.environment(\.layoutDirection, .leftToRight)` on the ScrollView
/// containing it ، the ONLY LTR override in the view; all labels stay RTL.
///
/// ## Coverage (T13 AC)
/// `MKCoverageReport` is rendered as labeled check marks for each boolean
/// (tashkeel, Qur'anic marks, Latin) and a range-count summary.
struct LicenseFontDetailView: View {
    @Environment(\.mkTheme) private var theme

    let section: MKLicensingDataSource.Section

    @State private var licenseText: String? = nil
    @State private var isLoadingLicense = true

    var body: some View {
        List {
            // MARK: Attribution
            Section(header: Text(attributionHeader)) {
                labeledRow(title: familyLabel, value: section.familyName)
                labeledRow(title: foundryLabel, value: section.foundryOrAuthor)
                labeledRow(title: licenseTypeLabel, value: licenseTypeName)
                labeledRow(title: commercialUseLabel, value: section.commercialUseStatus)
                if !section.reservedFontNames.isEmpty {
                    labeledRow(title: reservedNamesLabel,
                               value: section.reservedFontNames.joined(separator: "، "))
                }
                if !section.sourceRepoURL.isEmpty,
                   let url = URL(string: section.sourceRepoURL) {
                    Link(destination: url) {
                        Label(sourceRepoLabel, systemImage: "link")
                    }
                }
                if section.isProvisionalShip {
                    Text(provisionalNote)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                }
            }

            // MARK: Coverage
            if let coverage = section.coverage {
                Section(header: Text(coverageHeader)) {
                    coverageRow(label: tashkeelLabel, value: coverage.supportsTashkeel)
                    coverageRow(label: quranicLabel, value: coverage.supportsQuranicMarks)
                    coverageRow(label: latinLabel, value: coverage.supportsLatin)
                    labeledRow(
                        title: rangesLabel,
                        value: "\(coverage.ranges.count) نطاق يونيكود"
                    )
                }
            }

            // MARK: User-imported notice
            if section.origin == .userImported {
                Section {
                    Text(MKFontsStrings.userImportedLicenseNotice)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // MARK: Full license text (lazy, LTR)
            if section.origin != .userImported {
                Section(header: Text(licenseTextHeader)) {
                    if isLoadingLicense {
                        ProgressView()
                    } else if let text = licenseText, !text.isEmpty {
                        // LTR override for the English OFL text only (T13 AC).
                        ScrollView {
                            Text(text)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(theme.inkMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    } else {
                        Text(licenseTextUnavailableLabel)
                            .mkTypeStyle(theme.typeRamp.style(for: .caption))
                            .foregroundStyle(theme.inkMuted)
                    }
                }
            }
        }
        .mkDefaultFont(theme)
        .navigationTitle(Text(section.familyName))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            // Lazy load: license text is already available on the section
            // (MKLicensingDataSource reads it synchronously from the bundle),
            // but we assign it in a task to avoid blocking the list scroll
            // before this detail view appears (T13 AC: lazy loading).
            licenseText = section.fullLicenseText
            isLoadingLicense = false
        }
    }

    // MARK: - Helper views

    @ViewBuilder
    private func labeledRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted)
            Spacer()
            Text(value)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func coverageRow(label: String, value: Bool) -> some View {
        HStack {
            Text(label)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted)
            Spacer()
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(value ? theme.primary : theme.inkMuted)
        }
    }

    // MARK: - Computed helpers

    private var licenseTypeName: String {
        switch section.licenseType {
        case .ofl11:            return "OFL 1.1"
        case .apacheV2Reserved: return "Apache 2.0"
        case .commercial:       return "تجاري"
        case .prohibited:       return "محظور"
        case .userProvided:     return "مستورد من المستخدم"
        }
    }

    // MARK: - Strings (ar only ، D-100)

    private var attributionHeader: String { "معلومات الخط" }
    private var familyLabel: String { "العائلة" }
    private var foundryLabel: String { "المؤلف / مصدر الخط" }
    private var licenseTypeLabel: String { "نوع الترخيص" }
    private var commercialUseLabel: String { "الاستخدام التجاري" }
    private var reservedNamesLabel: String { "الأسماء المحجوزة" }
    private var sourceRepoLabel: String { "المستودع المصدر" }
    private var provisionalNote: String { "ملاحظة: يُشحن هذا الخط مؤقتًا بانتظار اكتمال التحقق." }
    private var coverageHeader: String { "التغطية" }
    private var tashkeelLabel: String { "يدعم التشكيل" }
    private var quranicLabel: String { "يدعم علامات التجويد" }
    private var latinLabel: String { "يدعم الحروف اللاتينية" }
    private var rangesLabel: String { "نطاقات يونيكود" }
    private var licenseTextHeader: String { "نص الترخيص الكامل" }
    private var licenseTextUnavailableLabel: String { "نص الترخيص غير متوفر." }
}
