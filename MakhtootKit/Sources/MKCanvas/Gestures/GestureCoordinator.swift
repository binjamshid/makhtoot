#if canImport(UIKit)
import CoreGraphics
import MKFoundation
import MKModel
import os
import UIKit

// WS-06 packet §5 task 1/5/6/7, ARCHITECTURE §10.2: "`MKGestureRouter` owns
// one tap, one double-tap, one pan, one pinch-rotate composite, and one
// long-press recognizer on the canvas, and resolves intent by phase." This
// is the UIKit-side glue: it owns the recognizers and dispatches into the
// pure logic already implemented in `CanvasSession`/`MoveGesture`/
// `HandleGestures`/`MarqueeController` ، no gesture MATH lives in this
// file, only phase routing, matching the packet's own scope split ("you
// own priority/policy... geometry/math already lives in the pure types").

/// UX-4 (AUDIT_2026-07-28.md): "zero hits for `UIImpactFeedbackGenerator`/
/// `UINotificationFeedbackGenerator`/`.sensoryFeedback` across the whole
/// codebase... in a canvas app the finger covers the object being
/// manipulated, which makes haptics the primary confirmation channel."
/// Abstracted behind this protocol (rather than `GestureCoordinator`
/// referencing `UISelectionFeedbackGenerator` directly) purely so
/// `MKCanvasHapticsTests` can substitute a spy and assert fire-COUNT
/// (never firing more than once per actual selection change, e.g. NOT once
/// per frame of an unrelated move/resize/rotate drag) without a live
/// haptics engine or a real device/simulator.
public protocol MKSelectionFeedbackGenerating: AnyObject {
    func selectionChanged()
}
extension UISelectionFeedbackGenerator: @MainActor MKSelectionFeedbackGenerating {}

@MainActor
public final class GestureCoordinator: NSObject {
    public weak var session: CanvasSession?
    public weak var hostView: UIView?
    public var zoomScaleProvider: () -> CGFloat = { 1 }
    public var onSelectionChromeNeedsUpdate: (() -> Void)?

    /// UX-4: injectable so tests can substitute a spy (see
    /// `MKSelectionFeedbackGenerating`'s own doc comment above). Defaults
    /// to a real `UISelectionFeedbackGenerator` in production.
    public var selectionFeedbackGenerator: any MKSelectionFeedbackGenerating = UISelectionFeedbackGenerator()
    /// The selection set as of the last `notifySelectionChromeNeedsUpdate()`
    /// call, so that call can detect a genuine change and fire the haptic
    /// exactly once per change rather than once per `onSelectionChromeNeedsUpdate`
    /// call site (several of which fire every frame of an in-progress
    /// move/resize/rotate/marquee drag, none of which is itself a
    /// "selection changed" event unless the marquee sweeps a NEW node in
    /// or out).
    private var lastKnownSelectionIDs: Set<MKNodeID> = []

    /// Arrange Mode interaction (packet task 15) ، injected by the app
    /// layer (mirrors `session.geometrySource`/`.renderBridge`'s own
    /// injection pattern). `nil`-safe throughout: every routing branch
    /// below falls back to ordinary object-level gesture handling when
    /// either this is unset or `session.mode` is not `.arrange`.
    public weak var arrangeInteraction: MKArrangeInteractionModel?

    /// Path-Edit Mode interaction (packet task 16) ، injected by the app
    /// layer, same pattern as `arrangeInteraction` above. `nil`-safe
    /// throughout: every routing branch below falls back to ordinary
    /// object-level gesture handling when either this is unset or
    /// `session.mode` is not `.pathEdit`.
    public weak var pathTextInteraction: MKPathTextInteractionModel?

    private let moveGesture = MoveGesture()
    private let handleGesture = HandleGestures()
    private var marqueeStart: CGPoint?
    private var activeHandleRole: MKHandleRole?
    private var isRotating = false
    private var panStartPoint: CGPoint = .zero
    /// `true` while a pan is driving `arrangeInteraction`'s child-move
    /// primitive rather than `moveGesture`'s top-level-node primitive.
    private var isDraggingArrangedChild = false
    /// What kind of path-edit-mode drag is in progress (task 16's own
    /// priority order ، see `handlePathEditPan`'s doc comment), or `nil`
    /// outside a path-edit drag.
    private enum PathEditDragKind { case handle(MKPathHandleID), glyph(MKPathGlyphOffsetKey) }
    private var pathEditDragKind: PathEditDragKind?
    private var lastPathEditPanPoint: CGPoint?
    /// ⌥/long-drag toggle (task 7: "⌥/long-drag toggles contain mode").
    public var marqueeContainModeEnabled = false

