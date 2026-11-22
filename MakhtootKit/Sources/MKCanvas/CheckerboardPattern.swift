#if canImport(UIKit)
import UIKit

// P5.4 (§2.11) "Transparent-canvas checkerboard: present alpha honestly."
// Ground-truth check before writing this (per this session's brief, which
// claimed a checkerboard pattern already shipped for the color picker's
// alpha strip): `grep -rn "Checkerboard\|checkerboard"` across the whole
// repo turns up nothing that is a reusable pattern generator (only an
// unrelated asset-contact-sheet helper and export/font-preview test
// fixtures use the word at all). No prior implementation exists anywhere
// to reuse ، this is the first, canonical one, written so any FUTURE
// consumer (a color-picker alpha strip, etc.) can reuse it instead of
// growing a second one. Presentation only: nothing in `MKRender`/`MKExport`
// references this type, so it can never leak into a rendered bitmap or an
// exported file by construction (not merely by convention).
enum MKCheckerboardPattern {
    /// A small tileable checkerboard `UIColor` built from
    /// `UIColor(patternImage:)`, alternating `light`/`dark` squares of
    /// `squareSize` points. Assigning `.cgColor` to a `CALayer
    /// .backgroundColor` (`MKCanvasViewController.refreshCheckerboard()`
    /// does this for `contentHostView`) paints it behind EVERY sublayer
    /// automatically ، no sublayer-ordering bookkeeping needed, and it
    /// scales naturally with the host view's own zoom transform (D-114's
    /// content-view-is-the-zoomed-view convention), matching how every
    /// mainstream design tool's transparency checkerboard scales with the
    /// canvas rather than staying screen-fixed.
    static func patternColor(
        squareSize: CGFloat = 8,
        light: UIColor = UIColor(white: 0.92, alpha: 1),
        dark: UIColor = UIColor(white: 0.82, alpha: 1)
    ) -> UIColor {
        let tile = CGSize(width: squareSize * 2, height: squareSize * 2)
        let renderer = UIGraphicsImageRenderer(size: tile)
        let image = renderer.image { ctx in
            light.setFill()
            ctx.fill(CGRect(origin: .zero, size: tile))
            dark.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: squareSize, height: squareSize))
            ctx.fill(CGRect(x: squareSize, y: squareSize, width: squareSize, height: squareSize))
        }
        return UIColor(patternImage: image)
    }
}
#endif
