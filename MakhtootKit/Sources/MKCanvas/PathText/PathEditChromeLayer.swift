import CoreGraphics
import MKFoundation
import MKModel
import QuartzCore

// WS-06 packet §5 task 16 ("anchors/handles drawn in chrome layer") ،
// Path-Edit Mode's visual chrome, mirroring `SelectionChromeLayer.swift`'s
// exact architectural split: a PURE geometry enum (unit-testable without a
// live layer tree, same reason `MKSelectionHandleLayout` is separate from
// its layer class) plus a thin `CALayer`-driving class. `CALayer`/
// `CAShapeLayer` are QuartzCore, not UIKit ، no `#if canImport(UIKit)`
// guard, same as the selection-chrome precedent, so this builds on both
// platform declarations in `Package.swift`.
//
// Coordinate spaces (matches the seam's own conventions ، see
// `MKPathTextEngineProviding.swift`): hit-target positions from
// `hitTargets(for:)` are already world/canvas space (the app-layer engine
// resolves the node transform, same as `MKCanvasGeometrySource
// .arrangedChildHit`'s `worldPoint`), so anchor/handle dots use them
// as-is; the raw `MKPathTextNode.path` is node-LOCAL, so the guide line
// applies the node's `core.transform` ، via `MKTransform2D
// .affineTransform`, the same canonical decomposed→affine bridge every
// other world-space projection in this package uses.

/// Pure geometry for path-edit chrome: guide-path projection, handle→anchor
/// connector pairing, and dot sizing. Kept separate from the
/// `CALayer`-driving code below so the math is unit-testable without a
/// layer tree (`PathTextInteractionModelTests`' chrome-geometry section) ،
/// the exact split `MKSelectionHandleLayout` already established.
public enum PathEditChromeGeometry {
    /// Screen-space (constant-size, zoom-independent) anchor-dot diameter ،
    /// matches `MKSelectionHandleLayout.handleDiameter` so path anchors
    /// read at the same visual weight as resize handles.
    public static let anchorDiameter: CGFloat = 10
    /// Bézier-handle dots are deliberately smaller than anchor dots (the
    /// standard pen-tool visual hierarchy: anchors are the primary
    /// targets, handles secondary).
    public static let handleDiameter: CGFloat = 6

    /// The live path as a world-space `CGPath` guide line: the node-local
    /// `MKBezierPathData.cgPath()` transformed by the node's own
    /// `core.transform` (see file header's coordinate-space note).
    public static func guidePath(_ path: MKBezierPathData, transform: MKTransform2D) -> CGPath {
        var affine = transform.affineTransform
        let local = path.cgPath()
        return local.copy(using: &affine) ?? local
    }

    /// One straight connector segment per PRESENT Bézier handle, pairing
    /// each `handleIn`/`handleOut` target with its own anchor's position
    /// (matched by `anchorID`) ، the classic pen-tool "stick" from anchor
    /// to handle knob. Targets whose anchor is missing from `targets`
    /// (should not happen ، `hitTargets(for:)` always emits the anchor
    /// before its handles) are skipped rather than crashed on, §9.6-style
    /// degenerate-input discipline.
    public static func connectorSegments(in targets: [MKPathHitTarget]) -> [(from: CGPoint, to: CGPoint)] {
        let anchorPositions: [UUID: CGPoint] = Dictionary(
            uniqueKeysWithValues: targets.filter { $0.id.kind == .anchor }.map { ($0.id.anchorID, $0.position) })
        return targets.compactMap { target in
            guard target.id.kind != .anchor, let anchorPosition = anchorPositions[target.id.anchorID] else { return nil }
            return (from: anchorPosition, to: target.position)
        }
    }

    /// The world-space rect for a dot of screen-space `diameter` centered
    /// at `center`, compensated by `1 / zoomScale` so dots read at a
    /// constant SCREEN size across zoom ، same compensation
    /// `SelectionChromeLayer.updateHandles` applies (ARCHITECTURE §10.4
    /// "handles scale-invariant").
    public static func dotRect(center: CGPoint, diameter: CGFloat, zoomScale: CGFloat) -> CGRect {
        let d = diameter / max(zoomScale, 0.0001)
        return CGRect(x: center.x - d / 2, y: center.y - d / 2, width: d, height: d)
    }
}

/// Drives the actual `CALayer` tree for path-edit chrome (task 16:
/// "anchors/handles drawn in chrome layer"): one thin stroked guide layer
/// for the live path, one connector layer per present Bézier handle, one
/// dot layer per hit target, with the `selectedHandle` dot highlighted.
/// Owned/laid out/refreshed by `MKCanvasViewController` exactly like its
/// `selectionChrome` sibling ، added to the same content-view superlayer
/// (so zoom/pan tracking is automatic) and refreshed from
/// `refreshSelectionChrome()`, hidden/emptied whenever `session.mode` is
/// not `.pathEdit`.
@MainActor
public final class PathEditChromeLayer {
    public let containerLayer = CALayer()
    private let guideLayer = CAShapeLayer()
    private var connectorLayers: [CAShapeLayer] = []
    private var dotLayers: [CAShapeLayer] = []

