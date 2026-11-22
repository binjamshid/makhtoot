import MKDesignSystem
import MKFoundation
import SwiftUI

/// دمج تصميم ، P7.4 (§2.2 "Merge Design"): pick another saved project so
/// its nodes can be imported into the CURRENT scene
/// (`EditorViewModel.mergeDesign(fromProjectID:library:)` →
/// `CanvasSession.mergeDesign(fromPackageAt:)`). Deliberately minimal (a
/// flat, searchable list, no folders) ، this is a one-off "bring content
/// in" picker, not a second project browser.
struct MergeDesignSheet: View {
    @Environment(\.mkTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container

    /// Excluded from the list ، merging a project into itself would just
    /// re-insert id-reassigned copies of the exact nodes already in this
    /// same scene, which is never useful.
    let excludingProjectID: MKProjectID
    let onMerge: (MKProjectID) -> Void

    @State private var projects: [ProjectSummary] = []
    @State private var searchText = ""
    @State private var isLoading = true

    private var filtered: [ProjectSummary] {
        let base = projects.filter { $0.id != excludingProjectID && !$0.isOrphaned }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    emptyStateView
                } else {
                    List(filtered) { project in
                        Button {
                            onMerge(project.id)
                            dismiss()
                        } label: {
                            HStack {
                                Text(project.name)
                                    .foregroundStyle(theme.ink)
                                Spacer()
                                Text(MKArabicRelativeDate.string(from: project.modifiedAt))
                                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                                    .foregroundStyle(theme.inkMuted)
                            }
                            .frame(minHeight: 44)
                        }
                    }
                    .searchable(text: $searchText)
                }
            }
            .navigationTitle(Text(navTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelLabel) { dismiss() }
                }
            }
        }
        .task {
            projects = await container.projectLibrary.fetchAll()
            isLoading = false
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: theme.spacing.sm) {
            Spacer()
            Text(emptyStateText)
                .mkTypeStyle(theme.typeRamp.style(for: .callout))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Strings (ar only ، D-100)

    private var navTitle: String {
        // Latin gloss: merge design
        "دمج تصميم"
    }
    private var cancelLabel: String { "إلغاء" }
    private var emptyStateText: String {
        // Latin gloss: no other projects to merge
        "لا توجد مشاريع أخرى لدمجها"
    }
}
