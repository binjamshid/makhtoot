import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence

// WS-04 packet §5 tasks 4 + 13. Every arrange mutation is an `MKCommand`
// (WS-02's undo stack, `MKPersistence`) ، this file is the command layer
// every controller in this module (`JoinController`, `LigatureDecomposer`,
// `MarkAttachmentController`, the style/transform edit helpers) builds on.
//
// **RESOLVED (Run-3 session, per WS-02 session 3 / `CONTRACTS.md`'s
// "WS-04 (`MKArrange`) ، arrange-engine contract" adoption row): a single
// mechanism now, not two.** Both node-kind swaps AND composition-internal
// mutations go through `MKPersistence`'s canonical, journal-codable
// catalog ، `MKArrangedCompositionCommand` (the module-local type this
// file used to define, not registrable in `MKCommandCoder`'s closed switch
// since the dependency edge runs `MKArrange → MKPersistence`, never the
// reverse) is RETIRED:
//
// 1. **Node-kind swaps** (`liveText`/`pathText` ⇄ `arranged`, task 4/14):
//    unchanged ، `MKPersistence`'s EXISTING `MKReplaceNodeCommand`, already
//    journal-codable, no migration needed here.
//
// 2. **Composition-internal mutations** (join break/restore, ligature
//    decompose/recompose, mark attach/detach/move, per-node style/
//    transform edits ، tasks 6/7/9/10/11/12/13): every controller now
//    builds a `MKPersistence.MKReplaceNodesCommand` through
//    `ArrangeCommands.replaceComposition(of:with:label:coalescingKeySuffix:)`
//    below ، the FULL replacement `MKArrangedTextNode` (owner's `core` +
//    the new `composition` + the owner's own `derivedFrom`) is captured at
//    command-CONSTRUCTION time (not read back off the scene at apply time,
//    the one semantic difference from the retired type ، see
//    `CONTRACTS.md`'s adoption row: this is safe under journal replay
//    because the `baseRev` chain pins the replay base to the same scene
//    the command was originally built against). Every controller's public
//    "…Command" builder therefore now takes the OWNER's full
//    `MKArrangedTextNode` (`ownerNode:`) instead of a bare `ownerNodeID:`
//    + separately-passed `composition:` ، the composition it mutates is
//    always `ownerNode.composition` anyway, so this is a strict
//    simplification, not just a plumbing change for the migration's sake.
//
// This closes the WS-04 journal gap documented in `docs/impl-log/WS-04.md`
// ("real bugs" §5): crash recovery previously silently lost any in-flight
// join-break/decompose/mark-move/style-edit arrange operation
// (`CommandJournal.append` throws `unknownCommandType`, swallowed by
// `MakhtootDocument.apply`'s `try?`) ، now every arrange operation
// (derive, revert, decompose, recompose, and every composition-internal
// edit) replays byte-identically from the journal. See
// `docs/impl-log/WS-04.md`'s "Session 2" for the adoption record and
// `Tests/MKArrangeTests/JournalRoundTripTests.swift` for the end-to-end
// encode→decode→replay proof.
public enum ArrangeCommands {
    /// Task 4: converts a `.liveText`/`.pathText` node into `.arranged`,
    /// same `MKNodeCore` (transform/z-order/opacity/style/name preserved
    /// verbatim per task 4's accept criterion ، "same transform/z").
    /// Undo restores the EXACT original node (`MKReplaceNodeCommand
    /// .inverse` captures the pre-apply node from the scene, byte-for-byte
    /// ، Equatable, task 4 accept).
    public static func arrangeCommand(
        sourceNodeID: MKNodeID, core: MKNodeCore, composition: ArrangedComposition, derivedFrom origin: MKArrangeOrigin
    ) -> any MKCommand {
        let arrangedNode = MKArrangedTextNode(core: core, composition: composition, derivedFrom: origin)
        return MKReplaceNodeCommand(nodeID: sourceNodeID, newNode: .arranged(arrangedNode))
    }

