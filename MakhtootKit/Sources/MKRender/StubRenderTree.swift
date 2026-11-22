import CoreGraphics
import MKFoundation
import MKModel
import QuartzCore

// WS-07 packet §5 task 1. Flat-colored-rect stub so WS-06 (`MKCanvas`) can
// build/run against a real `CALayer` tree before `MKLayerTreeController`
// (this packet's later tasks) lands real CG-rendered bitmaps. No CoreGraphics
// drawing at all ، every layer is a plain solid-color `CALayer` sized to
// the node's `NodeLocalBounds.worldBounds`.
@MainActor
public final class StubRenderTree: RenderTreeProviding {
    public let hostLayer = CALayer()
    private var layers: [MKNodeID: CALayer] = [:]
    private var rasterizationCount = 0

    public init() {
        hostLayer.name = "MKRender.StubRenderTree"
    }

    public func sync(to scene: MKScene) {
        var seen = Set<MKNodeID>()

        for node in scene.nodes {
            seen.insert(node.id)
            let layer = layerForNode(node.id, kind: node)
            configure(layer, for: node)
            rasterizationCount += 1
        }

        for (id, layer) in layers where !seen.contains(id) {
            layer.removeFromSuperlayer()
            layers.removeValue(forKey: id)
        }
    }

    public func applyTransientTransform(nodeID: MKNodeID, transform: CGAffineTransform) {
        guard let layer = layers[nodeID] else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.setAffineTransform(transform)
        CATransaction.commit()
    }

    public func commitTransients() {}

    public func setVisibleRect(_ visibleRect: CGRect, zoomScale: CGFloat) {}

    public func consumeRasterizationCount() -> Int {
        defer { rasterizationCount = 0 }
        return rasterizationCount
    }

    private func layerForNode(_ id: MKNodeID, kind: MKNode) -> CALayer {
        if let existing = layers[id] { return existing }
        let layer = CALayer()
        layer.anchorPoint = .zero
        hostLayer.addSublayer(layer)
        layers[id] = layer
        return layer
    }

    private func configure(_ layer: CALayer, for node: MKNode) {
        layer.isHidden = node.core.isHidden
        layer.opacity = Float(node.core.opacity)
        let bounds = MKNodeLocalBounds.localBounds(of: node)
        layer.bounds = CGRect(origin: .zero, size: bounds.size)
        layer.position = node.core.transform.position
        // Rotation/scale only ، translation is carried by `layer.position`
        // (matching the real `MKLayerTreeController`'s layer-property
        // convention so a WS-06 dev build behaves consistently switching
        // between the stub and the real controller).
        var rotateScale = node.core.transform
        rotateScale.position = .zero
        layer.setAffineTransform(rotateScale.affineTransform)
        layer.backgroundColor = Self.flatColor(for: node).cgColor
    }

    private static func flatColor(for node: MKNode) -> MKSolidColor {
        switch node {
        case .group: return MKSolidColor(r: 0.6, g: 0.6, b: 0.6, a: 0.3)
        case .liveText: return MKSolidColor(r: 0.11, g: 0.10, b: 0.09, a: 0.5)
        case .pathText: return MKSolidColor(r: 0.2, g: 0.4, b: 0.8, a: 0.5)
        case .arranged: return MKSolidColor(r: 0.6, g: 0.15, b: 0.1, a: 0.5)   // madder-red family (D-126)
        case .shape: return MKSolidColor(r: 0.3, g: 0.3, b: 0.3, a: 0.5)
        case .image: return MKSolidColor(r: 0.2, g: 0.6, b: 0.3, a: 0.5)
        case .background: return MKSolidColor(r: 0.9, g: 0.9, b: 0.85, a: 1)
        }
    }
}
