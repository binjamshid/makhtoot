import CoreGraphics
import MKFoundation

// WS-06 packet §5 task 7: "drag on empty canvas → marquee rect; intersect
// mode default, ⌥/long-drag toggles contain mode; excludes locked/hidden."
// Pure rect math over `MKHitCandidate` (this module's own candidate shape,
// `HitTestPolicy.swift`) ، no gesture-recognizer/UIKit dependency, per the
// packet's gate ("unit tests... marquee hit-sets").

public enum MKMarqueeMode: Sendable, Equatable {
    /// Selects anything the marquee rect touches at all (default).
    case intersect
    /// Selects only nodes fully contained within the marquee rect (⌥ /
    /// long-drag toggle).
    case contain
}

public enum MKMarqueeController {
    /// Builds a normalized (non-negative width/height) marquee rect from a
    /// drag's start/current points ، the gesture coordinator feeds raw,
    /// possibly-inverted drag vectors in from any direction.
    public static func rect(from start: CGPoint, to current: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    /// Selected node ids for `marquee`, honoring `mode` and excluding
    /// locked/hidden candidates entirely (task 7). Uses each candidate's
    /// axis-aligned bounds (`MKOrientedRect.axisAlignedBounds`) ، the same
    /// "cheap reject" shape `HitTestPolicy`/ARCHITECTURE §10.3 use, which
    /// is the standard, predictable behavior for marquee-selecting rotated
    /// shapes (a rotated node's corner poking into the marquee rect counts
    /// as touched under `.intersect`).
    public static func select(
        marquee: CGRect,
        candidates: [MKHitCandidate],
        mode: MKMarqueeMode
    ) -> Set<MKNodeID> {
        let eligible = candidates.filter { !$0.isLocked && !$0.isHidden }
        switch mode {
        case .intersect:
            return Set(eligible.filter { marquee.intersects($0.worldOBB.axisAlignedBounds) }.map(\.nodeID))
        case .contain:
            return Set(eligible.filter { marquee.contains($0.worldOBB.axisAlignedBounds) }.map(\.nodeID))
        }
    }
}