    /// Colors injected by `MKCanvasViewController` from the theme at
    /// setup time ، same mechanism (not hardcoded) `SelectionChromeLayer
    /// .strokeColor`/`.handleFillColor` use.
    public var strokeColor: CGColor = CGColor(gray: 0, alpha: 1) {
        didSet { applyColors() }
    }
    public var dotFillColor: CGColor = CGColor(gray: 1, alpha: 1) {
        didSet { applyColors() }
    }
    /// Highlight for the currently selected anchor/handle
    /// (`MKPathTextInteractionModel.selectedHandle`).
    public var highlightColor: CGColor = CGColor(gray: 0.5, alpha: 1)

    /// Kept per-dot so `applyColors` can re-apply base vs highlight
    /// correctly on a late color injection.
    private var dotHighlightFlags: [Bool] = []

    public init() {
        // One above the selection chrome's own 1000 ، path-edit chrome is
        // only ever visible in `.pathEdit` mode where it IS the primary
        // chrome, so the ordering is belt-and-braces, not a visual fight.
        containerLayer.zPosition = 1001
        guideLayer.fillColor = nil
        guideLayer.lineWidth = 1
        // Dashed, matching the universal "guide, not content" idiom (the
        // R-9.9 arranged-mode ghost guide will want the same look).
        guideLayer.lineDashPattern = [4, 3]
        containerLayer.addSublayer(guideLayer)
    }

    /// Redraws the full chrome: `guidePath` (world space, from
    /// `PathEditChromeGeometry.guidePath`), one dot per target, one
    /// connector per handle target, `selected` highlighted. Dot sizes are
    /// compensated by `1 / zoomScale` (constant screen size, same as
    /// selection handles).
    public func update(guidePath: CGPath?, targets: [MKPathHitTarget], selected: MKPathHandleID?, zoomScale: CGFloat) {
        containerLayer.isHidden = false
        guideLayer.path = guidePath
        guideLayer.strokeColor = strokeColor
        updateConnectors(PathEditChromeGeometry.connectorSegments(in: targets))
        updateDots(targets, selected: selected, zoomScale: zoomScale)
    }

    /// Hides and empties everything ، called whenever `session.mode` is
    /// not `.pathEdit` (mirrors `SelectionChromeLayer.clear()`'s role in
    /// `refreshSelectionChrome`).
    public func clear() {
        containerLayer.isHidden = true
        guideLayer.path = nil
        connectorLayers.forEach { $0.removeFromSuperlayer() }
        connectorLayers.removeAll()
        dotLayers.forEach { $0.removeFromSuperlayer() }
        dotLayers.removeAll()
        dotHighlightFlags.removeAll()
    }

    private func updateConnectors(_ segments: [(from: CGPoint, to: CGPoint)]) {
        while connectorLayers.count < segments.count {
            let layer = CAShapeLayer()
            layer.fillColor = nil
            layer.lineWidth = 1
            containerLayer.addSublayer(layer)
            connectorLayers.append(layer)
        }
        while connectorLayers.count > segments.count {
            connectorLayers.removeLast().removeFromSuperlayer()
        }
        for (layer, segment) in zip(connectorLayers, segments) {
            let path = CGMutablePath()
            path.move(to: segment.from)
            path.addLine(to: segment.to)
            layer.path = path
            layer.strokeColor = strokeColor
        }
    }

    private func updateDots(_ targets: [MKPathHitTarget], selected: MKPathHandleID?, zoomScale: CGFloat) {
        while dotLayers.count < targets.count {
            let layer = CAShapeLayer()
            containerLayer.addSublayer(layer)
            dotLayers.append(layer)
        }
        while dotLayers.count > targets.count {
            dotLayers.removeLast().removeFromSuperlayer()
        }
        dotHighlightFlags = targets.map { $0.id == selected }
        for (index, (layer, target)) in zip(dotLayers, targets).enumerated() {
            let diameter = target.id.kind == .anchor ? PathEditChromeGeometry.anchorDiameter : PathEditChromeGeometry.handleDiameter
            let rect = PathEditChromeGeometry.dotRect(center: target.position, diameter: diameter, zoomScale: zoomScale)
            layer.path = CGPath(ellipseIn: rect, transform: nil)
            let highlighted = dotHighlightFlags[index]
            layer.fillColor = highlighted ? highlightColor : dotFillColor
            layer.strokeColor = strokeColor
        }
    }

    private func applyColors() {
        guideLayer.strokeColor = strokeColor
        connectorLayers.forEach { $0.strokeColor = strokeColor }
        for (index, layer) in dotLayers.enumerated() {
            let highlighted = index < dotHighlightFlags.count && dotHighlightFlags[index]
            layer.fillColor = highlighted ? highlightColor : dotFillColor
            layer.strokeColor = strokeColor
        }
    }
}
