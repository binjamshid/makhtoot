import CoreGraphics
import MKFoundation
import MKModel
import QuartzCore

// WS-07 packet §5 task 1: "`RenderTreeProviding` protocol + stub
// (unblocks WS-06)... ship early." Published in CONTRACTS.md within this
// packet's first work hour per the contract-first duty; this file is the
// canonical source, CONTRACTS.md mirrors it for cross-packet visibility.
//
// `@MainActor`, not `Sendable`: this protocol is UIKit/CoreAnimation-facing
// (D-114's canvas host), and every conformer holds live `CALayer`s ، D-102's
// "@MainActor UI + document model" placement applies directly.
@MainActor
public protocol RenderTreeProviding: AnyObject {
    /// The layer WS-06 inserts as a sublayer of its canvas content view.
    var hostLayer: CALayer { get }

    /// Reconciles the layer tree to match `scene` (D-114 diffing, §11.2):
    /// inserts/removes/updates only the layers whose content actually
    /// changed (via `MKContentHash`).
    func sync(to scene: MKScene)

    /// 60/120 Hz hot path (§11.2/§14.3): applies `transform` to ONE node's
    /// layer as a property update inside a `CATransaction` with actions
    /// disabled ، zero draw/bitmap work. Called every gesture-changed
    /// frame; `transform` is the node's full LIVE (in-progress) world
    /// transform, not a delta ، conformers compute the delta from their
    /// own last-committed state internally.
    func applyTransientTransform(nodeID: MKNodeID, transform: CGAffineTransform)

    /// Gesture end. WS-06 calls this, then applies the real command to the
    /// document and calls `sync(to:)` with the now-committed scene ،
    /// `commitTransients()` itself does not need scene access; it exists
    /// so a conformer can clear transient-only bookkeeping explicitly
    /// between "gesture ended" and "new committed scene arrived," which
    /// may not be the same instant (e.g. an async undo-stack round trip).
    func commitTransients()

    /// Zoom/pan bookkeeping feeding the §11.3 zoom-bucket policy and
    /// offscreen-eviction hooks; `zoomScale` is the raw UIScrollView zoom
    /// factor (bucketed internally via `MKScaleBucket`).
    func setVisibleRect(_ visibleRect: CGRect, zoomScale: CGFloat)

    /// Test/HUD observability (task 5 accept: "editing one node
    /// re-rasterizes exactly one layer (instrumented count)"). Resets the
    /// counter on read.
    func consumeRasterizationCount() -> Int
}
