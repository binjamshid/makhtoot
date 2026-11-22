import CoreGraphics
import MKModel

// WS-07 packet §5 task 2/3. Shared fill/stroke/shadow application every
// drawer uses on its own content path ، one place implementing
// ARCHITECTURE §6 Arabic-correctness's "shadow applied per node,
// documented" rule (no double-darkening of overlapping mark/base shadows:
// each node gets its OWN `beginTransparencyLayer`/shadow state, never a
// shared/accumulated one) and §11.4's degradation-ladder shadow
// simplification (`.reduced` fidelity: flat offset fill at 30% alpha, no
// blur, no transparency layer).

public enum MKStylePainting {
    /// Fills+strokes `path` per `style`, honoring shadow + the current
    /// `MKRenderQuality` fidelity's shadow simplification. Does NOT apply
    /// `opacity` (that's a `SceneRenderer`-level transparency-layer
    /// concern spanning potentially multiple sub-draws of one node, e.g.
    /// an arranged composition's many children under one node opacity ،
    /// see `SceneRenderer.swift`).
    ///
    /// - Parameter strokeWidthCompensationScale: P14 hardening pass
    ///   (docs/impl-log/WS-07-p14-run3.md, item 4 ، the stroke-width
    ///   scaling fix `docs/impl-log/WS-08.md`'s "Fixture-authoring pitfall"
    ///   section flagged and filed a `spawn_task` suggestion for). Root
    ///   cause: `SceneRenderer` concatenates a shape node's own
    ///   `transform.scale` onto `ctx` BEFORE this function runs (so
    ///   `ShapeDrawer`'s unit-square `-0.5...0.5` geometry becomes the
    ///   node's real on-canvas size) ، but `ctx.setLineWidth` sets the
    ///   width in that SAME scaled user space, so CoreGraphics scales the
    ///   STROKE THICKNESS by the shape's box size too (a `width: 3` on a
    ///   320×160 box stroked at ~960pt ، WS-08's own repro). Callers whose
    ///   node scale is exactly this "box size" scale (currently only
    ///   `ShapeDrawer`, for `MKShapeGeometry`) pass it here so the width is
    ///   divided back out, making `stroke.width` mean an absolute document-
    ///   point value regardless of the shape's box dimensions ، the
    ///   "chosen as if they were absolute document points" expectation
    ///   WS-08's fixture author already had. Uses the geometric mean of the
    ///   two axes (`sqrt(|sx·sy|)`) for non-uniform scale, since CoreGraphics
    ///   line width itself has no separate per-axis component to correct
    ///   independently. Defaults to `(1, 1)` (no compensation) ، the
    ///   pre-existing behavior for every other caller (`ArrangedDrawer`'s
    ///   glyph/mark/ligature outlines, where a stroke naturally scaling with
    ///   font point size IS the desired behavior, a different scaling
    ///   domain WS-08's finding never reported a defect against).
    ///   **Known limitation, not covered by this fix**: only cancels the
    ///   PAINTED node's own transform ، a shape nested inside a scaled
    ///   `.group` still inherits the ancestor group's uncompensated scale
    ///   on its stroke, matching WS-08's own repro scope (a single
    ///   top-level shape, no group nesting) but not a fully general fix;
    ///   flagged here for whoever next touches `SceneRenderer`'s group
    ///   recursion.
    public static func paint(
        path: CGPath, style: MKStyle, quality: MKRenderQuality, in ctx: CGContext,
        strokeWidthCompensationScale: CGSize = CGSize(width: 1, height: 1)
    ) {
        let hasShadow = style.shadow != nil
        let needsShapeLayer = hasShadow

        if needsShapeLayer {
            ctx.saveGState()
            applyShadow(style.shadow, quality: quality, in: ctx)
        }

        switch style.fill {
        case .none:
            break
        case .solid(let color):
            ctx.setFillColor(color.cgColor)
            ctx.addPath(path)
            ctx.fillPath()
        }

        if let stroke = style.stroke {
            let rawScaleFactor = (strokeWidthCompensationScale.width * strokeWidthCompensationScale.height).magnitude.squareRoot()
            // Guard against a degenerate (zero/near-zero) node scale: fall
            // back to NO compensation rather than dividing by ~0 and
            // producing an enormous or infinite line width.
            let scaleFactor = rawScaleFactor > .ulpOfOne ? rawScaleFactor : 1
            ctx.setStrokeColor(stroke.color.cgColor)
            ctx.setLineWidth(CGFloat(stroke.width) / scaleFactor)
            ctx.setLineJoin(stroke.join.cgLineJoin)
            ctx.setLineCap(stroke.cap.cgLineCap)
            ctx.addPath(path)
            ctx.strokePath()
        }

        if needsShapeLayer {
            ctx.restoreGState()
        }
    }

    /// `.full` fidelity: real CG shadow (blurred, offset, correct alpha) ،
    /// `ctx.setShadow` applies to the NEXT fill/stroke only, which is
    /// exactly the single fill+stroke this function brackets, so no
    /// transparency layer is needed to prevent the shadow from re-applying
    /// to both (§6 Arabic-correctness: "shadow applied per node").
    /// `.reduced` fidelity (§11.4): "simplified shadows ، flat offset fill
    /// at 30% alpha, no blur" ، drawn as a second flat-color fill of the
    /// same path, offset, UNDER the real content (approximated here by
    /// drawing it first, before the real fill/stroke happens in the
    /// caller).
    private static func applyShadow(_ shadow: MKShadow?, quality: MKRenderQuality, in ctx: CGContext) {
        guard let shadow else { return }
        switch quality.fidelity {
        case .full:
            ctx.setShadow(
                offset: shadow.offset,
                blur: CGFloat(shadow.blur),
                color: shadow.color.cgColor
            )
        case .reduced:
            // Flat, unblurred approximation drawn directly (not via
            // ctx.setShadow, which would still blur) ، caller's own
            // fill/stroke happens after this returns, compositing on top.
            // Intentionally NOT wrapped in its own path fill here since
            // the caller hasn't set the path yet at this call site; see
            // `paintReducedShadow` used by callers that need the flat
            // fallback drawn against their OWN path before painting.
            break
        }
    }

    /// `.reduced`-fidelity flat shadow fallback, drawn explicitly against
    /// `path` (offset copy, 30% alpha, no blur) ، called by drawers BEFORE
    /// `paint(path:style:quality:in:)` when `quality.fidelity == .reduced`
    /// and `style.shadow != nil`, since (unlike the `.full` `ctx.setShadow`
    /// path) the flat fallback needs its own explicit fill of an offset
    /// path copy.
    public static func paintReducedShadowIfNeeded(path: CGPath, style: MKStyle, quality: MKRenderQuality, in ctx: CGContext) {
        guard quality.fidelity == .reduced, let shadow = style.shadow else { return }
        ctx.saveGState()
        var offsetTransform = CGAffineTransform(translationX: shadow.offset.width, y: -shadow.offset.height)
        if let offsetPath = path.copy(using: &offsetTransform) {
            ctx.addPath(offsetPath)
            ctx.setFillColor(shadow.color.cgColor.copy(alpha: 0.3) ?? shadow.color.cgColor)
            ctx.fillPath()
        }
        ctx.restoreGState()
    }
}

extension MKSolidColor {
    /// sRGB `CGColor` (D-117: working space = extended sRGB; document
    /// stores plain sRGB components).
    public var cgColor: CGColor {
        CGColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }
}

extension MKLineJoin {
    var cgLineJoin: CGLineJoin {
        switch self {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel
        }
    }
}

extension MKLineCap {
    var cgLineCap: CGLineCap {
        switch self {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }
}
