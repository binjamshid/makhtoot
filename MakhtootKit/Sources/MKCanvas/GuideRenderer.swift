import CoreGraphics
import QuartzCore
#if canImport(UIKit)
import UIKit
#endif

// WS-06 packet §5 task 9: "Guides drawn in chrome layer (accent color,
// hairline)." Renders `MKSnapGuide` descriptors (`SnapEngine.swift`, pure
// data) as hairline `CAShapeLayer`s. QuartzCore-only, no UIKit ، builds on
// both platform declarations.

/// UX-4 (AUDIT_2026-07-28.md): same abstraction/testing rationale as
/// `GestureCoordinator`'s `MKSelectionFeedbackGenerating` (this type's own
/// header note "builds on both platform declarations" is exactly why this
/// is a protocol rather than a direct `UIImpactFeedbackGenerator`
/// reference — a plain macOS `swift build`/`swift test` host has no UIKit
/// at all, and this type must keep building there).
public protocol MKImpactFeedbackGenerating: AnyObject {
    func impactOccurred()
}
#if canImport(UIKit)
extension UIImpactFeedbackGenerator: @MainActor MKImpactFeedbackGenerating {}
#endif

@MainActor
public final class GuideRenderer {
    public let containerLayer = CALayer()
    private var guideLayers: [CAShapeLayer] = []

    public var color: CGColor = CGColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1) {
        didSet { guideLayers.forEach { $0.strokeColor = color } }
    }
    /// Hairline width in VIEW points regardless of zoom (task 9: "hairline").
    public var lineWidthPoints: CGFloat = 1

    /// UX-4: fires once per not-engaged → engaged transition (see
    /// `isEngaged`'s own doc comment below). `nil` on a platform with no
    /// UIKit (a plain macOS `swift test` host) so this type keeps building
    /// there ، the engage/disengage edge-detection logic itself is still
    /// fully exercised by `MKCanvasHapticsTests` regardless (that logic
    /// has no UIKit dependency of its own; only the concrete generator
    /// does). Public so tests can substitute a spy and so
    /// `MKCanvasViewController` (this type's sole production owner) could
    /// swap it per-instance if a future change needs `gridRenderer`'s
    /// SEPARATE `GuideRenderer` instance (the always-on-request reference
    /// grid, not live snap guides — see `MKCanvasViewController.swift`'s
    /// own header on that second instance) to opt out of firing haptics on
    /// its own empty→non-empty transitions, which are grid-visibility
    /// toggles, not snap events.
    public var impactFeedbackGenerator: (any MKImpactFeedbackGenerating)?
    /// Whether the last `update(guides:zoomScale:)` call had a non-empty
    /// `guides` array. Tracked as an explicit stored flag (not re-derived
    /// from `guideLayers.isEmpty`, which `update` mutates BEFORE this
    /// would read it) so `update` can detect the not-engaged → engaged
    /// EDGE specifically ، firing once when snapping first engages, never
    /// again on every redraw while still engaged, and never on disengage.
    private var isEngaged = false

    public init() {
        containerLayer.zPosition = 999
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        impactFeedbackGenerator = generator
        #endif
    }

    public func update(guides: [MKSnapGuide], zoomScale: CGFloat) {
        while guideLayers.count < guides.count {
            let layer = CAShapeLayer()
            layer.fillColor = nil
            containerLayer.addSublayer(layer)
            guideLayers.append(layer)
        }
        while guideLayers.count > guides.count {
            guideLayers.removeLast().removeFromSuperlayer()
        }
        let width = lineWidthPoints / max(zoomScale, 0.0001)
        for (layer, guide) in zip(guideLayers, guides) {
            let path = CGMutablePath()
            switch guide.axis {
            case .horizontal:
                path.move(to: CGPoint(x: guide.position, y: guide.extentStart))
                path.addLine(to: CGPoint(x: guide.position, y: guide.extentEnd))
            case .vertical:
                path.move(to: CGPoint(x: guide.extentStart, y: guide.position))
                path.addLine(to: CGPoint(x: guide.extentEnd, y: guide.position))
            }
            layer.path = path
            layer.strokeColor = color
            layer.lineWidth = width
        }

        // UX-4: not-engaged → engaged edge only.
        let nowEngaged = !guides.isEmpty
        if nowEngaged, !isEngaged {
            impactFeedbackGenerator?.impactOccurred()
        }
        isEngaged = nowEngaged
    }

    public func clear() {
        guideLayers.forEach { $0.removeFromSuperlayer() }
        guideLayers.removeAll()
        isEngaged = false
    }
}
