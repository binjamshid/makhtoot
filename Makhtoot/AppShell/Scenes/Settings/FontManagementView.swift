import MKDesignSystem
import MKFonts
import MKFoundation
import SwiftUI
import UniformTypeIdentifiers

/// الخطوط ، font management (P7.2 Bug 18 + relocated P7.3 Bug 12).
///
/// Two responsibilities that both belong at the device/account scope, not
/// inside a per-selection editor sheet:
/// - **Import** (Bug 18): premium-gated user font import via `.fileImporter`
///   → `MKFontImporter`, surfacing every `MKFontError` (validator
///   rejection, corrupt file, checksum mismatch, …) instead of a generic or
///   silently-swallowed failure. `MKFontValidator` is a HARD gate here ،
///   `MKFontImporter.importFont` already throws on `.reject(_:)` before any
///   catalog/license record is created, so there is no path that registers
///   an unvalidated font.
/// - **System-wide install** (Bug 12, relocated): `CTFontManagerRegisterFontURLs
///   (_:.persistent:_:)` (`MKFontRegistry.installFontSystemWide`) is a
///   plain public CoreText API needing no entitlement/Info.plist key (only
///   triggering a one-time system consent dialog) ، but it is a
///   DEVICE-scoped, one-time action, and previously lived inside
///   `FontSettingsSheet` (a per-text-node formatting sheet), reachable only
///   while a text node happened to be selected. Moved here; a
///   "إدارة الخطوط…" row in that sheet still deep-links to this view for
///   discoverability from the editor.
struct FontManagementView: View {
    @Environment(\.mkTheme) private var theme
    @Environment(AppContainer.self) private var container

    @State private var records: [MKFontRecord] = []
    @State private var systemInstalledIDs: Set<MKFontID> = []
    @State private var showsFileImporter = false
    @State private var isImporting = false
    @State private var importErrorText: String?
    @State private var showsPaywall = false
    @State private var installErrorText: String?
    @State private var installingFontID: MKFontID?

    private var isEntitledToImport: Bool { container.entitlementProvider.isEntitled(.fontImport) }