    /// The composition-internal mutation primitive (see file header,
    /// mechanism 2) ، every controller in this module (`JoinController`,
    /// `FormSelectorModel`, `LigatureDecomposer`, `MarkAttachmentController`,
    /// `ArrangeStyleEditor`) builds its command through this one function.
    /// `newComposition` is always the FULL new composition value (callers
    /// compute it purely); `ownerNode.core`/`ownerNode.derivedFrom` are
    /// carried through unchanged into the replacement node, so this is
    /// exactly "swap `composition`, keep everything else about the owner
    /// node identical" ، the same semantics the retired
    /// `MKArrangedCompositionCommand` had, now expressed as the canonical,
    /// journal-codable `MKReplaceNodesCommand`.
    public static func replaceComposition(
        of ownerNode: MKArrangedTextNode, with newComposition: ArrangedComposition,
        label: String, coalescingKeySuffix: String? = nil
    ) -> any MKCommand {
        let updatedNode = MKArrangedTextNode(core: ownerNode.core, composition: newComposition, derivedFrom: ownerNode.derivedFrom)
        return MKReplaceNodesCommand(
            nodeID: ownerNode.core.id, newNode: .arranged(updatedNode), label: label, coalescingKeySuffix: coalescingKeySuffix)
    }
}

// MARK: - Task 13: per-node style/transform edit helpers

/// Thin, coalescable command builders over one selection of arranged
/// children (glyph/mark/ligature, including decomposed-ligature
/// components) ، the primitive WS-06's inspector bindings call directly
/// (packet: "thin wrappers emitting MKCommands"). Every helper here
/// produces exactly ONE `MKReplaceNodesCommand` (via `ArrangeCommands
/// .replaceComposition`, journal-codable), so a multi-select edit across N
/// children is ALREADY one undo step without needing `MKUndoStack`
/// coalescing (task 13 accept: "multi-select recolor of 3 glyph nodes = 1
/// undo step") ، coalescing keys are still supplied so a CONTINUOUS gesture
/// (a slider being dragged, many `apply` calls in sequence) also collapses
/// to one step.
public enum ArrangeStyleEditor {
    /// Sets `style` (fill/stroke/shadow) on every child in `ids`.
    public static func setStyle(
        _ style: MKStyle, forChildIDs ids: Set<MKNodeID>, ownerNode: MKArrangedTextNode,
        gestureID: UUID = UUID()
    ) -> any MKCommand {
        let newComposition = Self.mapMatching(ids, in: ownerNode.composition) { child in
            switch child {
            case .glyph(var g): g.style = style; return .glyph(g)
            case .mark(var m): m.style = style; return .mark(m)
            case .ligature(var l): l.style = style; return .ligature(l)
            }
        } mappingComponent: { component in
            var c = component
            c.style = style
            return c
        }
        return ArrangeCommands.replaceComposition(
            of: ownerNode, with: newComposition, label: "تنسيق", coalescingKeySuffix: "style:\(gestureID)")
    }

    /// Sets `opacity` (task 13's per-object opacity ، `MKNodeCore.opacity`
    /// is the top-level-node field; arranged CHILDREN don't have a
    /// dedicated opacity field of their own in the D-111 model, so a
    /// per-glyph "opacity" is realized by folding it into `style.fill`'s
    /// alpha channel, the same representation `MKStyle`'s solid-fill color
    /// already carries ، documented, not a silent approximation).
    public static func setOpacity(
        _ opacity: Double, forChildIDs ids: Set<MKNodeID>, ownerNode: MKArrangedTextNode,
        gestureID: UUID = UUID()
    ) -> any MKCommand {
        func applyOpacity(_ style: MKStyle) -> MKStyle {
            var s = style
            if case .solid(var color) = s.fill {
                color.a = opacity
                s.fill = .solid(color)
            }
            return s
        }
        let newComposition = Self.mapMatching(ids, in: ownerNode.composition) { child in
            switch child {
            case .glyph(var g): g.style = applyOpacity(g.style); return .glyph(g)
            case .mark(var m): m.style = applyOpacity(m.style); return .mark(m)
            case .ligature(var l): l.style = applyOpacity(l.style); return .ligature(l)
            }
        } mappingComponent: { component in
            var c = component
            c.style = applyOpacity(c.style)
            return c
        }
        return ArrangeCommands.replaceComposition(
            of: ownerNode, with: newComposition, label: "شفافية", coalescingKeySuffix: "opacity:\(gestureID)")
    }

