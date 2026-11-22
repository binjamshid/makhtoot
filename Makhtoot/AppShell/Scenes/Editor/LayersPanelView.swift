import MKCanvas
import MKDesignSystem
import MKFoundation
import SwiftUI

/// The طبقات (layers) panel over WS-06's `LayersModel` (packet T11).
/// Adaptive host (iPad persistent column vs iPhone sheet) is
/// `EditorScene`'s job ، this view is the panel BODY only, shared by both
/// presentations.
struct LayersPanelView: View {
    @Environment(\.mkTheme) private var theme
    let viewModel: EditorViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacing.xs) {
                ForEach(viewModel.layers.flattenedRows) { row in
                    LayerRowView(row: row, viewModel: viewModel)
                }
            }
            .padding(theme.spacing.md)
        }
        .background(theme.bg)
        .navigationTitle(Text(title))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var title: String {
        // Latin gloss: layers
        "الطبقات"
    }
}

private struct LayerRowView: View {
    @Environment(\.mkTheme) private var theme
    let row: LayersModel.LayerRow
    let viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            if row.depth > 0 {
                Spacer().frame(width: CGFloat(row.depth) * theme.spacing.lg)
            }
            if row.hasChildren {
                Button {
                    viewModel.layers.toggleExpanded(row.id)
                } label: {
                    Image(systemName: row.isExpanded ? "chevron.down" : "chevron.left")
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 14)
            }

            Text(row.name)
                .mkTypeStyle(theme.typeRamp.style(for: .callout))
                .foregroundStyle(row.isVisible ? theme.ink : theme.inkMuted)
                .lineLimit(1)

            if row.isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(theme.inkMuted)
            }

            Spacer(minLength: 0)

            Text(row.kindLabel)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted)

            if !row.isBackground {
                Button {
                    try? viewModel.layers.toggleVisibility(row.id)
                } label: {
                    Image(systemName: row.isVisible ? "eye" : "eye.slash")
                        .foregroundStyle(theme.inkMuted)
                }
                .buttonStyle(.plain)

                Button {
                    try? viewModel.layers.toggleLock(row.id)
                } label: {
                    Image(systemName: row.isLocked ? "lock" : "lock.open")
                        .foregroundStyle(theme.inkMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, theme.spacing.xs)
        .padding(.horizontal, theme.spacing.sm)
        .background(
            row.isSelected ? theme.primary.opacity(0.15) : Color.clear,
            in: RoundedRectangle(cornerRadius: theme.radius.button, style: theme.radius.style)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.layers.select(row.id)
            viewModel.refreshCanvasChrome()
        }
        .contextMenu {
            if !row.isBackground {
                Button(duplicateLabel) { try? viewModel.layers.duplicate(row.id) }
                Button(deleteLabel, role: .destructive) { try? viewModel.layers.delete(row.id) }
            }
        }
    }

    private var duplicateLabel: String {
        // Latin gloss: duplicate
        "تكرار"
    }

    private var deleteLabel: String {
        // Latin gloss: delete
        "حذف"
    }
}
