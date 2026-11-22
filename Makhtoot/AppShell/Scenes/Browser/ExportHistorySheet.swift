import MKDesignSystem
import SwiftUI

/// T16's browser entry point: project context-menu "سجل التصدير"
/// (export history) → a list read from `MetadataStore.exportHistory`
/// (WS-02, exposed through `ProjectLibraryProviding.exportHistory(_:)`).
/// Re-share via `ShareLink` is only offered once WS-08 actually writes
/// export output files with a recoverable bookmark ، `MKExportRecord`
/// carries an `outputBookmark` field but nothing populates it yet (no
/// `MKExport` implementation exists this session), so this sheet renders
/// records read-only. Expected to be empty in this slice (no export flow
/// exists to create records) ، the empty state below is not a placeholder
/// hiding missing wiring, it is what an honestly-empty history looks like.
struct ExportHistorySheet: View {
    @Environment(\.mkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let projectName: String
    let entries: [ProjectExportHistoryEntry]
    @ScaledMetric(relativeTo: .body) private var emptyStateIconSize: CGFloat = 36

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    List(entries) { entry in
                        row(entry)
                    }
                }
            }
            .navigationTitle(Text(navTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeLabel) { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacing.md) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: emptyStateIconSize))
                .foregroundStyle(theme.inkMuted)
            Text(emptyTitle)
                .mkTypeStyle(theme.typeRamp.style(for: .callout))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xl)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
    }

    private func row(_ entry: ProjectExportHistoryEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(entry.format.uppercased())
                    .mkTypeStyle(theme.typeRamp.style(for: .callout))
                    .foregroundStyle(theme.ink)
                Text(MKArabicRelativeDate.string(from: entry.date))
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            if !entry.success {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.destructive)
            }
        }
    }

    // MARK: - Strings

    private var navTitle: String {
        // Latin gloss: export history
        "سجل التصدير"
    }

    private var closeLabel: String {
        "إغلاق"
    }

    private var emptyTitle: String {
        // Latin gloss: no exports have been made from this project yet
        "لم يتم تصدير هذا المشروع بعد"
    }
}

#Preview {
    ExportHistorySheet(projectName: "تصميم بلا عنوان ١", entries: [])
        .environment(\.mkTheme, HibrTheme.default)
}