    /// Sets the per-child `transform` (position/rotation/scale) directly ،
    /// the primitive independent move/rotate/scale/kerning-nudge/baseline-
    /// shift all reduce to (each is "add a delta to one or more transform
    /// fields", computed by the caller before calling this).
    public static func setTransform(
        _ transform: MKTransform2D, forChildID id: MKNodeID, ownerNode: MKArrangedTextNode,
        gestureID: UUID = UUID()
    ) -> any MKCommand {
        let newComposition = Self.mapMatching([id], in: ownerNode.composition) { child in
            switch child {
            case .glyph(var g): g.transform = transform; return .glyph(g)
            case .mark(var m): m.transform = transform; return .mark(m)
            case .ligature(var l): l.transform = transform; return .ligature(l)
            }
        } mappingComponent: { component in
            var c = component
            c.transform = transform
            return c
        }
        return ArrangeCommands.replaceComposition(
            of: ownerNode, with: newComposition, label: "تحريك", coalescingKeySuffix: "transform:\(gestureID)")
    }

    /// Baseline shift (packet: "baseline shift"): adds `delta` points to a
    /// child's `transform.position.y` in composition-local (y-up) space ،
    /// positive `delta` moves the glyph UP, matching `MKTextStyle
    /// .baselineShift`'s own documented sign convention ("positive =
    /// upward").
    public static func nudgeBaseline(
        by delta: CGFloat, forChildID id: MKNodeID, ownerNode: MKArrangedTextNode,
        gestureID: UUID = UUID()
    ) -> any MKCommand {
        Self.nudgePosition(by: CGSize(width: 0, height: delta), forChildID: id, ownerNode: ownerNode, gestureID: gestureID)
    }

    /// Kerning-like nudge (packet: "kerning-like nudge (position deltas)"):
    /// adds `delta` to a child's `transform.position` in composition-local
    /// space.
    public static func nudgePosition(
        by delta: CGSize, forChildID id: MKNodeID, ownerNode: MKArrangedTextNode,
        gestureID: UUID = UUID()
    ) -> any MKCommand {
        func applyDelta(_ t: MKTransform2D) -> MKTransform2D {
            var t = t
            t.position.x += delta.width
            t.position.y += delta.height
            return t
        }
        let newComposition = Self.mapMatching([id], in: ownerNode.composition) { child in
            switch child {
            case .glyph(var g): g.transform = applyDelta(g.transform); return .glyph(g)
            case .mark(var m): m.transform = applyDelta(m.transform); return .mark(m)
            case .ligature(var l): l.transform = applyDelta(l.transform); return .ligature(l)
            }
        } mappingComponent: { component in
            var c = component
            c.transform = applyDelta(c.transform)
            return c
        }
        return ArrangeCommands.replaceComposition(
            of: ownerNode, with: newComposition, label: "إزاحة", coalescingKeySuffix: "nudge:\(id)")
    }

    /// Applies `mapTop` to every TOP-LEVEL child whose id is in `ids`, and
    /// `mapComponent` to every DECOMPOSED-ligature component whose id is in
    /// `ids` (nested one level inside `MKLigatureGroup.state.decomposed`) ،
    /// so style/transform edit helpers reach constituents after a
    /// decompose without special-casing at every call site above.
    private static func mapMatching(
        _ ids: Set<MKNodeID>, in composition: ArrangedComposition,
        _ mapTop: (MKArrangedChild) -> MKArrangedChild,
        mappingComponent mapComponent: (MKGlyphNode) -> MKGlyphNode
    ) -> ArrangedComposition {
        var copy = composition
        copy.nodes = copy.nodes.map { child -> MKArrangedChild in
            if ids.contains(child.id) {
                return mapTop(child)
            }
            if case .ligature(var group) = child, case .decomposed(var decomposed) = group.state {
                var touched = false
                decomposed.components = decomposed.components.map { component in
                    guard ids.contains(component.id) else { return component }
                    touched = true
                    return mapComponent(component)
                }
                if touched {
                    group.state = .decomposed(decomposed)
                    return .ligature(group)
                }
            }
            return child
        }
        return copy
    }
}
