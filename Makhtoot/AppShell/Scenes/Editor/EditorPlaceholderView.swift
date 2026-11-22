import MKDesignSystem
import MKFoundation
import SwiftUI

/// SUPERSEDED (WS-13 P4 EDITOR-CHROME session, `docs/impl-log/WS-13.md`
/// Session 3): the real composition now lives in `EditorScene.swift`
/// (canvas host, toolbar, layers/inspector panels, autosave indicator,
/// memory-pressure banner) and `RootShellView` routes `.editor(id)` there
/// instead of here. This file is kept (not deleted) to avoid an
/// unnecessary `project.pbxproj` file-removal edit in a session already
/// making several additive pbxproj edits ، it is dead code, unreferenced
/// by any route, retained only for its `#Preview` and as a paper trail of
/// the P1 EARLY-SLICE shape. Safe to delete in a future cleanup pass.
struct EditorPlaceholderView: View {
    @Environment(\.mkTheme) private var theme
    let projectID: MKProjectID
    var onDone: () -> Void
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 48

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            Spacer()
            Image(systemName: "hammer")
                .font(.system(size: iconSize))
                .foregroundStyle(theme.inkMuted)
            Text(title)
                .mkTypeStyle(theme.typeRamp.style(for: .title2))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .mkTypeStyle(theme.typeRamp.style(for: .callout))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xl)
            Text(verbatim: projectID.description)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted.opacity(0.6))
            Spacer()
            Spacer()
        }
        .padding(theme.spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .navigationTitle(Text(navTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(doneLabel, action: onDone)
            }
        }
    }

    private var navTitle: String {
        // Latin gloss: editor
        "المحرر"
    }

    private var title: String {
        // Latin gloss: the editor is under construction
        "المحرر قيد الإنشاء"
    }

    private var subtitle: String {
        // Latin gloss: the canvas, layers, and inspector editor will be
        // built in a later work packet
        "سيُبنى محرر الكانفاس والطبقات والخصائص في حزمة عمل لاحقة"
    }

    private var doneLabel: String {
        // Latin gloss: done
        "تم"
    }
}

#Preview {
    NavigationStack {
        EditorPlaceholderView(projectID: MKProjectID()) {}
    }
    .environment(\.mkTheme, HibrTheme.default)
}
