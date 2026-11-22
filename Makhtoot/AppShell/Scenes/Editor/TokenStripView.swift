import MKCanvas
import MKDesignSystem
import MKFoundation
import MKModel
import SwiftUI

/// P2.4: a horizontal chip strip below the canvas, one chip per top-level
/// TEXT node (`.liveText`/`.pathText`) ، a more phone-discoverable surface
/// than opening the full `LayersPanelView` sheet just to jump between text
/// objects (P2.2's split tokens/P2.3's grouped lines are exactly the case
/// this helps with: many small top-level pieces that are tedious to find
/// one-by-one in the tree). `LayersPanelView` stays as the full-tree
/// surface ، this is additional, not a replacement (master-plan
/// instruction).
///
/// `LayersModel.flattenedRows`/`.select(_:)` already expose everything a
/// flat strip needs (master-plan instruction: "no new model plumbing is
/// required") ، this view only FILTERS the existing top-level rows down to
/// text-bearing kinds (checked against the live `session.scene`, not a
/// string comparison against `LayerRow.kindLabel`) and reuses `MKChip` for
/// styling, matching `EditorScene.panelToggleRow`'s existing `MKChip`
/// usage.
struct TokenStripView: View {
    @Environment(\.mkTheme) private var theme
    let viewModel: EditorViewModel

    private struct Entry: Identifiable {
        let id: MKNodeID
        let label: String
        let isSelected: Bool
    }

    private var entries: [Entry] {
        viewModel.layers.flattenedRows
            .filter { $0.depth == 0 && !$0.isBackground }
            .compactMap { row -> Entry? in
                let text: String
                switch viewModel.session.scene.node(id: row.id) {
                case .liveText(let n): text = n.text.string
                case .pathText(let n): text = n.text.string
                default: return nil
                }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return Entry(id: row.id, label: Self.truncated(trimmed.isEmpty ? row.name : trimmed), isSelected: row.isSelected)
            }
    }

    private static func truncated(_ s: String, max: Int = 16) -> String {
        guard s.count > max else { return s }
        return String(s.prefix(max)) + "…"
    }

    var body: some View {
        let rows = entries
        if !rows.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.xs) {
                    ForEach(rows) { entry in
                        MKChip(title: entry.label, isSelected: entry.isSelected) {
                            viewModel.layers.select(entry.id)
                        }
                    }
                }
            }
            .mkFloatingBar()
        }
    }
}