    public private(set) lazy var tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    public private(set) lazy var doubleTapRecognizer: UITapGestureRecognizer = {
        let r = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        r.numberOfTapsRequired = 2
        return r
    }()
    public private(set) lazy var panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
    public private(set) lazy var longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))

    public init(session: CanvasSession, hostView: UIView) {
        self.session = session
        self.hostView = hostView
        super.init()
        tapRecognizer.require(toFail: doubleTapRecognizer)
        [tapRecognizer, doubleTapRecognizer, panRecognizer, longPressRecognizer].forEach { hostView.addGestureRecognizer($0) }
        lastKnownSelectionIDs = session.selection.ids
    }

    /// UX-4: every call site below that used to invoke
    /// `onSelectionChromeNeedsUpdate?()` directly now routes through here
    /// instead, so the "selection changed" haptic and the chrome-refresh
    /// callback share one source of truth about what the selection just
    /// was. Fires `selectionFeedbackGenerator.selectionChanged()` only
    /// when `session.selection.ids` actually differs from the last time
    /// this ran, THEN always forwards to `onSelectionChromeNeedsUpdate`
    /// unconditionally (chrome still needs to redraw on every call, e.g.
    /// mid-drag frames where the selection itself hasn't changed).
    private func notifySelectionChromeNeedsUpdate() {
        if let session, session.selection.ids != lastKnownSelectionIDs {
            lastKnownSelectionIDs = session.selection.ids
            selectionFeedbackGenerator.selectionChanged()
        }
        onSelectionChromeNeedsUpdate?()
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let session, let hostView else { return }
        let point = recognizer.location(in: hostView)
        if case .arrange = session.mode, let arrangeInteraction {
            arrangeInteraction.tap(at: point, zoomScale: zoomScaleProvider())
        } else if case .pathEdit = session.mode, let pathTextInteraction {
            handlePathEditTap(at: point, pathTextInteraction: pathTextInteraction)
        } else {
            session.tap(at: point, zoomScale: zoomScaleProvider())
        }
        notifySelectionChromeNeedsUpdate()
    }

    /// Path-Edit Mode's own tap handling (task 16, R-9.1's "tap to add
    /// anchors"). Priority order (own design choice, documented per this
    /// packet's instructions): (1) an existing anchor/handle within
    /// tolerance ، select it for a subsequent drag, NEVER insert on top of
    /// one; (2) failing that, attempt an insert-on-curve ،
    /// `MKPathTextInteractionModel.insertAnchor(near:)` itself decides
    /// (via the app-layer engine, the only side that can run the
    /// arc-length LUT) whether `point` is close enough to the live path to
    /// count as an on-curve tap; an off-curve tap is silently a no-op,
    /// same "return nil when inapplicable" convention every other
    /// engine-backed mutation here already uses; (3) neither ، clears the
    /// handle selection (tap on empty canvas, mirroring `session.tap`'s
    /// own empty-tap-deselects behavior).
    private func handlePathEditTap(at point: CGPoint, pathTextInteraction: MKPathTextInteractionModel) {
        let tolerance = MKHitTestPolicy.touchTolerance(zoomScale: zoomScaleProvider())
        if pathTextInteraction.tap(at: point, tolerance: tolerance) != nil { return }
        try? pathTextInteraction.insertAnchor(near: point)
    }

    /// R-6.11's arrange-then-edit-source conflict: double-tapping an
    /// ALREADY-arranged composition (while in browse/object mode, not
    /// inside Arrange Mode itself) must NOT open the text overlay ، it
    /// signals the app layer to present the "تعديل النص يتطلب العودة إلى
    /// النص" choice sheet instead (presentation is UI/app-layer territory;
    /// this coordinator only resolves WHICH node was targeted, same split
    /// every other callback here already uses).
    public var onArrangedNodeDoubleTapped: ((MKNodeID) -> Void)?

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard let session, let hostView else { return }
        let point = recognizer.location(in: hostView)
        if case .arrange = session.mode {
            // Inside Arrange Mode itself, double-tap has no composition-
            // drill-in action of its own (R-6.9's tap-cycling already
            // reaches occluded children) ، swallow, do not fall through to
            // object-level double-tap handling.
            notifySelectionChromeNeedsUpdate()
            return
        }
        if case .pathEdit = session.mode, let pathTextInteraction {
            // Own design choice (task 16 leaves double-tap unassigned ،
            // "use your judgment, document the choice"): a pen-tool
            // double-tap conventionally closes/opens the current path, so
            // this toggles `BezierPathModel.isClosed` (task 10's
            // `PathEditModel.toggleClosed`, exposed at task 16's own
            // anchor-CRUD scope) rather than a second insert ، single tap
            // already owns insert-on-curve (`handlePathEditTap`).
            try? pathTextInteraction.toggleClosed()
            notifySelectionChromeNeedsUpdate()
            return
        }
        // ARCHITECTURE §10.2: double-tap on live/path text enters the D-104
        // overlay; double-tap on an `.arranged` composition routes through
        // R-6.11's choice sheet instead (never opens the overlay directly).
        if let hit = session.tap(at: point, zoomScale: zoomScaleProvider()),
           let node = session.scene.node(id: hit) {
            switch node {
            case .liveText, .pathText:
                session.beginEditingText(nodeID: hit)
            case .arranged:
                onArrangedNodeDoubleTapped?(hit)
            default:
                break
            }
        }
        notifySelectionChromeNeedsUpdate()
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let session, let hostView else { return }
        let point = recognizer.location(in: hostView)
        let zoomScale = zoomScaleProvider()

        if case .arrange = session.mode, let arrangeInteraction {
            handleArrangePan(recognizer, session: session, point: point, arrangeInteraction: arrangeInteraction)
            return
        }
        if case .pathEdit = session.mode, let pathTextInteraction {
            handlePathEditPan(recognizer, point: point, pathTextInteraction: pathTextInteraction)
            return
        }

        switch recognizer.state {
        case .began:
            activeHandleRole = nil
            isRotating = false
            panStartPoint = point
            // Check for handle hit first — resize/rotate handles are smaller
            // targets that sit at the edges of the selected node's OBB.
            if let geometrySource = session.geometrySource,
               let id = session.selection.single,
               let obb = geometrySource.worldOBB(for: id, in: session.scene),
               let role = MKSelectionHandleLayout.handle(at: point, on: obb, zoomScale: zoomScale) {
                // Nearest-handle, screen-constant 44 pt targets ، see
                // `MKSelectionHandleLayout.handle(at:on:zoomScale:)` and
                // `.grabRadiusScreenPoints` for what the old world-space
                // first-match loop got wrong.
                if role == .rotate {
                    isRotating = true
                    handleGesture.beginRotate(session: session, pointerStart: point)
                } else {
                    activeHandleRole = role
                    handleGesture.beginResize(session: session, handle: role)
                }
            }
#if DEBUG
            if activeHandleRole == nil, !isRotating, session.selection.single != nil {
                os_log(.debug, "GestureCoordinator: handle miss — single=%@ obb=%@", String(describing: session.selection.single), String(describing: session.geometrySource?.worldOBB(for: session.selection.single!, in: session.scene)))
            }
#endif
            // Fall through to move/marquee only if no handle was hit.
            if activeHandleRole == nil, !isRotating {
                if !session.selection.isEmpty, let candidates = session.geometrySource,
                   let id = session.selection.single ?? session.selection.ids.first,
                   candidates.worldOBB(for: id, in: session.scene)?.contains(point, tolerance: MKHitTestPolicy.touchTolerance(zoomScale: zoomScale)) == true {
                    moveGesture.begin(session: session, at: point)
                } else if let hit = MKHitTestPolicy.topHit(at: point, in: session.hitCandidates(), tolerance: MKHitTestPolicy.touchTolerance(zoomScale: zoomScale)) {
                    session.setSelection([hit])
                    moveGesture.begin(session: session, at: point)
                } else {
                    marqueeStart = point
                    session.setSelection([])
                }
            }
        case .changed:
            if let handle = activeHandleRole {
                let dx = point.x - panStartPoint.x
                let dy = point.y - panStartPoint.y
                let fromCenter = false
                let aspectLocked: Bool? = (handle.isCorner ? true : nil)
                handleGesture.updateResize(session: session, worldDelta: CGPoint(x: dx, y: dy), fromCenter: fromCenter, aspectLocked: aspectLocked)
            } else if isRotating {
                handleGesture.updateRotate(session: session, pointerCurrent: point, snapping: true)
            } else if moveGesture.isActive {
                moveGesture.update(session: session, to: point, zoomScale: zoomScale)
            } else if let start = marqueeStart {
                let rect = MKMarqueeController.rect(from: start, to: point)
                let mode: MKMarqueeMode = marqueeContainModeEnabled ? .contain : .intersect
                session.marqueeSelect(rect: rect, mode: mode)
            }
            notifySelectionChromeNeedsUpdate()
        case .ended, .cancelled, .failed:
            if activeHandleRole != nil {
                handleGesture.endResize(session: session)
                activeHandleRole = nil
            } else if isRotating {
                handleGesture.endRotate(session: session)
                isRotating = false
            } else if moveGesture.isActive {
                moveGesture.end(session: session)
            }
            marqueeStart = nil
            notifySelectionChromeNeedsUpdate()
        default:
            break
        }
    }

    /// Arrange Mode's own pan handling (task 15, R-6.5/R-7.4): pan on an
    /// already-selected arranged child drags it (glyph/mark move, same
    /// `nudgePositionCommand` primitive for both ، see
    /// `MKArrangeInteractionModel.updateMove`'s doc comment); pan starting
    /// on empty composition space re-taps to pick a new child under the
    /// finger first (so a drag can start directly on an unselected glyph,
    /// matching the object-level pan's own "select-then-drag" convenience).
    private var lastArrangePanPoint: CGPoint?
    private func handleArrangePan(_ recognizer: UIPanGestureRecognizer, session: CanvasSession, point: CGPoint, arrangeInteraction: MKArrangeInteractionModel) {
        switch recognizer.state {
        case .began:
            if session.selection.isEmpty {
                arrangeInteraction.tap(at: point, zoomScale: zoomScaleProvider())
            }
            if !session.selection.isEmpty {
                isDraggingArrangedChild = true
                lastArrangePanPoint = point
                arrangeInteraction.beginMove()
            }
        case .changed:
            // `point` (from `recognizer.location(in: hostView)`) is already
            // in the content view's own (canvas-space, zoom-independent)
            // coordinate system ، UIKit resolves the zoom transform when
            // reporting locations relative to the zoomed view itself, same
            // as `MoveGesture.update`'s own raw `point - startPoint` delta
            // (no zoom-scale division there either). The Y axis is negated
            // going into `updateMove`, though: canvas/document space is
            // y-DOWN, but `MKGlyphNode.transform.position` (what
            // `nudgePositionCommand` mutates) shares `layout.position`'s
            // composition-local y-UP convention (`ArrangeDeriver`'s
            // documented coordinate-convention note, mirrored by
            // `MKArrangedGeometry`'s `flip = CGAffineTransform(scaleX: 1,
            // y: -1)` compositionAffine) ، a documented simplification
            // assuming the owner `.arranged` node itself is unrotated (the
            // common case); a rotated owner would additionally need the
            // delta rotated by the owner's own inverse rotation first.
            guard isDraggingArrangedChild, let last = lastArrangePanPoint else { return }
            let delta = CGSize(width: point.x - last.x, height: -(point.y - last.y))
            lastArrangePanPoint = point
            arrangeInteraction.updateMove(byDelta: delta)
            notifySelectionChromeNeedsUpdate()
        case .ended, .cancelled, .failed:
            if isDraggingArrangedChild {
                arrangeInteraction.endMove()
            }
            isDraggingArrangedChild = false
            lastArrangePanPoint = nil
            notifySelectionChromeNeedsUpdate()
        default:
            break
        }
    }

    /// Path-Edit Mode's own pan handling (task 16: "drags routed to WS-05
    /// `PathEditModel` (coalesced)"). Priority order at drag-BEGIN (own
    /// design choice, documented per this packet's instructions): (1) an
    /// anchor/handle hit takes priority over a glyph-body hit, since
    /// reshaping the path is Path-Edit Mode's primary action and
    /// anchors/handles are the smaller, more precise targets ، a glyph
    /// sitting near a handle should never steal a drag meant for the
    /// handle; (2) failing that, a glyph hit begins a per-glyph offset
    /// drag (R-9.4); (3) neither ، the pan is not ours, left un-driven
    /// (no marquee/move fallback in this mode, matching Arrange Mode's own
    /// "pan on empty composition space" contract, which also does
    /// nothing further once its own re-tap comes up empty).
    private func handlePathEditPan(_ recognizer: UIPanGestureRecognizer, point: CGPoint, pathTextInteraction: MKPathTextInteractionModel) {
        switch recognizer.state {
        case .began:
            let tolerance = MKHitTestPolicy.touchTolerance(zoomScale: zoomScaleProvider())
            if let hit = pathTextInteraction.nearestHitTarget(at: point, tolerance: tolerance) {
                pathTextInteraction.beginHandleDrag(hit.id)
                pathEditDragKind = .handle(hit.id)
                lastPathEditPanPoint = point
            } else if let key = pathTextInteraction.beginGlyphOffsetDrag(at: point) {
                pathEditDragKind = .glyph(key)
                lastPathEditPanPoint = point
            }
        case .changed:
            guard let kind = pathEditDragKind else { return }
            switch kind {
            case .handle:
                // Absolute position, not a delta ، `updateHandleDrag`
                // tracks the finger 1:1 (see its own doc comment), so no
                // `lastPathEditPanPoint`/Y-flip bookkeeping is needed here
                // unlike the glyph-offset branch below.
                pathTextInteraction.updateHandleDrag(to: point)
            case .glyph:
                // Same y-DOWN(canvas)-vs-y-UP(composition-local) flip
                // `handleArrangePan`'s own `.changed` case documents in
                // detail ، per-glyph offsets share that same local-space
                // convention (`MKPathGlyphOffset.offset` is folded into
                // `PathLayoutEngine`'s composition-local placement, the
                // same space `MKArrangedGeometry`'s `compositionAffine`
                // flips), so the same negation applies here.
                guard let last = lastPathEditPanPoint else { return }
                let delta = CGSize(width: point.x - last.x, height: -(point.y - last.y))
                pathTextInteraction.updateGlyphOffsetDrag(byDelta: delta)
            }
            lastPathEditPanPoint = point
            notifySelectionChromeNeedsUpdate()
        case .ended, .cancelled, .failed:
            switch pathEditDragKind {
            case .handle: pathTextInteraction.endHandleDrag()
            case .glyph: pathTextInteraction.endGlyphOffsetDrag()
            case .none: break
            }
            pathEditDragKind = nil
            lastPathEditPanPoint = nil
            notifySelectionChromeNeedsUpdate()
        default:
            break
        }
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        // ARCHITECTURE §10.2: long-press → context menu (duplicate, lock,
        // hide, arrange, order). The actual `UIMenu` presentation is
        // editor-chrome (WS-13) territory ، this coordinator only
        // resolves WHICH node the long-press targeted.
        guard recognizer.state == .began, let session, let hostView else { return }
        let point = recognizer.location(in: hostView)
        if case .pathEdit = session.mode, let pathTextInteraction {
            // Own design choice (task 16 leaves long-press unassigned ،
            // "use your judgment, document the choice"): long-press
            // deletes the nearest ANCHOR (never a handle ، handles have no
            // independent delete semantics, `PathEditModel.deleteAnchor`
            // only ever operates on anchor ids) within tolerance. Mirrors
            // this recognizer's object-level role elsewhere in this file:
            // resolve the target, don't present destructive-op
            // confirmation chrome (WS-13 territory, same split the doc
            // comment above already states for the context-menu case).
            let tolerance = MKHitTestPolicy.touchTolerance(zoomScale: zoomScaleProvider())
            if let hit = pathTextInteraction.nearestHitTarget(at: point, tolerance: tolerance), hit.id.kind == .anchor {
                try? pathTextInteraction.deleteAnchor(hit.id.anchorID)
            }
            notifySelectionChromeNeedsUpdate()
            return
        }
        if let hit = MKHitTestPolicy.topHit(at: point, in: session.hitCandidates(), tolerance: MKHitTestPolicy.touchTolerance(zoomScale: zoomScaleProvider())) {
            session.setSelection([hit])
            notifySelectionChromeNeedsUpdate()
        }
    }

    /// Handle-drag entry point ، `MKCanvasViewController`'s selection
    /// chrome installs its own small per-handle pan recognizers (they need
    /// to know WHICH handle was grabbed, which only the chrome layer
    /// knows) and calls into this coordinator's `handleGesture` via these
    /// forwarding methods so gesture MATH still lives in one place.
    public func beginHandleResize(_ handle: MKHandleRole) {
        guard let session else { return }
        handleGesture.beginResize(session: session, handle: handle)
    }

    public func updateHandleResize(worldDelta: CGPoint, fromCenter: Bool, aspectLocked: Bool?) {
        guard let session else { return }
        handleGesture.updateResize(session: session, worldDelta: worldDelta, fromCenter: fromCenter, aspectLocked: aspectLocked)
        notifySelectionChromeNeedsUpdate()
    }

    public func endHandleResize() {
        guard let session else { return }
        handleGesture.endResize(session: session)
        notifySelectionChromeNeedsUpdate()
    }

    public func beginHandleRotate(pointerStart: CGPoint) {
        guard let session else { return }
        handleGesture.beginRotate(session: session, pointerStart: pointerStart)
    }

    public func updateHandleRotate(pointerCurrent: CGPoint, snapping: Bool) {
        guard let session else { return }
        handleGesture.updateRotate(session: session, pointerCurrent: pointerCurrent, snapping: snapping)
        notifySelectionChromeNeedsUpdate()
    }

    public func endHandleRotate() {
        guard let session else { return }
        handleGesture.endRotate(session: session)
        notifySelectionChromeNeedsUpdate()
    }
}
#endif
