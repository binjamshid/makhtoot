import CoreGraphics
import Testing
@testable import MKFoundation

/// WS-01 packet §5 task 5 accept criteria: compose→decompose round-trip
/// within 1e-6; rotation of a marked point matches the `CGAffineTransform`
/// reference implementation.
@Suite("MKTransform2D")
struct TransformMathTests {
    private let epsilon: CGFloat = 1e-6

    @Test func decomposeOfAffineRoundTripsToSameTransform() {
        let original = MKTransform2D(
            position: CGPoint(x: 42, y: -17),
            rotation: .pi / 3,
            scale: CGSize(width: 2.5, height: 0.75)
        )
        let decomposed = MKTransform2D(decomposing: original.affineTransform)

        #expect(abs(decomposed.position.x - original.position.x) < epsilon)
        #expect(abs(decomposed.position.y - original.position.y) < epsilon)
        #expect(abs(decomposed.rotation - original.rotation) < epsilon)
        #expect(abs(decomposed.scale.width - original.scale.width) < epsilon)
        #expect(abs(decomposed.scale.height - original.scale.height) < epsilon)
    }

    @Test func rotationMatchesCGAffineTransformReference() {
        let angle: CGFloat = .pi / 4
        let transform = MKTransform2D(position: .zero, rotation: angle, scale: CGSize(width: 1, height: 1))
        let referenceMatrix = CGAffineTransform(rotationAngle: angle)

        let point = CGPoint(x: 10, y: 0)
        let mapped = transform.apply(to: point)
        let reference = point.applying(referenceMatrix)

        #expect(abs(mapped.x - reference.x) < epsilon)
        #expect(abs(mapped.y - reference.y) < epsilon)
    }

    @Test func identityConcatenatingAnythingReturnsThatTransform() {
        let t = MKTransform2D(position: CGPoint(x: 5, y: 5), rotation: 0.4, scale: CGSize(width: 1.2, height: 1.2))
        let result = MKTransform2D.identity.concatenating(t)

        #expect(abs(result.position.x - t.position.x) < epsilon)
        #expect(abs(result.position.y - t.position.y) < epsilon)
        #expect(abs(result.rotation - t.rotation) < epsilon)
    }

    @Test func invertedTransformMapsAPointBackToItselfWithUniformScale() {
        // Uniform scale + arbitrary rotation: the decomposed round-trip is
        // exact (no shear is ever needed to represent the true inverse).
        let t = MKTransform2D(
            position: CGPoint(x: 30, y: 12),
            rotation: 0.9,
            scale: CGSize(width: 1.4, height: 1.4)
        )
        let point = CGPoint(x: 7, y: -3)
        let forward = t.apply(to: point)
        let back = t.inverted().apply(to: forward)

        #expect(abs(back.x - point.x) < 1e-4)
        #expect(abs(back.y - point.y) < 1e-4)
    }

    @Test func invertedTransformMapsAPointBackToItselfWithNonUniformScaleAndNoRotation() {
        // Non-uniform scale + zero rotation: also exact ، shear only
        // enters the picture when non-uniform scale and non-zero rotation
        // combine (see `concatenating(_:)` doc comment).
        let t = MKTransform2D(
            position: CGPoint(x: -8, y: 21),
            rotation: 0,
            scale: CGSize(width: 2.0, height: 0.5)
        )
        let point = CGPoint(x: 3, y: 9)
        let forward = t.apply(to: point)
        let back = t.inverted().apply(to: forward)

        #expect(abs(back.x - point.x) < 1e-4)
        #expect(abs(back.y - point.y) < 1e-4)
    }

    @Test func matrixLevelInversionRemainsExactEvenWhenDecomposedInversionCannot() {
        // Documents the escape hatch for the non-uniform-scale +
        // non-zero-rotation case: composing/inverting `affineTransform`
        // directly (bypassing the decomposed representation) is always
        // exact, because CGAffineTransform itself supports shear even
        // though MKTransform2D does not.
        let t = MKTransform2D(
            position: CGPoint(x: 30, y: 12),
            rotation: 0.9,
            scale: CGSize(width: 1.4, height: 0.6)
        )
        let point = CGPoint(x: 7, y: -3)
        let forward = point.applying(t.affineTransform)
        let back = forward.applying(t.affineTransform.inverted())

        #expect(abs(back.x - point.x) < 1e-6)
        #expect(abs(back.y - point.y) < 1e-6)
    }
}
