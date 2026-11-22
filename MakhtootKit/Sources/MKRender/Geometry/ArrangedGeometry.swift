import CoreGraphics
import MKFoundation
import MKModel

// WS-07 packet §5 task 2 (`ArrangedDrawer`) / §5 task 12 (`HitTester`'s
// arranged-child hit). ARCHITECTURE §5.3's D-220 normative affine chain,
// implemented once here so `ArrangedDrawer` (rendering) and `HitTester`
// (hit-testing) share exactly one geometry truth ، the packet's own
// framing for this run: "implement the D-220 affine chain now... numeric
// correctness per ARCHITECTURE §11.1."
//
// **Decomposed-ligature geometry (documented judgment call, not spelled
// out verbatim by D-220/§5.3/§7.5):** a `MKLigatureGroup` in `.decomposed`
// state has no single meaningful world frame of its own ، D-108/§7.5 says
// decomposition repositions each CONSTITUENT glyph independently (with
// `fidelityOffsets` baked into `layout.position` by whoever performs the
// decomposition, MKArrange/WS-04, not yet built) and re-points any
// attached marks to the nearest COMPONENT (§7.5 step 6), not the group.
// So `Index` below flattens a decomposed ligature's components into the
// same id space as top-level glyphs (each keyed by its OWN
// `MKGlyphNode.id`), and does NOT expose the group's own id as a
// world-transformable element while decomposed. This means: (a) rendering
// a decomposed ligature draws each component exactly like an independent
// glyph child (§5.3's first bullet: "composition.affine ∘ child.affine"),
// never additionally wrapped in the group's own `transform`/`style`; (b) a
// mark whose `attachedTo` already points at a component id (which MKArrange
// is responsible for setting on decompose, per §7.5 step 6) resolves
// correctly through the same `Index` with no special-casing here.
//
// **Non-following / detached marks (also an extrapolation, not literal
// D-220 text):** D-220's formula is stated only for `followsBase == true`.
// For `followsBase == false` or `attachedTo == nil` (explicit detach, BRIEF:
// "individually selectable/detachable/movable"), this file treats the mark
// like a plain child ، `composition.affine ∘ mark.affine`, no base-relative
// translate ، i.e. `mark.transform.position` becomes an absolute
// composition-space position once detached. This is the only
// self-consistent reading: a detached mark has no base to be base-local
// relative to.
public enum MKArrangedGeometry {
    /// One resolved arranged-composition element, flattening decomposed
    /// ligature components into the same id space as top-level children
    /// (see file-level "Decomposed-ligature geometry" note).
    public enum Element: Sendable {
        case glyph(MKGlyphNode)
        case composedLigature(id: MKNodeID, groupTransform: MKTransform2D, ligature: MKComposedLigature)
        case mark(MKMarkNode)
    }

    /// Built once per composition render/hit-test pass and reused across
    /// per-child lookups (HitTester's per-frame traversal, ArrangedDrawer's
    /// per-child draw loop) rather than re-scanning `composition.nodes`
    /// (and decomposed components) on every lookup.
    public struct Index: Sendable {
        private var table: [MKNodeID: Element] = [:]
        /// Paint order: top-level composition order, with a decomposed
        /// ligature's components spliced in at the group's position
        /// (§7.5's visual-bounds-matching intent keeps them co-located).
        public private(set) var paintOrder: [MKNodeID] = []

        public init(composition: ArrangedComposition) {
            for child in composition.nodes {
                switch child {
                case .glyph(let g):
                    table[g.id] = .glyph(g)
                    paintOrder.append(g.id)
                case .mark(let m):
                    table[m.id] = .mark(m)
                    paintOrder.append(m.id)
                case .ligature(let l):
                    switch l.state {
                    case .composed(let composed):
                        table[l.id] = .composedLigature(id: l.id, groupTransform: l.transform, ligature: composed)
                        paintOrder.append(l.id)
                    case .decomposed(let d):
                        for component in d.components {
                            table[component.id] = .glyph(component)
                            paintOrder.append(component.id)
                        }
                    }
                }
            }
        }

