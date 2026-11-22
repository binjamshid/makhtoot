import CoreGraphics
import Foundation
import MKDesignSystem
import MKFoundation
import MKModel
import MKPersistence
import QuartzCore
import Testing
@testable import MKCanvas

#if canImport(UIKit)
import UIKit
#endif

// P-2 (AUDIT_2026-07-28.md): "The zoom poll is replaceable with the
// `scrollViewDidZoom`/`scrollViewDidScroll` delegate callbacks
// `MKCanvasViewController` already implements... the header comment
// rejects KVO for Swift 6 strict-concurrency reasons, which don't apply to
// a plain `@MainActor` delegate method." This suite regression-locks the
// viewport callbacks from Wave 2 work item 2.1: `onViewportChanged`
// firing from BOTH the existing `scrollViewDidZoom(_:)` and the newly-
// implemented `scrollViewDidScroll(_:)`.
//
// UIKit-only: `MKCanvasViewController` is entirely `#if canImport(UIKit)`-
// gated in its own source file and so does not exist under a plain macOS
// `swift build`/`swift test` host at all (same acknowledged environment
// limitation `MKCanvasHapticsTests.swift`'s own `GestureCoordinator` block
// already documents for this target). This suite therefore does not run as
// part of this repo's `swift test --no-parallel` gate — it exists so the
// contract is still verified under a real iOS `xcodebuild test` run.
#if canImport(UIKit)
@MainActor
@Suite("MKCanvasViewController.onViewportChanged (P-2)")
struct MKCanvasViewControllerViewportCallbackTests {
    private func makeViewController() throws -> MKCanvasViewController {
        let session = try CanvasTestSupport.makeSession()
        let vc = MKCanvasViewController(session: session, theme: HibrTheme.default)
        vc.loadViewIfNeeded()
        return vc
    }

    @Test func onViewportChangedFiresFromScrollViewDidZoom() throws {
        let vc = try makeViewController()
        var fireCount = 0
        vc.onViewportChanged = { _, _ in fireCount += 1 }

        vc.scrollViewDidZoom(vc.scrollView)

        #expect(fireCount == 1)
    }

    @Test func onViewportChangedFiresFromScrollViewDidScroll() throws {
        let vc = try makeViewController()
        var fireCount = 0
        vc.onViewportChanged = { _, _ in fireCount += 1 }

        vc.scrollViewDidScroll(vc.scrollView)

        #expect(fireCount == 1)
    }

    @Test func onViewportChangedFiresIndependentlyFromBothCallbacks() throws {
        let vc = try makeViewController()
        var fireCount = 0
        vc.onViewportChanged = { _, _ in fireCount += 1 }

        // A pure pan (scroll, no zoom change) and a zoom are two distinct
        // real `UIScrollViewDelegate` events ، both must reach the
        // callback, unlike the old 150 ms poll which only ever sampled
        // `zoomScale` and therefore never reacted to a pan alone.
        vc.scrollViewDidScroll(vc.scrollView)
        vc.scrollViewDidZoom(vc.scrollView)
        vc.scrollViewDidScroll(vc.scrollView)

        #expect(fireCount == 3)
    }

    @Test func onViewportChangedReportsTheLiveZoomScale() throws {
        let vc = try makeViewController()
        vc.scrollView.zoomScale = 2.5
        var reportedZoomScale: CGFloat?
        vc.onViewportChanged = { _, zoomScale in reportedZoomScale = zoomScale }

        vc.scrollViewDidZoom(vc.scrollView)

        #expect(reportedZoomScale == 2.5)
    }

    @Test func onViewportChangedReportsScrollViewBoundsUnconverted() throws {
        // P-3's own fix lives at the call site (`EditorViewModel.attach
        // (canvasViewController:)`), which converts this rect via
        // `scrollView.convert(scrollView.bounds, to: contentHostView)`
        // before use ، this controller's own contract is simply to hand
        // over `scrollView.bounds` as-is, matching what a plain
        // `UIScrollViewDelegate` callback naturally has on hand.
        let vc = try makeViewController()
        vc.scrollView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        var reportedRect: CGRect?
        vc.onViewportChanged = { rect, _ in reportedRect = rect }

        vc.scrollViewDidScroll(vc.scrollView)

        #expect(reportedRect == vc.scrollView.bounds)
    }
}
#endif

// MARK: - UX-3: SelectionChromeLayer Differentiate Without Color
//
// Cross-platform: unlike `MKCanvasViewController` above, `SelectionChromeLayer`
// has no UIKit dependency of its own (that type's own file header: "this
// file has no `#if canImport(UIKit)` guard and builds on both platform
// declarations") ، so this suite runs under a plain `swift test --no-parallel`
// on the macOS host, same as everything else in this target that isn't
// gated to `MKCanvasViewController`/`GestureCoordinator` specifically.

@MainActor
@Suite("SelectionChromeLayer Differentiate Without Color (UX-3)")
struct SelectionChromeLayerDifferentiateWithoutColorTests {
    private static let sampleOBB = MKOrientedRect(center: CGPoint(x: 50, y: 50), size: CGSize(width: 100, height: 60), rotation: 0)

    @Test func defaultRenderingHasNoDashPattern() {
        let layer = SelectionChromeLayer()
        #expect(layer.differentiateWithoutColor == false)

        layer.update(obbs: [Self.sampleOBB], handleAnchor: Self.sampleOBB, zoomScale: 1)

        let outline = layer.containerLayer.sublayers?.first as? CAShapeLayer
        #expect(outline?.lineDashPattern == nil)
    }

    @Test func differentiateWithoutColorAddsANonDefaultDashPattern() {
        let layer = SelectionChromeLayer()
        layer.differentiateWithoutColor = true

        layer.update(obbs: [Self.sampleOBB], handleAnchor: Self.sampleOBB, zoomScale: 1)

        let outline = layer.containerLayer.sublayers?.first as? CAShapeLayer
        #expect(outline?.lineDashPattern != nil)
        #expect(outline?.lineDashPattern?.isEmpty == false)
    }

    @Test func togglingDifferentiateWithoutColorAfterAlreadyDrawnOutlinesUpdatesThemInPlace() {
        let layer = SelectionChromeLayer()
        layer.update(obbs: [Self.sampleOBB], handleAnchor: Self.sampleOBB, zoomScale: 1)
        let outline = layer.containerLayer.sublayers?.first as? CAShapeLayer
        #expect(outline?.lineDashPattern == nil)

        layer.differentiateWithoutColor = true
        #expect(outline?.lineDashPattern != nil)

        layer.differentiateWithoutColor = false
        #expect(outline?.lineDashPattern == nil)
    }
}
