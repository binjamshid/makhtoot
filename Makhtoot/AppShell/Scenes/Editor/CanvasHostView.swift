import MKCanvas
import MKDesignSystem
import SwiftUI
import UIKit

/// Hosts the real `MKCanvasViewController` (WS-06) inside SwiftUI (packet
/// T11: "hosts `MKCanvasHosting` UIKit view full-bleed"). Attaches WS-07's
/// real render tree (`MKCanvasRenderAdapter.hostLayer`) as the bottom
/// sublayer of `contentHostView` ، BELOW the selection-chrome/guide
/// layers `MKCanvasViewController.viewDidLoad` already installs, so
/// selection handles/guides always paint on top of node content, never
/// under it.
struct CanvasHostView: UIViewControllerRepresentable {
    let viewModel: EditorViewModel
    let theme: any MKTheme

    func makeUIViewController(context: Context) -> MKCanvasViewController {
        let vc = MKCanvasViewController(session: viewModel.session, theme: theme)
        vc.loadViewIfNeeded()

        let hostLayer = viewModel.renderAdapter.hostLayer
        hostLayer.frame = vc.contentHostView.bounds
        vc.contentHostView.layer.insertSublayer(hostLayer, at: 0)

        viewModel.attach(canvasViewController: vc)
        DispatchQueue.main.async {
            vc.zoomToFit()
        }
        return vc
    }

    func updateUIViewController(_ vc: MKCanvasViewController, context: Context) {
        let hostLayer = viewModel.renderAdapter.hostLayer
        if hostLayer.frame != vc.contentHostView.bounds, vc.contentHostView.bounds.width > 0 {
            hostLayer.frame = vc.contentHostView.bounds
        }
        viewModel.syncOverlay()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {}
}
