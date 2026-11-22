#if canImport(UIKit)
import MKDesignSystem
import MKFoundation
import MKModel
import UIKit

// WS-06 packet §5 task 1 / ARCHITECTURE §10.1: "UIScrollView with content
// view sized to canvas + margin, zoom 0.1×–64×, `viewForZooming`, double-
// tap zoom-to-fit/100 %, backdrop from theme `canvasBackdrop`. RTL note:
// canvas coordinates are geometric (LTR math space); only chrome/panels
// mirror."
///
/// The content-layer tree (one `CALayer` per top-level node, D-114) is
/// WS-07's render-tree responsibility, wired in via `contentHostView`
/// once a real `MKCanvasGeometrySource`/`MKCanvasRenderBridge` conformer
/// exists ، this controller owns the scroll/zoom/backdrop/chrome
/// scaffolding and the gesture/selection/overlay wiring, per the packet's
/// "you own priority/policy" split.
@MainActor
public final class MKCanvasViewController: UIViewController, UIScrollViewDelegate {
    public let session: CanvasSession
    private let theme: any MKTheme

    public let scrollView = UIScrollView()
    /// The content view WS-07's render tree adds its per-node `CALayer`s
    /// to. Sized to the document canvas (task 1: "content view sized to
    /// canvas + margin").
    public let contentHostView = UIView()

    public let selectionChrome = SelectionChromeLayer()
    public let pathEditChrome = PathEditChromeLayer()
    public let guideRenderer = GuideRenderer()
    /// P5.5: a SECOND `GuideRenderer` instance (not a new rendering
    /// primitive) drawing the always-on-request grid (`MKGridLines`)
    /// through the same hairline-`CAShapeLayer` mechanism `guideRenderer`
    /// already uses for live snap guides ، styled distinctly (fainter,
    /// muted color) and added BELOW `guideRenderer`/the selection chrome
    /// in `contentHostView.layer`'s sublayer order so live snap guides and
    /// the selection outline always draw on top of it.
    public let gridRenderer = GuideRenderer()

    private var gestureCoordinator: GestureCoordinator?
    private var preKeyboardBottomInset: CGFloat = 0
    private var isKeyboardVisible = false

    /// P2.5/Bug 5 remedy 1: the D-104 text-edit overlay currently on
    /// screen, if any ، set/cleared by the app layer (`EditorViewModel`,
    /// which owns presenting/dismissing the overlay) around its own
    /// `presentOverlay`/teardown calls. `weak` since this controller does
    /// not own the overlay's lifetime, mirroring `arrangeInteraction`/
    /// `pathTextInteraction`'s own injected, not-owned pattern above.
    /// Read by `overlayDismissTapRecognizer` (tap-outside-commits) and by
    /// `keyboardWillShow(_:)` (Bug 6 remedy 1: scrolls the overlay's frame
    /// into view above the keyboard).
    public weak var activeTextOverlay: TextEditingOverlayView?

