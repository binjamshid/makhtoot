import CoreGraphics
import MKFoundation

// WS-06 packet §5 task 8. Pure matrix math backing group/transform/ungroup
// round-tripping: "group→transform→ungroup leaves children at correct
// world positions (property test vs matrix math)."
//
// `MKScene.reparenting` (WS-02, `MKModel/MKScene.swift`) creates the group
// node with an IDENTITY transform and copies children in as-is ، since
// identity composition is a no-op, each child's `core.transform` at the
// moment of grouping already equals its effective WORLD transform. That
// half of the round trip needs no fixup. What DOES need explicit handling
// is the other half: once the group itself has been moved/rotated/scaled
// (`MKTransformCommand` on the group node), a child's *stored* local
// transform is no longer its world transform ، the two only coincide again
// once the group's own transform is composed back in. This file is that
// composition, in both directions.
public enum MKGroupTransform {
    /// A child's effective WORLD transform, given its transform as stored
    /// inside the group (`childLocal`, i.e. relative to the group's own
    /// frame) and the group node's own transform (`groupTransform`).
    /// Composition order matches `MKTransform2D.concatenating`'s contract
    /// ("self followed by other"): a point is first mapped by the child's
    /// local transform (into the group's frame), then by the group's
    /// transform (into the group's parent frame).
    public static func worldTransform(childLocal: MKTransform2D, groupTransform: MKTransform2D) -> MKTransform2D {
        childLocal.concatenating(groupTransform)
    }

    /// The inverse: given a child's desired WORLD transform and the
    /// group's transform, the local transform to store on the child so
    /// that `worldTransform(childLocal:groupTransform:) == childWorld`
    /// (within the shear-free approximation `MKTransform2D` documents on
    /// `inverted()`/`concatenating(_:)`).
    public static func localTransform(childWorld: MKTransform2D, groupTransform: MKTransform2D) -> MKTransform2D {
        childWorld.concatenating(groupTransform.inverted())
    }
}