    var body: some View {
        List {
            importSection
            installedFontsSection
        }
        .mkDefaultFont(theme)
        .navigationTitle(Text(navTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await refresh() }
        // System `UTType.font` ، no new UTI declarations needed (verified:
        // a plain public system content type, not an app-declared one).
        .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.font]) { result in
            switch result {
            case .success(let url): Task { await importFont(from: url) }
            case .failure: importErrorText = genericImportFailureText
            }
        }
        .sheet(isPresented: $showsPaywall) {
            PaywallView(context: .settingsUpgrade) { showsPaywall = false }
        }
    }

    // MARK: - Import section

    @ViewBuilder
    private var importSection: some View {
        Section {
            Button {
                guard isEntitledToImport else { showsPaywall = true; return }
                importErrorText = nil
                showsFileImporter = true
            } label: {
                HStack {
                    if isImporting {
                        ProgressView()
                    } else {
                        Label(importActionLabel, systemImage: "square.and.arrow.down")
                    }
                    Spacer()
                    if !isEntitledToImport {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(theme.primary)
                    }
                }
                .frame(minHeight: 44)
            }
            .disabled(isImporting)
            if let importErrorText {
                Text(importErrorText)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.destructive)
            }
        } header: {
            Text(importSectionHeader)
        } footer: {
            Text(importSectionFooter)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted)
        }
    }

    // MARK: - Installed-on-device section (P7.3, relocated)

    @ViewBuilder
    private var installedFontsSection: some View {
        Section {
            if records.isEmpty {
                ProgressView()
            } else {
                ForEach(records, id: \.fontID) { record in
                    installRow(record)
                }
            }
            if let installErrorText {
                Text(installErrorText)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.destructive)
            }
        } header: {
            Text(installedSectionHeader)
        } footer: {
            Text(installedSectionFooter)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted)
        }
    }

    @ViewBuilder
    private func installRow(_ record: MKFontRecord) -> some View {
        let isInstalled = systemInstalledIDs.contains(record.fontID)
        let isBusy = installingFontID == record.fontID
        HStack {
            Text(record.familyNameArabic ?? record.familyName)
                .foregroundStyle(theme.ink)
            Spacer()
            if isBusy {
                ProgressView()
            } else if isInstalled {
                Button(uninstallActionLabel) { uninstall(record.fontID) }
                    .foregroundStyle(theme.destructive)
            } else {
                Button(installActionLabel) { install(record.fontID) }
                    .foregroundStyle(theme.primary)
            }
        }
        .frame(minHeight: 44)
    }

    // MARK: - Actions

    private func refresh() async {
        records = await container.fontRegistry.records()
            .filter { !$0.isLocked }
            .sorted { ($0.familyNameArabic ?? $0.familyName) < ($1.familyNameArabic ?? $1.familyName) }
        systemInstalledIDs = await container.fontRegistry.systemInstalledFontIDs()
    }

    /// P7.3 (Bug 12): `FontSettingsSheet` previously discarded every
    /// install/uninstall error via `try?`, so a failed system-wide
    /// registration and a successful one looked identical. Both actions
    /// here surface the real `MKFontError` (a user cancellation of the
    /// system consent dialog still resolves as success, per
    /// `installFontSystemWide`'s own doc comment ، only a genuine
    /// registration failure reaches `installErrorText`).
    private func install(_ fontID: MKFontID) {
        installErrorText = nil
        installingFontID = fontID
        Task {
            do {
                try await container.fontRegistry.installFontSystemWide(fontID: fontID)
            } catch let error as MKFontError {
                installErrorText = error.arabicUserMessage
            } catch {
                installErrorText = genericInstallFailureText
            }
            systemInstalledIDs = await container.fontRegistry.systemInstalledFontIDs()
            installingFontID = nil
        }
    }

    private func uninstall(_ fontID: MKFontID) {
        installErrorText = nil
        installingFontID = fontID
        Task {
            do {
                try await container.fontRegistry.uninstallFontSystemWide(fontID: fontID)
            } catch let error as MKFontError {
                installErrorText = error.arabicUserMessage
            } catch {
                installErrorText = genericInstallFailureText
            }
            systemInstalledIDs = await container.fontRegistry.systemInstalledFontIDs()
            installingFontID = nil
        }
    }

    /// P7.2 requirement: the copy must happen INSIDE the security-scope
    /// bracket. `MKFontImporter.importFont(from:originalFilename:)` reads
    /// the source bytes (`Data(contentsOf:)`) near the very start of its
    /// own body and only returns once the content-addressed copy has
    /// landed in `Application Support/Fonts/Imported/` ، so the WHOLE
    /// `await` below, not just a synchronous prefix, must run while the
    /// scope is active.
    private func importFont(from url: URL) async {
        isImporting = true
        importErrorText = nil
        defer { isImporting = false }
        guard url.startAccessingSecurityScopedResource() else {
            importErrorText = genericImportFailureText
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            _ = try await container.fontImporter.importFont(from: url, originalFilename: url.lastPathComponent)
            await refresh()
        } catch let error as MKFontError {
            importErrorText = error.arabicUserMessage
        } catch {
            importErrorText = genericImportFailureText
        }
    }

    // MARK: - Strings (ar only ، D-100)

    private var navTitle: String { "الخطوط" }
    private var importSectionHeader: String {
        // Latin gloss: import font
        "استيراد خط"
    }
    private var importActionLabel: String {
        // Latin gloss: import a font from Files
        "استيراد خط من الملفات"
    }
    private var importSectionFooter: String {
        // Latin gloss: you can import TTF or OTF files. Compliance with the imported font's license is your responsibility.
        "يمكنك استيراد ملفات TTF أو OTF. الالتزام بترخيص الخط المستورد مسؤوليتك ، راجع صفحة التراخيص."
    }
    private var installedSectionHeader: String {
        // Latin gloss: install on device
        "التثبيت على الجهاز"
    }
    private var installedSectionFooter: String {
        // Latin gloss: installing a font on the device makes it available in other apps too, and asks for your approval via a system dialog.
        "تثبيت خط على الجهاز يجعله متاحًا في التطبيقات الأخرى أيضًا، ويطلب موافقتك عبر نافذة النظام."
    }
    private var installActionLabel: String {
        // Latin gloss: install
        "تثبيت"
    }
    private var uninstallActionLabel: String {
        // Latin gloss: uninstall
        "إلغاء التثبيت"
    }
    private var genericImportFailureText: String {
        // Latin gloss: could not import this file
        "تعذّر استيراد هذا الملف"
    }
    private var genericInstallFailureText: String {
        // Latin gloss: could not complete the operation
        "تعذّر إكمال العملية"
    }
}
