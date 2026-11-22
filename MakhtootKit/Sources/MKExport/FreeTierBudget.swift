import CoreGraphics

// WS-08 packet §5 task 6. `effectivePixelBudget = 2_000_000`; free-export
// sizes scaled down aspect-preserving to fit; actual size reported.
// *Accept*: "1080×1080 untouched; 4096×4096 → ~1414×1414; aspect-
// preservation property test."
public enum MKFreeTierBudget {
    public static let effectivePixelBudget = 2_000_000

    /// Aspect-preserving downscale of `size` so `width × height ≤ budget`.
    /// Sizes already within budget are returned UNCHANGED (task 6 accept:
    /// "1080×1080 untouched") ، never upscaled, never nudged for parity.
    /// Degenerate (`<= 0`) dimensions pass through unchanged (callers
    /// reject degenerate sizes earlier, at the gate/coordinator layer).
    public static func clamped(_ size: CGSize, budget: Int = effectivePixelBudget) -> CGSize {
        guard size.width > 0, size.height > 0 else { return size }
        let area = Double(size.width) * Double(size.height)
        guard area > Double(budget) else { return size }
        let factor = (Double(budget) / area).squareRoot()
        return CGSize(width: size.width * factor, height: size.height * factor)
    }

    /// Whether `clamped(size:)` would change `size` (i.e. `size` exceeds
    /// the budget) ، used by `ExportGate`/`ExportCoordinator` to decide
    /// whether a `.downscaledForFreeTierBudget` `FallbackNote` is owed
    /// (Q73: "never silent" extends to this clamp too).
    public static func exceedsBudget(_ size: CGSize, budget: Int = effectivePixelBudget) -> Bool {
        guard size.width > 0, size.height > 0 else { return false }
        return Double(size.width) * Double(size.height) > Double(budget)
    }
}
