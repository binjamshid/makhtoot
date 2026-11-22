import CoreGraphics
import Foundation
import MKFoundation

// WS-07 packet §5 task 3. Render options: `.editorPreview(stage:)` vs
// `.exportQuality` (ARCHITECTURE §11.1's literal wording), plus the small
// value types `SceneRenderer`/`SnapshotRenderer` share.

/// The renderer's two operating modes (ARCHITECTURE §11.1): preview quality
/// tracks the D-116 degradation ladder's current stage; export quality
/// NEVER degrades regardless of ladder stage (D-118 ، "if memory can't
/// support export, WS-08 tiling handles it", not a quality cut).
public enum MKRenderQuality: Sendable, Hashable {
    case editorPreview(stage: MKMemoryStage)
    case exportQuality

    /// The `MKRenderFidelity` this quality implies for drawers (task 11:
    /// "stage ≥2 uses half-res + cheap shadows... export path NEVER
    /// degrades").
    public var fidelity: MKRenderFidelity {
        switch self {
        case .exportQuality: return .full
        case .editorPreview(let stage): return stage >= .stage2 ? .reduced : .full
        }
    }

    /// CG image interpolation quality for raster assets (ARCHITECTURE
    /// §11.1: `.high` at export, `.medium` in preview; §11.4: `.low` when
    /// `.reduced`).
    public var imageInterpolationQuality: CGInterpolationQuality {
        switch self {
        case .exportQuality: return .high
        case .editorPreview(let stage): return stage >= .stage2 ? .low : .medium
        }
    }
}

/// Every node-content drawer (`Drawers/*.swift`) is a stateless `Sendable`
/// struct with its own `draw(_:into:quality:report:)` method (no shared
/// generic protocol ، each drawer's node payload type differs, and
/// `SceneRenderer`'s traversal dispatches via a `switch` over `MKNode`
/// anyway, so a common associated-type protocol would add indirection
/// without a real call site). This comment documents the shared SIGNATURE
/// convention drawers follow, not an enforced protocol: `draw(_ node:
/// into ctx: CGContext, quality: MKRenderQuality, report: inout
/// MKRenderReportBuilder)` ، content only, NOT transform/opacity
/// (`SceneRenderer` applies those around the call, §11.1's "concat node
/// affine, apply opacity via transparency layer" step).

/// Mutable accumulator `SceneRenderer` threads through a render pass;
/// finalized into the immutable, `Sendable` `MKRenderReport` it returns.
public struct MKRenderReportBuilder {
    public var substitutions: [MKRenderSubstitution] = []
    public var nodeCount: Int = 0

    public init() {}

    public mutating func recordSubstitution(nodeID: MKNodeID, kind: MKRenderSubstitution.Kind, detail: String) {
        substitutions.append(MKRenderSubstitution(nodeID: nodeID, kind: kind, detail: detail))
    }
}

/// `MKRenderReport` (ARCHITECTURE §11.1): per-render substitution events
/// (missing asset/outline/font) ، "surfaced in debug HUD and asserted
/// empty in export tests."
public struct MKRenderReport: Sendable, Equatable {
    public var substitutions: [MKRenderSubstitution]
    public var nodeCount: Int
    public var duration: TimeInterval

    public init(substitutions: [MKRenderSubstitution], nodeCount: Int, duration: TimeInterval) {
        self.substitutions = substitutions
        self.nodeCount = nodeCount
        self.duration = duration
    }
}

public struct MKRenderSubstitution: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case missingAsset
        case missingOutline
        case missingFont
    }
    public var nodeID: MKNodeID
    public var kind: Kind
    public var detail: String

    public init(nodeID: MKNodeID, kind: Kind, detail: String) {
        self.nodeID = nodeID
        self.kind = kind
        self.detail = detail
    }
}
