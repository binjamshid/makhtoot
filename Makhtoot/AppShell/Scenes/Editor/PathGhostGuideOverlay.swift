import MKCanvas
import MKDesignSystem
import MKModel
import SwiftUI

/// R-9.9's "إظهار المسار" (show path) ghost guide: draws the FROZEN SOURCE
/// path of an arranged Path-Text composition as a dashed alignment aid
/// while Arrange Mode is active and the toggle is on
/// (`EditorViewModel.arrangedGhostGuidePath`, gated there on both the
/// toggle AND `arrangeInteraction.activeOwnerNode.derivedFrom` actually
/// being `.pathText`). Pure SwiftUI chrome layered into `EditorScene`'s
/// canvas `ZStack`, entirely separate from `MKRender`/`MKSnapshotRenderer`
/// ، by construction (this view is never on the export code path at all),
/// satisfying R-9.9's "never renders in export" requirement without any
/// export-side flag to remember.
///
/// **Screen-space transform ، documented approximation, not exact.**
/// `MKCanvasViewController.contentHostView` (canvas-space, origin `.zero`,
/// size = canvas size, `MKCanvasViewController.swift` read-only reference)
/// sits inside `.scrollView`; this overlay's own SwiftUI coordinate space
/// is assumed to coincide with that scroll view's frame (both fill the
/// same `canvasArea` region in `EditorScene`). The standard `UIScrollView`
/// content→view formula applies: `screenPoint = contentPoint * zoomScale -
/// contentOffset` (`contentOffset` already accounts for `contentInset` ،
/// a scroll view at rest sits at `-contentInset`, not `.zero`, per
/// `MKCanvasViewController`'s own centering-inset logic). Per this
/// deliverable's own instruction ("keep it simple, correctness > elegance"),
/// this is polled on the SAME ~150 ms cadence
/// `EditorViewModel.startZoomBucketPolling()` already uses for the
/// identical class of cross-UIKit-boundary signal, rather than a new
/// per-frame delegate hook (`MKCanvasViewController` is already its own
/// `UIScrollViewDelegate` ، see that method's own doc comment for why a
/// second hook isn't added here either). A guide overlay only needs to be
/// visually "close enough" to line up during a manual nudge, not
/// pixel-exact.
struct PathGhostGuideOverlay: View {
    @Environment(\.mkTheme) private var theme
    let viewModel: EditorViewModel

    @State private var zoomScale: CGFloat = 1
    @State private var contentOffset: CGPoint = .zero

    var body: some View {
        Group {
            if let pathData = viewModel.arrangedGhostGuidePath {
                GhostGuideShape(pathData: pathData, zoomScale: zoomScale, contentOffset: contentOffset)
                    .stroke(theme.primary.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                    .allowsHitTesting(false)
            }
        }
        .task { await pollTransform() }
    }

    @MainActor
    private func pollTransform() async {
        while !Task.isCancelled {
            if let scrollView = viewModel.canvasViewController?.scrollView {
                zoomScale = scrollView.zoomScale
                contentOffset = scrollView.contentOffset
            }
            try? await Task.sleep(for: .milliseconds(150))
        }
    }
}

private struct GhostGuideShape: Shape {
    let pathData: MKBezierPathData
    let zoomScale: CGFloat
    let contentOffset: CGPoint

    func path(in rect: CGRect) -> Path {
        let cgPath = pathData.cgPath()
        var transform = CGAffineTransform(scaleX: zoomScale, y: zoomScale)
            .concatenating(CGAffineTransform(translationX: -contentOffset.x, y: -contentOffset.y))
        guard let transformed = cgPath.copy(using: &transform) else { return Path() }
        return Path(transformed)
    }
}
