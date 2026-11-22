import CoreGraphics
import Foundation
import QuartzCore

// WS-06 packet §5 task 4: "overlay CALayer drawing selection outlines
// (theme `selectionStroke`), multi-select union bounds + 8 resize handles +
// rotate handle above-top-center... handles scale-invariant (constant
// screen size across zoom)." `CALayer`/`CAShapeLayer` are QuartzCore, not
// UIKit ، this file has no `#if canImport(UIKit)` guard and builds on both
// platform declarations in `Package.swift`.

/// Pure geometry: world-space handle center points for `obb`, keyed by
/// role. Kept separate from the `CALayer`-driving code below so handle
/// PLACEMENT math is unit-testable without a live layer tree.
public enum MKSelectionHandleLayout {
    /// Screen-space (constant-size, zoom-independent) handle diameter ،
    /// ARCHITECTURE §10.4 "handles scale-invariant."
    public static let handleDiameter: CGFloat = 10

    /// Screen-space grab radius for a handle ، half of the 44 pt minimum
    /// touch target (`MKHitTestPolicy.minimumTouchTargetPoints`), so the
    /// tappable box is a full 44 × 44 points however small the drawn dot
    /// is. Callers convert to world units by dividing by the zoom scale.
    ///
    /// Bug fix (2026-07-29, user report: "text corner handles only move
    /// text but don't reliably resize it"). `GestureCoordinator` used to
    /// grab with `max(16, handleDiameter / zoomScale)` ، a WORLD-space
    /// radius, so the on-screen target shrank as you zoomed out (8 screen
    /// points at 0.5×) and was never bigger than 32 points even at 1×.
    /// Every near-miss fell straight through to the move branch, which is
    /// exactly "the handle drags the object instead of resizing it."
    public static let grabRadiusScreenPoints: CGFloat = MKHitTestPolicy.minimumTouchTargetPoints / 2

    /// World-space center point for `handle` on `obb` at `zoomScale`. The
    /// rotate knob sits `MKAnchoredResize.rotateKnobOffset` SCREEN points
    /// further out than the unit position implies (hence the
    /// `1/zoomScale`), along the OBB's own "up" direction ، i.e. still
    /// above-top-center in the node's ROTATED frame (task 4:
    /// "above-top-center (RTL-agnostic placement)").
    public static func worldPosition(of handle: MKHandleRole, on obb: MKOrientedRect, zoomScale: CGFloat = 1) -> CGPoint {
        let unit = handle.localUnitPosition
        var local = CGPoint(x: unit.x * obb.size.width, y: unit.y * obb.size.height)
        if handle == .rotate {
            local.y -= MKAnchoredResize.rotateKnobOffset / max(zoomScale, 0.0001)
        }
        return obb.localToWorld(local)
    }

    public static func allHandlePositions(on obb: MKOrientedRect, zoomScale: CGFloat = 1) -> [MKHandleRole: CGPoint] {
        Dictionary(uniqueKeysWithValues: MKHandleRole.allCases.map { ($0, worldPosition(of: $0, on: obb, zoomScale: zoomScale)) })
    }

    /// The handle a pointer at `point` grabbed, or `nil`.
    ///
    /// Deliberately NOT "first rect that contains the point": handle
    /// positions live in a `Dictionary`, whose iteration order is
    /// unspecified and varies run to run, so a first-match loop over
    /// overlapping targets resolved differently on different taps ، the
    /// other half of the user-reported "rotate handle doesn't work
    /// reliably". This picks the NEAREST handle instead (deterministic),
    /// with `.rotate` winning an exact tie so the knob stays reachable
    /// even where its box still grazes the top-center handle's.
    public static func handle(
        at point: CGPoint, on obb: MKOrientedRect, zoomScale: CGFloat
    ) -> MKHandleRole? {
        let grabRadius = grabRadiusScreenPoints / max(zoomScale, 0.0001)
        var best: (role: MKHandleRole, distance: CGFloat)?
        for role in MKHandleRole.allCases {
            let position = worldPosition(of: role, on: obb, zoomScale: zoomScale)
            let distance = hypot(point.x - position.x, point.y - position.y)
            guard distance <= grabRadius else { continue }
            guard let current = best else { best = (role, distance); continue }
            if distance < current.distance || (distance == current.distance && role == .rotate) {
                best = (role, distance)
            }
        }
        return best?.role
    }
}

/// Drives the actual `CALayer` tree for selection chrome: one outline
/// layer per OBB, one dot layer per handle. Handle sizes are compensated
/// by `1 / zoomScale` at `update(...)` time so they read as a constant
/// SCREEN size regardless of canvas zoom (ARCHITECTURE §10.4).
@MainActor
public final class SelectionChromeLayer {
    public let containerLayer = CALayer()
    private var outlineLayers: [CAShapeLayer] = []
    private var handleLayers: [CAShapeLayer] = []

