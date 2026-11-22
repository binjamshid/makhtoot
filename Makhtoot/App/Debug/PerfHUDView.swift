import MKDesignSystem
import MKFoundation
import MKRender
import SwiftUI

#if DEBUG
/// Adapts `EditorViewModel`'s live state to WS-07's `MKRenderPerfHUDDataSource`
/// seam (`MakhtootKit/Sources/MKRender/RenderSignposts.swift`) ، that
/// file's own doc comment: "`Makhtoot/App/Debug/PerfHUDView.swift` (WS-13,
/// app-target ، outside this packet's fence) is expected to render: frame
/// time, memory stage, cache bytes." This is that consumer.
///
/// `bitmapCacheBytes` is honestly reported as `0` ، `MKLayerTreeController`
/// (the real `RenderTreeProviding` conformer this editor wires in) does
/// its own per-node `layer.contents` caching via a plain dictionary, not
/// WS-07's `BitmapCache` actor (confirmed by inspection: no `BitmapCache`
/// reference anywhere in `LayerTreeBuilder.swift`) ، there is no real
/// byte-accounted cache attached to the live canvas to report a number
/// from yet. Flagged here rather than fabricated.
@MainActor
final class EditorPerfHUDDataSource: MKRenderPerfHUDDataSource {
    private weak var viewModel: EditorViewModel?

    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
    }

    func currentPerfSnapshot() -> MKRenderPerfSnapshot {
        guard let viewModel else {
            return MKRenderPerfSnapshot(lastFrameDuration: 0, memoryStage: .normal, bitmapCacheBytes: 0, rasterizationsSinceLastRead: 0)
        }
        return MKRenderPerfSnapshot(
            lastFrameDuration: viewModel.lastManipulationFrameDuration,
            memoryStage: viewModel.memoryBannerText == nil ? .normal : .stage2,
            bitmapCacheBytes: 0,
            rasterizationsSinceLastRead: viewModel.renderAdapter.consumeRasterizationCount()
        )
    }
}

/// The DEBUG perf HUD (WS-07 packet §8 deliverable, deferred to this
/// session ، see `EditorPerfHUDDataSource`'s doc comment). A small
/// floating overlay polling `dataSource.currentPerfSnapshot()` on a
/// timer; DEBUG-builds only, toggled from the editor's DEBUG menu.
struct PerfHUDView: View {
    @Environment(\.mkTheme) private var theme
    let dataSource: any MKRenderPerfHUDDataSource

    @State private var snapshot: MKRenderPerfSnapshot?

    var body: some View {
        VStack(alignment: .trailing, spacing: theme.spacing.xs) {
            row(label: "frame", value: frameText)
            row(label: "stage", value: "\(snapshot?.memoryStage.rawValue ?? 0)")
            row(label: "raster", value: "\(snapshot?.rasterizationsSinceLastRead ?? 0)")
        }
        .padding(theme.spacing.sm)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: theme.radius.button, style: theme.radius.style))
        .task {
            while !Task.isCancelled {
                snapshot = dataSource.currentPerfSnapshot()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private var frameText: String {
        guard let ms = snapshot?.lastFrameDuration, ms > 0 else { return "-" }
        return String(format: "%.2f ms", ms * 1000)
    }

    private func row(label: String, value: String) -> some View {
        HStack(spacing: theme.spacing.xs) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }
}
#endif