        public func element(id: MKNodeID) -> Element? { table[id] }
    }

    /// §5.3's `base.affine`/`child.affine`: the element's own LOCAL
    /// (composition-space, not yet composed with `composition.affine`)
    /// affine. For a glyph, this is `translate(layout.position) ∘
    /// transform.affine` ، `layout.position` is the shaped placement at
    /// derivation, `transform` is the user's independent per-glyph delta
    /// "on top of layout.position" (`MKGlyphNode.transform` doc comment);
    /// composing them this way means the user delta's own rotation/scale
    /// pivots about `layout.position + transform.position`, matching the
    /// glyph analogue of D-220's mark-pivot semantics ("the mark's own
    /// rotation/scale pivots about the relativeOffset-anchored origin, not
    /// about the mark's own bounds center").
    public static func localAffine(of element: Element) -> CGAffineTransform? {
        switch element {
        case .glyph(let g):
            return CGAffineTransform(translationX: g.layout.position.x, y: g.layout.position.y)
                .concatenating(g.transform.affineTransform)
        case .composedLigature(_, let groupTransform, let ligature):
            return CGAffineTransform(translationX: ligature.layout.position.x, y: ligature.layout.position.y)
                .concatenating(groupTransform.affineTransform)
        case .mark:
            return nil   // marks are never valid attachment bases
        }
    }

    /// §5.3 first bullet: `composition.affine ∘ child.affine` for a
    /// glyph/ligature child (decomposed-ligature constituents take this
    /// same path via `Index`'s flattening ، see file-level note).
    public static func worldTransform(
        ofChild childID: MKNodeID, index: Index, compositionAffine: CGAffineTransform
    ) -> CGAffineTransform? {
        guard let element = index.element(id: childID), let local = localAffine(of: element) else { return nil }
        return local.concatenating(compositionAffine)
    }

    /// §5.3 normative mark chain: `composition.affine ∘ base.affine ∘
    /// translate(relativeOffset) ∘ mark.affine`. `relativeOffset` is
    /// base-local (captured at derivation, before `base.affine` ، D-220),
    /// so it is translated FIRST (innermost), then the whole thing is
    /// carried by `base.affine`, then `composition.affine`. Falls back to
    /// the plain-child path for detached/non-following marks (file-level
    /// note above).
    public static func worldTransform(
        ofMark markID: MKNodeID, index: Index, compositionAffine: CGAffineTransform
    ) -> CGAffineTransform? {
        guard case .mark(let mark) = index.element(id: markID) else { return nil }

        guard
            mark.followsBase,
            let baseID = mark.attachedTo,
            let baseElement = index.element(id: baseID),
            let baseLocal = localAffine(of: baseElement)
        else {
            return mark.transform.affineTransform.concatenating(compositionAffine)
        }

        let offsetTranslate = CGAffineTransform(translationX: mark.relativeOffset.width, y: mark.relativeOffset.height)
        let localChain = mark.transform.affineTransform
            .concatenating(offsetTranslate)
            .concatenating(baseLocal)
        return localChain.concatenating(compositionAffine)
    }

    /// Convenience: world transform for ANY arranged-child id (glyph,
    /// composed ligature, decomposed-ligature component, or mark),
    /// dispatching to the right formula. `HitTester`/`ArrangedDrawer` use
    /// this single entry point rather than switching on `Index.Element`
    /// themselves.
    public static func worldTransform(
        of id: MKNodeID, index: Index, compositionAffine: CGAffineTransform
    ) -> CGAffineTransform? {
        switch index.element(id: id) {
        case .mark: return worldTransform(ofMark: id, index: index, compositionAffine: compositionAffine)
        case .glyph, .composedLigature: return worldTransform(ofChild: id, index: index, compositionAffine: compositionAffine)
        case .none: return nil
        }
    }
}
