import Testing
import CoreGraphics
@testable import MKExport

// WS-08 packet §5 task 6 accept: "1080×1080 untouched; 4096×4096 →
// ~1414×1414; aspect-preservation property test."
@Suite struct FreeTierBudgetTests {
    @Test func sizeWithinBudgetIsUntouched() {
        let size = CGSize(width: 1080, height: 1080)
        #expect(MKFreeTierBudget.clamped(size) == size)
        #expect(!MKFreeTierBudget.exceedsBudget(size))
    }

    @Test func fourKSquareClampsToApproximatelyExpectedSize() {
        let clamped = MKFreeTierBudget.clamped(CGSize(width: 4096, height: 4096))
        #expect(abs(clamped.width - 1414) < 1)
        #expect(abs(clamped.height - 1414) < 1)
        #expect(Double(clamped.width) * Double(clamped.height) <= Double(MKFreeTierBudget.effectivePixelBudget) + 1)
    }

    @Test func exceedsBudgetMatchesClampBehavior() {
        #expect(MKFreeTierBudget.exceedsBudget(CGSize(width: 4096, height: 4096)))
        #expect(!MKFreeTierBudget.exceedsBudget(CGSize(width: 100, height: 100)))
    }

    @Test(arguments: [
        CGSize(width: 3000, height: 1000),
        CGSize(width: 1000, height: 3000),
        CGSize(width: 5000, height: 5000),
        CGSize(width: 1920, height: 1080),
    ])
    func aspectRatioIsPreservedUnderClamp(_ size: CGSize) {
        let clamped = MKFreeTierBudget.clamped(size)
        let originalRatio = size.width / size.height
        let clampedRatio = clamped.width / clamped.height
        #expect(abs(originalRatio - clampedRatio) < 0.001)
    }

    @Test func degenerateSizesPassThroughUnchanged() {
        let zero = CGSize(width: 0, height: 500)
        #expect(MKFreeTierBudget.clamped(zero) == zero)
        #expect(!MKFreeTierBudget.exceedsBudget(zero))
    }

    @Test func clampNeverUpscales() {
        let tiny = CGSize(width: 10, height: 10)
        let clamped = MKFreeTierBudget.clamped(tiny)
        #expect(clamped.width <= tiny.width || abs(clamped.width - tiny.width) < 0.001)
        #expect(clamped == tiny)
    }
}
