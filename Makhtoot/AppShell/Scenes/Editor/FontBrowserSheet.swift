import MKDesignSystem
import MKFonts
import MKFoundation
import MKModel
import SwiftUI

/// Font browser sheet — shown when the user taps the Font row in
/// either the inspector panel or the font settings sheet. Lists every
/// registered `MKFontRecord` with the selected text rendered in that face.
struct FontBrowserSheet: View {
    @Environment(\.mkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let fontRegistry: MKFontRegistry
    let currentFontID: String?
    let sampleText: String
    let onSelect: (MKFontRef) -> Void

    @State private var records: [MKFontRecord] = []
    @State private var systemInstalledIDs: Set<MKFontID> = []

    private var effectiveSample: String {
        sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "بسم الله الرحمن الرحيم"
            : sampleText
    }

    /// P7.2 (Bug 18): user-imported fonts (`MKFontImporter`) get their own
    /// "خطوطي" section, matching `LicensingView`'s own bundled/premium/
    /// imported grouping convention (`MKFontOrigin`).
    private var myFonts: [MKFontRecord] { records.filter { $0.origin == .userImported } }
    private var catalogFonts: [MKFontRecord] { records.filter { $0.origin != .userImported } }

    var body: some View {
        NavigationStack {
            List {
                if !myFonts.isEmpty {
                    Section(header: Text(myFontsHeader)) {
                        ForEach(myFonts, id: \.fontID) { record in
                            fontRow(record)
                                .listRowBackground(
                                    record.fontID == currentFontID
                                        ? theme.surface
                                        : Color.clear
                                )
                        }
                    }
                }
                Section {
                    ForEach(catalogFonts, id: \.fontID) { record in
                        fontRow(record)
                            .listRowBackground(
                                record.fontID == currentFontID
                                    ? theme.surface
                                    : Color.clear
                            )
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("اختر الخط")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
            }
            .task {
                records = await fontRegistry.records()
                    .filter { !$0.isLocked }
                    .sorted { ($0.familyNameArabic ?? $0.familyName) < ($1.familyNameArabic ?? $1.familyName) }
                systemInstalledIDs = await fontRegistry.systemInstalledFontIDs()
            }
        }
    }

    // Latin gloss: my fonts
    private var myFontsHeader: String { "خطوطي" }

    @ViewBuilder
    private func fontRow(_ record: MKFontRecord) -> some View {
        let face = record.defaultFace
        let isInstalled = systemInstalledIDs.contains(record.fontID)
        Button {
            if let face {
                let ref = MKFontRef(fontID: record.fontID, postScriptName: face.postScriptName)
                onSelect(ref)
                dismiss()
            }
        } label: {
            HStack(spacing: theme.spacing.md) {
                VStack(alignment: .trailing, spacing: theme.spacing.xs) {
                    HStack(spacing: theme.spacing.xs) {
                        if isInstalled {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                // Design-token triage: no dedicated "success"
                                // semantic exists in `MKTheme` ، `theme.primary`
                                // is this same file's own existing token for
                                // "affirmative/selected" state (see the
                                // `currentFontID` checkmark below), so this
                                // installed-indicator reuses it rather than a
                                // hardcoded system color.
                                .foregroundStyle(theme.primary)
                        }
                        Text(record.familyNameArabic ?? record.familyName)
                            .mkTypeStyle(theme.typeRamp.style(for: .callout))
                            .foregroundStyle(theme.ink)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    if let psName = face?.postScriptName {
                        Text(effectiveSample)
                            .font(.custom(psName, size: 18))
                            .foregroundStyle(theme.ink)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .lineLimit(1)
                    }
                }
                if record.fontID == currentFontID {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.primary)
                }
            }
            .padding(.vertical, theme.spacing.xs)
            .environment(\.layoutDirection, .rightToLeft)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            if isInstalled {
                Button("إلغاء التثبيت") {
                    Task {
                        try? await fontRegistry.uninstallFontSystemWide(fontID: record.fontID)
                        systemInstalledIDs = await fontRegistry.systemInstalledFontIDs()
                    }
                }
                // Design-token triage: uninstalling is a destructive/removal
                // action ، `theme.destructive` is the exact semantic token
                // for that (used identically for other removal actions app-
                // wide), not a hardcoded system red.
                .tint(theme.destructive)
            } else {
                Button("تثبيت على الجهاز") {
                    Task {
                        try? await fontRegistry.installFontSystemWide(fontID: record.fontID)
                        systemInstalledIDs = await fontRegistry.systemInstalledFontIDs()
                    }
                }
                // Design-token triage: no dedicated "success"/"confirm"
                // semantic exists in `MKTheme` ، `theme.primary` is this same
                // file's own existing token for an affirmative/primary
                // action (see the installed-indicator above), reused here
                // instead of a hardcoded system green.
                .tint(theme.primary)
            }
        }
    }
}
