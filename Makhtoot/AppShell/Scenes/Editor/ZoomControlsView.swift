import MKCanvas
import MKDesignSystem
import MKFoundation
import SwiftUI

/// Zoom controls (packet's P4 toolbar-chrome scope: "zoom controls").
/// Drives the hosted `MKCanvasViewController.scrollView` directly ،
/// `MKCanvasViewController` already exposes `zoomToFit()`/`zoomTo100Percent()`
/// plus the underlying `UIScrollView` for step in/out.
struct ZoomControlsView: View {
    @Environment(\.mkTheme) private var theme
    let viewModel: EditorViewModel

    private var zoomScale: CGFloat {
        viewModel.currentZoomScale
    }

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            MKToolbarButton(systemImage: "minus.magnifyingglass", accessibilityLabel: zoomOutLabel) {
                step(by: 0.8)
            }
            // UX-8: VoiceOver could already operate this control (via its
            // accessibilityLabel) but never learned the resulting zoom
            // level. `percentageText` below is already Arabic-Indic
            // formatted (`MKRTLUtilities.toArabicIndicDigits`) ، the same
            // string the visible `Text` badge renders, just also exposed
            // as this button's `accessibilityValue`.
            .accessibilityValue(percentageText)
            Text(percentageText)
                .mkTypeStyle(theme.typeRamp.style(for: .mono))
                .foregroundStyle(theme.inkMuted)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard let vc = viewModel.canvasViewController else {
                        #if DEBUG
                        // P1.1: distinguishes "tap lost" (this view never
                        // received the gesture) from "tap landed, no-op"
                        // (`canvasViewController` is legitimately nil during
                        // the brief window before `EditorViewModel.attach`
                        // runs). `step(by:)` below carries the identical
                        // guard/log for the same reason.
                        MKLog.app.debug("ZoomControlsView: percentage-badge tap landed with canvasViewController == nil")
                        #endif
                        return
                    }
                    vc.zoomTo100Percent()
                }
            MKToolbarButton(systemImage: "plus.magnifyingglass", accessibilityLabel: zoomInLabel) {
                step(by: 1.25)
            }
            .accessibilityValue(percentageText)
            MKToolbarButton(systemImage: "arrow.up.left.and.arrow.down.right", accessibilityLabel: zoomFitLabel) {
                guard let vc = viewModel.canvasViewController else {
                    #if DEBUG
                    MKLog.app.debug("ZoomControlsView: zoomToFit tap landed with canvasViewController == nil")
                    #endif
                    return
                }
                vc.zoomToFit()
            }
        }
        // P1.2/P1.3 (Bug 7): this bar applied NONE of the shared floating-
        // chrome before ، bare `theme.ink` glyphs drawn straight onto the
        // canvas backdrop, illegible over busy artwork, and in compact
        // layout sitting directly above the tool-rail pill with no visual
        // separation. `usesMaterial: true` because this is the one small,
        // low-content bar in the editor (4 controls, no scroll/menu
        // content) ، `.ultraThinMaterial` reads well here and is cheap
        // enough over a live canvas at this size; the larger bars
        // (`ToolRailView`/`ArrangeToolbarView`/`PathEditToolbarView`, the
        // two popovers) keep the opaque `theme.surface` fill instead, per
        // `MKFloatingBarModifier`'s own doc comment on why.
        .mkFloatingBar(usesMaterial: true)
    }

    private func step(by factor: CGFloat) {
        guard let scrollView = viewModel.canvasViewController?.scrollView else {
            #if DEBUG
            // P1.1: `canvasViewController` is `weak` and briefly nil before
            // `EditorViewModel.attach(canvasViewController:)` runs ، this
            // log distinguishes that legitimate no-op window from a genuine
            // "tap lost" (gesture never reached this closure at all, e.g.
            // swallowed by the enclosing `ScrollView`'s touch delay).
            MKLog.app.debug("ZoomControlsView: step(by:) tap landed with canvasViewController == nil")
            #endif
            return
        }
        let target = max(MKCanvasViewController.minimumZoom, min(scrollView.zoomScale * factor, MKCanvasViewController.maximumZoom))
        scrollView.setZoomScale(target, animated: true)
    }

    private var percentageText: String {
        let percent = Int((zoomScale * 100).rounded())
        return MKRTLUtilities.toArabicIndicDigits("\(percent)%")
    }

    // UX-7: catalog-extractable accessibility labels ، feeds
    // `MKToolbarButton`'s `LocalizedStringResource` initializer.
    private var zoomOutLabel: LocalizedStringResource {
        // Latin gloss: zoom out
        "تصغير"
    }
    private var zoomInLabel: LocalizedStringResource {
        // Latin gloss: zoom in
        "تكبير"
    }
    private var zoomFitLabel: LocalizedStringResource {
        // Latin gloss: fit to screen
        "ملائمة للشاشة"
    }
}