    /// P2.5/Bug 5 remedy 1: tap-outside-the-overlay dismissal. Installed on
    /// `view` (the top-level view, ABOVE `scrollView`/`contentHostView`) so
    /// it sees every tap on screen, including ones that land outside the
    /// canvas entirely (the backdrop). `require(toFail:)` against
    /// `GestureCoordinator.doubleTapRecognizer` so double-tap-to-edit is
    /// never swallowed by this recognizer resolving first ، deliberately
    /// NOT required-to-fail against the single-tap object-selection
    /// recognizer: a tap elsewhere on the canvas is BOTH "commit the
    /// overlay" AND "select whatever's there," and both should happen.
    private lazy var overlayDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleOverlayDismissTap(_:)))

    /// Arrange Mode interaction (packet task 15) ، set by the app layer
    /// once `MKArrangeEngineProviding` is wired (mirrors how
    /// `session.geometrySource`/`.renderBridge` are injected post-`init`).
    /// Forwarded straight to the `GestureCoordinator` this controller owns.
    public var arrangeInteraction: MKArrangeInteractionModel? {
        didSet { gestureCoordinator?.arrangeInteraction = arrangeInteraction }
    }

    /// Path-Edit Mode interaction (packet task 16) ، set by the app layer
    /// once `MKPathTextEngineProviding` is wired (mirrors
    /// `arrangeInteraction`'s exact injection pattern above). Forwarded
    /// straight to the `GestureCoordinator` this controller owns; also the
    /// source `refreshSelectionChrome()` reads path-edit chrome state
    /// (targets/selected handle) from.
    public var pathTextInteraction: MKPathTextInteractionModel? {
        didSet { gestureCoordinator?.pathTextInteraction = pathTextInteraction }
    }

    /// R-6.11: forwarded from `GestureCoordinator.onArrangedNodeDoubleTapped`
    /// so the app layer can present the choice sheet without reaching into
    /// this controller's private gesture-coordinator instance.
    public var onArrangedNodeDoubleTapped: ((MKNodeID) -> Void)? {
        didSet { gestureCoordinator?.onArrangedNodeDoubleTapped = onArrangedNodeDoubleTapped }
    }

    /// P-2 (AUDIT_2026-07-28.md): fired from BOTH `scrollViewDidZoom(_:)`
    /// and `scrollViewDidScroll(_:)` below ، real `UIScrollViewDelegate`
    /// callbacks, not a poll ، so the app layer (`EditorViewModel`) can
    /// react to every genuine viewport change (pan AND zoom) as it
    /// happens, replacing the 150 ms zoom-bucket poll the audit calls out.
    /// The header comment that poll left behind rejected KVO for Swift 6
    /// strict-concurrency reasons; those reasons don't apply to a plain
    /// `@MainActor` delegate method, which is what this already is.
    ///
    /// The `CGRect` handed over is `scrollView.bounds` AS-IS (`scrollView`'s
    /// own coordinate space: offset by `contentOffset`, scaled by
    /// `zoomScale`) ، NOT pre-converted into `contentHostView` space. A
    /// caller that needs canvas-point coordinates (P-3:
    /// `MKLayerTreeController.setVisibleRect` does) must convert it via
    /// `scrollView.convert(scrollView.bounds, to: contentHostView)` itself
    /// ، exactly the bug P-3 fixes at its one production call site
    /// (`EditorViewModel.attach(canvasViewController:)`).
    public var onViewportChanged: ((CGRect, CGFloat) -> Void)?

    /// Zoom bounds (packet task 1: "zoom 0.1×–64×"). ARCHITECTURE §10.1's
    /// "2.5%–6400%" is the same range expressed as a percentage ، kept
    /// consistent here rather than re-deriving.
    public static let minimumZoom: CGFloat = 0.1
    public static let maximumZoom: CGFloat = 64

    public init(session: CanvasSession, theme: any MKTheme) {
        self.session = session
        self.theme = theme
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(theme.canvasBackdrop)

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.delegate = self
        scrollView.minimumZoomScale = Self.minimumZoom
        scrollView.maximumZoomScale = Self.maximumZoom
        scrollView.backgroundColor = UIColor(theme.canvasBackdrop)
        view.addSubview(scrollView)

        let canvasSize = session.scene.canvas.size
        contentHostView.frame = CGRect(origin: .zero, size: canvasSize)
        contentHostView.backgroundColor = .clear
        // P5.5: `gridRenderer` added FIRST among the chrome overlays so it
        // sits below the selection/path-edit/snap-guide layers added right
        // after it (CALayer sublayer order: earlier `addSublayer` calls sit
        // further back).
        contentHostView.layer.addSublayer(gridRenderer.containerLayer)
        contentHostView.layer.addSublayer(selectionChrome.containerLayer)
        contentHostView.layer.addSublayer(pathEditChrome.containerLayer)
        contentHostView.layer.addSublayer(guideRenderer.containerLayer)
        scrollView.addSubview(contentHostView)
        scrollView.contentSize = canvasSize

        selectionChrome.strokeColor = UIColor(theme.selectionStroke).cgColor
        selectionChrome.handleFillColor = UIColor(theme.surface).cgColor
        // UX-3 (AUDIT_2026-07-28.md): "Canvas selection state is conveyed
        // by accent colour alone." `SelectionChromeLayer` has no UIKit
        // dependency of its own (deliberately headless-testable), so the
        // live system flag is read HERE (this controller is already
        // `#if canImport(UIKit)`-gated and `@MainActor`) and threaded in
        // as plain data, same injection shape `strokeColor`/
        // `handleFillColor` just above already use.
        selectionChrome.differentiateWithoutColor = UIAccessibility.shouldDifferentiateWithoutColor
        // Same theme-injection mechanism as `selectionChrome` above:
        // guide/connector strokes share the selection stroke color, dots
        // fill with the elevated background, and the selected handle
        // highlights in the accent (the same accent `guideRenderer`
        // already claims for its own guide chrome).
        pathEditChrome.strokeColor = UIColor(theme.selectionStroke).cgColor
        pathEditChrome.dotFillColor = UIColor(theme.surface).cgColor
        pathEditChrome.highlightColor = UIColor(theme.primary).cgColor
        guideRenderer.color = UIColor(theme.primary).cgColor
        // P5.5: faint, muted ، a permanent reference grid must read as
        // quiet chrome, not compete with the accent-colored live snap
        // guides it sits behind.
        gridRenderer.color = UIColor(theme.inkMuted).withAlphaComponent(0.25).cgColor

        let coordinator = GestureCoordinator(session: session, hostView: contentHostView)
        coordinator.zoomScaleProvider = { [weak self] in self?.scrollView.zoomScale ?? 1 }
        coordinator.onSelectionChromeNeedsUpdate = { [weak self] in self?.refreshSelectionChrome() }
        coordinator.arrangeInteraction = arrangeInteraction
        coordinator.pathTextInteraction = pathTextInteraction
        coordinator.onArrangedNodeDoubleTapped = onArrangedNodeDoubleTapped
        gestureCoordinator = coordinator

        overlayDismissTapRecognizer.require(toFail: coordinator.doubleTapRecognizer)
        // Pure observer: never cancels touches, so it can never interfere
        // with selection taps, pans, or handle drags happening underneath it.
        overlayDismissTapRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(overlayDismissTapRecognizer)

        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )

        centerContentIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        centerContentIfNeeded()
    }

    /// Content-inset centering for small canvases (task 1 accept: "content
    /// inset centers small canvases").
    private func centerContentIfNeeded() {
        let boundsSize = scrollView.bounds.size
        let contentSize = scrollView.contentSize
        let horizontalInset = max(0, (boundsSize.width - contentSize.width) / 2)
        let verticalInset = max(0, (boundsSize.height - contentSize.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
        else { return }

        let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
        let overlap = max(0, scrollView.frame.maxY - keyboardFrameInView.minY)

        if !isKeyboardVisible {
            preKeyboardBottomInset = scrollView.contentInset.bottom
            isKeyboardVisible = true
        }

        // Bug 6 remedy 1: an inset change alone never MOVES existing
        // content ، without this, the overlay (and everything else already
        // on screen) can sit entirely behind the keyboard until the user
        // manually scrolls. `overlay.frame` is in `contentHostView`
        // (canvas/zoom) space, so it's converted into `scrollView`'s own
        // coordinate space (`scrollRectToVisible`'s contract) rather than
        // hand-scaled by the zoom factor ، `convert(_:to:)` already folds
        // in whatever zoom transform `viewForZooming` currently has.
        let overlayRectInScrollView: CGRect? = activeTextOverlay.map { overlay in
            overlay.superview?.convert(overlay.frame, to: scrollView) ?? overlay.frame
        }

        let animator = UIViewPropertyAnimator(duration: duration, curve: UIView.AnimationCurve(rawValue: curveValue) ?? .easeInOut) { [weak self] in
            guard let self else { return }
            self.scrollView.contentInset.bottom = self.preKeyboardBottomInset + overlap
            self.scrollView.verticalScrollIndicatorInsets.bottom = overlap
            if let overlayRectInScrollView {
                self.scrollView.scrollRectToVisible(overlayRectInScrollView, animated: false)
            }
        }
        animator.startAnimation()
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
        else { return }

        isKeyboardVisible = false
        let savedInset = preKeyboardBottomInset

        let animator = UIViewPropertyAnimator(duration: duration, curve: UIView.AnimationCurve(rawValue: curveValue) ?? .easeInOut) { [weak self] in
            guard let self else { return }
            self.scrollView.contentInset.bottom = savedInset
            self.scrollView.verticalScrollIndicatorInsets.bottom = 0
        }
        animator.startAnimation()
    }

    /// P2.5/Bug 5 remedy 1's action: commits the active overlay whenever a
    /// tap lands anywhere on `view` OUTSIDE the overlay's own bounds ،
    /// `location(in:)` resolves through the overlay's ancestor transforms
    /// (including the zoom scale `contentHostView` carries), so this stays
    /// correct at any zoom level without any manual scale math.
    @objc private func handleOverlayDismissTap(_ recognizer: UITapGestureRecognizer) {
        guard let overlay = activeTextOverlay else { return }
        let pointInOverlay = recognizer.location(in: overlay)
        guard !overlay.bounds.contains(pointInOverlay) else { return }
        // §4.8: don't yank an in-progress IME composition out from under
        // the user just because a stray tap landed elsewhere ، same
        // marked-text guard `TextEditingOverlayView.handleToolbarSwipeDown`
        // applies to its own dismissal trigger, for the same reason.
        guard overlay.textView.markedTextRange == nil else { return }
        overlay.commit()
    }

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? { contentHostView }

    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContentIfNeeded()
        refreshSelectionChrome()
        onViewportChanged?(scrollView.bounds, scrollView.zoomScale)
    }

    /// P-2: not implemented before this fix ، `UIScrollViewDelegate`
    /// conformance existed only for `viewForZooming`/`scrollViewDidZoom`
    /// above, so a plain PAN (a scroll with no zoom change) never notified
    /// anyone. This is the other half of "delegate callback instead of a
    /// poll": every genuine scroll, zoom or not, now reaches
    /// `onViewportChanged`.
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onViewportChanged?(scrollView.bounds, scrollView.zoomScale)
    }

    /// Double-tap-to-zoom (task 1: "double-tap zoom-to-fit/100 %") toggles
    /// between fit-to-view and 100 %.
    public func zoomToFit() {
        let canvasSize = session.scene.canvas.size
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
        let fitScale = min(scrollView.bounds.width / canvasSize.width, scrollView.bounds.height / canvasSize.height)
        scrollView.setZoomScale(max(Self.minimumZoom, min(fitScale, Self.maximumZoom)), animated: true)
    }

    public func zoomTo100Percent() {
        scrollView.setZoomScale(1, animated: true)
    }

    /// P5.5: shows/hides the always-on-request reference grid per
    /// `session.showsGrid`, re-quantizing hairline width for the current
    /// zoom (same `GuideRenderer.update(guides:zoomScale:)` mechanism live
    /// snap guides already use). Screen-only ، `MKGridLines` has no
    /// `MKRender`/`MKExport` caller anywhere, so a grid can never appear in
    /// an exported bitmap or file by construction.
    private func refreshGrid() {
        guard session.showsGrid else {
            gridRenderer.clear()
            return
        }
        gridRenderer.update(guides: MKGridLines.guides(canvasSize: session.scene.canvas.size), zoomScale: scrollView.zoomScale)
    }

    /// P5.4 (§2.11): shows the checkerboard behind `contentHostView`'s
    /// entire sublayer stack whenever the canvas background would let
    /// transparency show through ، background node hidden (`SceneRenderer
    /// .render` skips drawing it entirely in that case) or a `.solid`
    /// color whose alpha is `< 1`. `.image` backgrounds are treated as
    /// opaque here (photo assets normally have no alpha channel worth
    /// honoring, and `MKAssetProviding`'s synchronous contract gives this
    /// UIKit-only chrome layer no cheap way to inspect a resolved
    /// `CGImage`'s alpha channel without decoding it) ، documented
    /// simplification, not an oversight.
    private func refreshCheckerboard() {
        contentHostView.layer.backgroundColor = isBackgroundTransparent ? Self.checkerboardColor.cgColor : nil
    }

    private static let checkerboardColor = MKCheckerboardPattern.patternColor()

    private var isBackgroundTransparent: Bool {
        let background = session.scene.background
        if background.core.isHidden { return true }
        if case .solid(let color) = background.content { return color.a < 1 }
        return false
    }

    private func refreshSelectionChrome() {
        refreshGrid()
        refreshCheckerboard()
        refreshPathEditChrome()
        guard let geometrySource = session.geometrySource else {
            selectionChrome.clear()
            return
        }
        // Arrange Mode (packet task 15): `session.selection.ids` are
        // arranged-CHILD ids (glyph/mark/ligature) scoped to
        // `compositionScope`, not top-level scene node ids ، `worldOBB`
        // would find nothing for them (same reason
        // `CanvasSession.setArrangeChildSelection` exists as a dedicated
        // path). Route through `arrangedChildWorldOBB` instead whenever a
        // composition scope is active.
        let obbs: [MKOrientedRect]
        if let ownerID = session.selection.compositionScope {
            obbs = session.selection.ids.compactMap { geometrySource.arrangedChildWorldOBB(childID: $0, ownerNodeID: ownerID, in: session.scene) }
        } else {
            obbs = session.selection.ids.compactMap { geometrySource.worldOBB(for: $0, in: session.scene) }
        }
        let anchor: MKOrientedRect?
        if session.selection.isMultiple, let bounds = MKOrientedRect.unionBounds(of: obbs) {
            anchor = MKOrientedRect(center: CGPoint(x: bounds.midX, y: bounds.midY), size: bounds.size, rotation: 0)
        } else {
            anchor = obbs.first
        }
        selectionChrome.update(obbs: obbs, handleAnchor: anchor, zoomScale: scrollView.zoomScale)
    }

    /// Path-Edit Mode chrome (packet task 16): while `session.mode` is
    /// `.pathEdit(nodeID:)` and the interaction model is wired, renders
    /// the live path guide + anchor/handle dots in content-view space
    /// (zoom/pan tracking automatic, same as selection chrome); hidden/
    /// emptied otherwise ، `nil`-safe throughout, mirroring every other
    /// injected-dependency guard in this controller. Refreshed from the
    /// same `refreshSelectionChrome()` funnel the gesture coordinator and
    /// zoom delegate already drive, so path edits/drags/zoom all update it
    /// with zero extra wiring.
    private func refreshPathEditChrome() {
        guard case .pathEdit(let nodeID) = session.mode,
              let pathTextInteraction,
              case .pathText(let node)? = session.scene.node(id: nodeID)
        else {
            pathEditChrome.clear()
            return
        }
        pathEditChrome.update(
            guidePath: PathEditChromeGeometry.guidePath(node.path, transform: node.core.transform),
            targets: pathTextInteraction.currentHitTargets(),
            selected: pathTextInteraction.selectedHandle,
            zoomScale: scrollView.zoomScale)
    }
}
#endif