    public var strokeColor: CGColor = CGColor(gray: 0, alpha: 1) {
        didSet { applyColors() }
    }
    public var handleFillColor: CGColor = CGColor(gray: 1, alpha: 1) {
        didSet { applyColors() }
    }

    /// UX-3 (AUDIT_2026-07-28.md): "Canvas selection state is conveyed by
    /// accent colour alone." This type has no UIKit dependency of its own
    /// (file header: "builds on both platform declarations") ، so, exactly
    /// like `strokeColor`/`handleFillColor` above, the live
    /// `UIAccessibility.shouldDifferentiateWithoutColor` value is read
    /// by `MKCanvasViewController` (this type's sole production owner,
    /// already `#if canImport(UIKit)`-gated and `@MainActor`) and threaded
    /// in here as plain data, keeping this layer fully headless-testable.
    /// Defaults to `false` (today's exact stroke/handle rendering,
    /// unchanged) so every existing call site behaves identically until it
    /// opts in.
    public var differentiateWithoutColor = false {
        didSet {
            guard differentiateWithoutColor != oldValue else { return }
            applyColors()
        }
    }

    /// Screen-space (zoom-independent) outline dash pattern used under
    /// Differentiate Without Color, on top of the existing accent-color
    /// stroke ، a solid line reads as "selected" by SHAPE (dashed vs.
    /// solid), not only by color, for users who can't rely on color alone.
    private static let differentiateDashPattern: [NSNumber] = [4, 3]

    public init() {
        containerLayer.zPosition = 1000
    }

    /// Redraws chrome for `obbs` (one outline per node) plus one shared set
    /// of resize/rotate handles for `handleAnchor` (typically the single
    /// selected node's OBB, or the multi-select union bounds treated as a
    /// zero-rotation `MKOrientedRect`) at `zoomScale`.
    public func update(obbs: [MKOrientedRect], handleAnchor: MKOrientedRect?, zoomScale: CGFloat) {
        updateOutlines(obbs)
        updateHandles(anchor: handleAnchor, zoomScale: zoomScale)
    }

    public func clear() {
        outlineLayers.forEach { $0.removeFromSuperlayer() }
        outlineLayers.removeAll()
        handleLayers.forEach { $0.removeFromSuperlayer() }
        handleLayers.removeAll()
    }

    private func updateOutlines(_ obbs: [MKOrientedRect]) {
        while outlineLayers.count < obbs.count {
            let layer = CAShapeLayer()
            layer.fillColor = nil
            layer.lineWidth = 1
            containerLayer.addSublayer(layer)
            outlineLayers.append(layer)
        }
        while outlineLayers.count > obbs.count {
            outlineLayers.removeLast().removeFromSuperlayer()
        }
        for (layer, obb) in zip(outlineLayers, obbs) {
            let path = CGMutablePath()
            let corners = obb.corners
            guard let first = corners.first else { continue }
            path.move(to: first)
            for corner in corners.dropFirst() { path.addLine(to: corner) }
            path.closeSubpath()
            layer.path = path
            layer.strokeColor = strokeColor
            layer.lineDashPattern = differentiateWithoutColor ? Self.differentiateDashPattern : nil
        }
    }

    private func updateHandles(anchor: MKOrientedRect?, zoomScale: CGFloat) {
        guard let anchor else {
            handleLayers.forEach { $0.removeFromSuperlayer() }
            handleLayers.removeAll()
            return
        }
        let positions = MKSelectionHandleLayout.allHandlePositions(on: anchor, zoomScale: zoomScale)
        while handleLayers.count < positions.count {
            let layer = CAShapeLayer()
            containerLayer.addSublayer(layer)
            handleLayers.append(layer)
        }
        while handleLayers.count > positions.count {
            handleLayers.removeLast().removeFromSuperlayer()
        }
        let screenDiameter = MKSelectionHandleLayout.handleDiameter / max(zoomScale, 0.0001)
        for (layer, position) in zip(handleLayers, positions.values) {
            let rect = CGRect(x: position.x - screenDiameter / 2, y: position.y - screenDiameter / 2, width: screenDiameter, height: screenDiameter)
            layer.path = CGPath(ellipseIn: rect, transform: nil)
            layer.fillColor = handleFillColor
            layer.strokeColor = strokeColor
        }
    }

    private func applyColors() {
        let dashPattern = differentiateWithoutColor ? Self.differentiateDashPattern : nil
        outlineLayers.forEach { $0.strokeColor = strokeColor; $0.lineDashPattern = dashPattern }
        handleLayers.forEach { $0.fillColor = handleFillColor; $0.strokeColor = strokeColor }
    }
}
