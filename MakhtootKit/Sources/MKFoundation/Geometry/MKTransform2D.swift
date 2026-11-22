import CoreGraphics

/// The canonical node transform representation for the scene graph
/// (D-111: "decomposed, not raw matrix"). Every `MKNode` in `MKModel`
/// carries one of these instead of a raw `CGAffineTransform`, so the
/// inspector can show independent position/rotation/scale fields and
/// interpolation/undo never has to decompose a matrix back out.
///
/// Composition order is scale → rotate → translate (standard 2-D sprite
/// convention): a point is first scaled about the origin, then rotated,
/// then translated to `position`.
public struct MKTransform2D: Hashable, Codable, Sendable {
    /// Translation, in the parent's coordinate space.
    public var position: CGPoint
    /// Rotation in radians, counter-clockwise positive (CoreGraphics
    /// convention).
    public var rotation: CGFloat
    /// Non-uniform scale factors applied before rotation.
    public var scale: CGSize

    public init(position: CGPoint = .zero, rotation: CGFloat = 0, scale: CGSize = CGSize(width: 1, height: 1)) {
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }

    public static let identity = MKTransform2D()

    /// The equivalent `CGAffineTransform`, derived fresh from the decomposed
    /// fields on every access (no cached/raw-matrix storage, per D-111).
    ///
    /// Built directly from the scale→rotate→translate formula (a point is
    /// scaled about the origin, then rotated, then translated to
    /// `position`) rather than by chaining
    /// `.translatedBy(_:).rotated(_:).scaledBy(_:)`: those builder methods
    /// compose in the *opposite* order (translate happens first in the
    /// point-mapping sense), which silently produces the wrong matrix for
    /// any non-identity position+rotation+scale combination. This closed
    /// form is also the exact inverse of `init(decomposing:)` below, so
    /// `MKTransform2D(decomposing: t.affineTransform) == t`.
    public var affineTransform: CGAffineTransform {
        let cosTheta = cos(rotation)
        let sinTheta = sin(rotation)
        return CGAffineTransform(
            a: scale.width * cosTheta,
            b: scale.width * sinTheta,
            c: -scale.height * sinTheta,
            d: scale.height * cosTheta,
            tx: position.x,
            ty: position.y
        )
    }

    /// Concatenates `self` followed by `other`: applying the result to a
    /// point is equivalent to applying `self` then `other`.
    ///
    /// Because the canonical representation is decomposed (not a raw
    /// matrix), concatenation is realized by composing the two affine
    /// transforms and re-decomposing the result ، see
    /// `MKTransform2D.init(decomposing:)`.
    ///
    /// **Known limitation (inherent to shear-free decomposed transforms,
    /// not a bug):** when a transform with *non-uniform* scale
    /// (`scale.width != scale.height`) is combined with a *non-zero*
    /// rotation, the true composed/inverted affine matrix generally
    /// requires shear to represent exactly ، and `MKTransform2D` has no
    /// shear term (D-111 fixes the shape to position/rotation/scale only).
    /// `init(decomposing:)` still returns the best shear-free
    /// approximation in that case, but `result.affineTransform` will not
    /// exactly equal the true composed matrix. The round-trip **is**
    /// exact whenever scale is uniform, or rotation is zero, on either
    /// operand ، which covers every scene-graph transform Makhtoot
    /// produces today (v1 has no per-axis shear tool). Callers that need
    /// the exact composed matrix regardless of shear should compose
    /// `affineTransform` values directly instead of going through this
    /// decomposed API.
    public func concatenating(_ other: MKTransform2D) -> MKTransform2D {
        let combined = affineTransform.concatenating(other.affineTransform)
        return MKTransform2D(decomposing: combined)
    }

    /// The inverse transform, decomposed. `t.concatenating(t.inverted())`
    /// round-trips a point back to itself (within floating-point epsilon)
    /// whenever `t.scale` is uniform or `t.rotation` is zero ، see the
    /// shear limitation documented on `concatenating(_:)` above, which
    /// applies identically here (inversion is composition with the
    /// identity in reverse).
    public func inverted() -> MKTransform2D {
        MKTransform2D(decomposing: affineTransform.inverted())
    }

    /// Maps a point from the transform's local space into its parent space.
    public func apply(to point: CGPoint) -> CGPoint {
        point.applying(affineTransform)
    }

    /// Decomposes an arbitrary affine transform back into
    /// position/rotation/scale. Used internally by `concatenating`/
    /// `inverted`, and by any code bridging in from a raw
    /// `CGAffineTransform` (e.g. UIKit gesture recognizers).
    ///
    /// Decomposition assumes no skew (the only shape MakhtootKit ever
    /// produces via `affineTransform` above): `a = sx·cosθ`, `b = sx·sinθ`,
    /// `c = -sy·sinθ`, `d = sy·cosθ`.
    public init(decomposing matrix: CGAffineTransform) {
        let sx = (matrix.a * matrix.a + matrix.b * matrix.b).squareRoot()
        let sySign: CGFloat = (matrix.a * matrix.d - matrix.b * matrix.c) < 0 ? -1 : 1
        let sy = sySign * (matrix.c * matrix.c + matrix.d * matrix.d).squareRoot()
        let theta = atan2(matrix.b, matrix.a)
        self.position = CGPoint(x: matrix.tx, y: matrix.ty)
        self.rotation = theta
        self.scale = CGSize(width: sx, height: sy)
    }
}
