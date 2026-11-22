import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence

// MASTER-PLAN §2.3 "Editing operations" (P6): Copy/Paste, Select All/
// Deselect All, Flip Horizontal/Vertical. Split the same way `KeyCommands
// .swift` already splits `NudgeController` (headless, UIKit-free, directly
// unit-testable on the `swift test` macOS host per `Package.swift`'s
// `platforms:` note) from `MKCanvasKeyCommands` (the thin `#if
// canImport(UIKit)` glue): everything above the `#if canImport(UIKit)`
// block below is pure `CanvasSession`/`MKModel` logic ، no `UIPasteboard`,
// so `MKCanvasTests` exercises the real fresh-id/offset/undo/malformed-
// payload behavior directly, not a mock of the system pasteboard. Only the
// literal "read/write `UIPasteboard.general`" glue is UIKit-gated.

// MARK: - Select All / Deselect All

public extension CanvasSession {
    /// Selects every top-level, selectable node (packet: "respect the
    /// existing selectability rules"). Deliberately routed through
    /// `setSelection(_:)`, NOT `setSelectionFromLayersPanel(_:)`: Select All
    /// is a CANVAS-level command (the toolbar "···" menu / a keyboard
    /// shortcut over the canvas, exactly where Delete/Group/Duplicate
    /// already live in that same menu, `ToolRailView.swift`), not the
    /// layers-panel management surface `setSelectionFromLayersPanel`
    /// exists for ، so it must skip locked/hidden nodes the same way a
    /// canvas marquee-select-all would, per `isSelectable(_:)`'s own doc
    /// comment ("locked... skipped by tap/marquee selection... selectable
    /// from the layers panel"). `setSelection` already runs every id
    /// through that exact filter (`sanitized(_:)`), so this is a one-line
    /// composition, not new selection-policy code.
    func selectAll() {
        setSelection(Set(scene.nodes.map(\.id)))
    }

    /// `CanvasSession.clearSelection()` (`CanvasSession.swift`) already IS
    /// Deselect All's primitive (used today by the empty-canvas tap and
    /// Arrange-mode reset) ، no new selection-model code, only the new
    /// trigger surfaces (menu item + keyboard shortcut, wired in
    /// `ToolRailView.swift`/`KeyCommands.swift`). This thin alias exists
    /// only so call sites read as intent ("deselect all") rather than the
    /// lower-level "clear selection" a reader would otherwise have to infer
    /// is the same thing.
    func deselectAll() {
        clearSelection()
    }
}

// MARK: - Flip Horizontal / Vertical

public extension CanvasSession {
    /// Which axis a flip mirrors across, in the node's own LOCAL (pre-
    /// rotation) frame ، matches `MKTransform2D`'s documented composition
    /// order (scale → rotate → translate), so flipping is correct
    /// regardless of the node's current rotation.
    enum FlipAxis: Sendable { case horizontal, vertical }

    /// Mirrors every selected, unlocked node across `axis` by negating the
    /// corresponding `MKTransform2D.scale` component (packet: "a sign
    /// change on `MKTransform2D.scale`"). One `MKTransformCommand` per
    /// node, matching `deleteSelection()`/`EditorViewModel
    /// .toggleLockForSelection()`'s own established "loop selection, one
    /// `perform` per node, skip locked" shape for bulk selection actions ،
    /// NOT wrapped in a single `beginGesture()/endGesture()` bracket, so a
    /// multi-node flip needs one Undo per node to fully revert, exactly
    /// like a multi-node Delete already does today. This keeps the new
    /// operation consistent with the codebase's own existing convention
    /// for bulk selection commands rather than introducing a second,
    /// differently-scoped "one undo step for N nodes" convention that only
    /// Flip would follow.
    ///
    /// Rendering/hit-testing/export were audited for the negative-scale
    /// assumption this introduces for the first time in this codebase (see
    /// `MKStylePainting.paint(strokeWidthCompensationScale:)`,
    /// `MKOrientedRect.init(localBounds:transform:)`, `HitTester`, and
    /// `SVGSerializer`) ، see this session's report for the findings; the
    /// one real gap found (`HandleGestures.updateResize`/`updateRotate`
    /// silently discarding a flip's sign on the NEXT resize/rotate, since
    /// `MKOrientedRect.derivingTransform(localBounds:)` only ever
    /// synthesizes non-negative scale) is fixed in that file, not here.
    func flipSelection(axis: FlipAxis) throws {
        for id in selection.ids {
            guard let node = scene.node(id: id), !node.core.isLocked else { continue }
            var transform = node.core.transform
            switch axis {
            case .horizontal: transform.scale.width = -transform.scale.width
            case .vertical: transform.scale.height = -transform.scale.height
            }
            try perform(MKTransformCommand(nodeID: id, newTransform: transform))
        }
    }

    /// Mirrors the WHOLE composition across the canvas's own centre line ،
    /// every top-level node's PLACEMENT is reflected, not merely each
    /// object flipped where it stands.
    ///
    /// This is the operation `flipSelection(axis:)` above is repeatedly
    /// mistaken for (user report, 2026-07-29: "no way to flip/mirror a
    /// project"). Select-All-then-flip is NOT the same thing: that negates
    /// each node's own scale and leaves all of them exactly where they
    /// were, so a design whose title sits top-right still has its title
    /// top-right afterwards, each letter individually back-to-front. A
    /// real mirror moves the title to the top-LEFT.
    ///
    /// Math: reflecting about `x = cx` is `M = translate(cx) ∘ scale(-1,1)
    /// ∘ translate(−cx)`. Composing that onto a node's transform `T: p ↦
    /// R(θ)·S·p + t` and re-decomposing (`D = diag(−1, 1)`, and `D·R(θ)·D
    /// = R(−θ)`, with `D`/`S` both diagonal so they commute) gives exactly
    /// three field edits: negate the axis's `scale` component, negate
    /// `rotation`, and reflect that axis of `position` about the canvas
    /// centre. Vertical is the same with `D = diag(1, −1)`.
    ///
    /// Bracketed in one `beginGesture()`/`endGesture()` pair with a single
    /// `MKBatchTransformCommand`, so ONE Undo restores the whole
    /// composition. This deliberately differs from `flipSelection`'s
    /// per-node convention: that one mirrors the "bulk action over a
    /// selection" shape Delete/Lock already use, whereas this is a single
    /// document-level transform, and unwinding it N steps at a time would
    /// be indefensible.
    ///
    /// Locked nodes are INCLUDED, also deliberately and also unlike
    /// `flipSelection`. A lock guards a node against being edited
    /// individually; skipping it here would not protect it, it would
    /// silently produce a half-mirrored, broken composition ، a worse
    /// outcome than the one the lock exists to prevent.
    ///
    /// The background (`MKBackgroundNode`) is not transformed: it is
    /// canvas-filling by definition and ignores its own transform (see
    /// `BackgroundDrawer`), so there is nothing to mirror. A `.cover`
    /// photo background therefore stays as it is; only the design on top
    /// of it mirrors.
    func flipScene(axis: FlipAxis) throws {
        let canvasSize = scene.canvas.size
        guard canvasSize.width > 0, canvasSize.height > 0, !scene.nodes.isEmpty else { return }
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

        var newTransforms: [MKNodeID: MKTransform2D] = [:]
        for node in scene.nodes {
            var transform = node.core.transform
            transform.rotation = -transform.rotation
            switch axis {
            case .horizontal:
                transform.scale.width = -transform.scale.width
                transform.position.x = 2 * center.x - transform.position.x
            case .vertical:
                transform.scale.height = -transform.scale.height
                transform.position.y = 2 * center.y - transform.position.y
            }
            newTransforms[node.id] = transform
        }
        guard !newTransforms.isEmpty else { return }

        beginGesture()
        defer { endGesture() }
        try perform(MKBatchTransformCommand(gestureID: UUID(), newTransforms: newTransforms))
    }
}

// MARK: - Copy / Paste

/// Thrown by `CanvasSession.paste(from:)` when the pasteboard held no data,
/// data in an unrecognized/foreign shape, or a payload from a newer/older
/// schema version this build doesn't understand ، the "malformed/foreign
/// payload case without crashing" the packet calls out explicitly (a
/// cross-app paste of, say, plain image/text data landing on the SAME
/// custom UTI would never happen since the type identifier is private to
/// this app, but a stale payload from a pre-P6 build, or this app's own
/// future format, both decode to this instead of a crash).
public enum MKPasteError: Error, Sendable {
    case emptyOrMalformedPayload
}

/// The pasteboard wire payload: `MKNode`'s existing `Codable` conformance
/// (`MKModel/MKNode.swift`) needs no new model code, per the packet's own
/// "viable as a pasteboard payload with no model work" note ، this envelope
/// only adds a schema-version tag so a future format change can be
/// detected and rejected cleanly instead of decoding into garbage.
struct MKNodesPasteboardPayload: Codable {
    static let currentSchemaVersion = 1
    var schemaVersion: Int
    var nodes: [MKNode]

    init(nodes: [MKNode]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.nodes = nodes
    }
}

public extension CanvasSession {
    /// Private (app-specific) pasteboard type identifier, following the
    /// document UTI's own `net.binjamshid.makhtoot.project` reverse-DNS
    /// convention (packet instruction) ، deliberately NOT a public plain-
    /// text/image UTI, so this app's copied nodes never show up as a
    /// pastable "image"/"text" in other apps, and other apps' pasteboard
    /// contents never get misinterpreted as node data here.
    static let nodesPasteboardType = "net.binjamshid.makhtoot.project.nodes"

    /// World-space offset applied to every pasted node so a paste is
    /// visibly distinct from its source (packet: "offset the pasted nodes
    /// slightly"), matching the on-canvas nudge unit `NudgeController
    /// .normalStep` already establishes for "one visible step" elsewhere in
    /// this same file's neighborhood (`KeyCommands.swift`), scaled up
    /// slightly (12 pt) so the offset reads clearly at typical canvas zoom
    /// even for small nodes, without the paste landing far enough away to
    /// feel disconnected from the copied selection.
    private static var pasteOffset: CGPoint { CGPoint(x: 12, y: 12) }

    /// Encodes the current selection's TOP-LEVEL nodes (scene paint order)
    /// as pasteboard-ready `Data`, or `nil` when there is nothing
    /// selectable to copy. Headless (no `UIPasteboard`) so it is directly
    /// unit-testable and reusable by whichever glue writes the bytes
    /// somewhere (`copySelectionToPasteboard()` below, or a future share-
    /// sheet/drag-and-drop source).
    func copySelectionPayloadData() -> Data? {
        let orderedIDs = scene.nodes.map(\.id).filter { selection.ids.contains($0) }
        let nodes = orderedIDs.compactMap { scene.node(id: $0) }
        guard !nodes.isEmpty else { return nil }
        return try? JSONEncoder().encode(MKNodesPasteboardPayload(nodes: nodes))
    }

    /// Decodes `data` (as produced by `copySelectionPayloadData()`, from
    /// THIS session or a different document entirely ، the packet's
    /// "handle the cross-document case" requirement, satisfied trivially
    /// since nothing here reads `document`/`scene` to decode, only to
    /// insert), mints a FRESH `MKNodeID` for every node (and every arranged
    /// descendant, cross-references remapped ، `LayersModel
    /// .reassigningIDs(_:)`, reused rather than reimplemented) so paste
    /// never collides with or replaces the copied originals — including
    /// after the originals were deleted (nothing here looks the source ids
    /// up in `scene` at all), offsets each pasted node by `pasteOffset`,
    /// inserts them all as ONE `MKInsertNodesCommand` (one undo step, the
    /// packet's "undoable as a single step" requirement), and selects the
    /// new nodes.
    ///
    /// Throws `MKPasteError.emptyOrMalformedPayload` rather than silently
    /// doing nothing on bad input, so a caller (e.g. a future "paste
    /// failed" toast) can distinguish "nothing to paste" from "pasted
    /// nothing because the selection was empty at copy time" if it ever
    /// needs to; `EditorViewModel`'s call site below simply discards the
    /// error (`try?`), matching every other `CanvasSession` mutator's
    /// established `try?`-at-the-view-model-boundary convention
    /// (`EditorViewModel.deleteSelection()` etc.).
    func paste(from data: Data) throws {
        guard let payload = try? JSONDecoder().decode(MKNodesPasteboardPayload.self, from: data),
              payload.schemaVersion == MKNodesPasteboardPayload.currentSchemaVersion,
              !payload.nodes.isEmpty
        else {
            throw MKPasteError.emptyOrMalformedPayload
        }
        let offset = Self.pasteOffset
        let freshNodes = payload.nodes.map { node -> MKNode in
            let fresh = LayersModel.reassigningIDs(node)
            var core = fresh.core
            core.transform.position.x += offset.x
            core.transform.position.y += offset.y
            return fresh.withCore(core)
        }
        try perform(MKInsertNodesCommand(nodes: freshNodes))
        setSelection(Set(freshNodes.map(\.id)))
    }
}

// MARK: - Merge Design (P7.4, §2.2)

public extension CanvasSession {
    /// Imports every top-level node from ANOTHER saved project's package
    /// into the CURRENT scene. Reuses the exact package-reading primitive
    /// (`DocumentPackage.readScene()`) every other read path already uses
    /// ، no new persistence code, matching the packet's "reuse the existing
    /// package-reading path" instruction literally.
    ///
    /// Mints a FRESH `MKNodeID` for every merged node (and its arranged
    /// descendants, cross-references remapped) via the SAME
    /// `LayersModel.reassigningIDs(_:)` helper `paste(from:)` above uses ،
    /// the packet's own "same requirement as P6's paste" note: two
    /// documents' nodes must never collide on id once combined into one
    /// scene. Inserted as ONE `MKInsertNodesCommand` (one undo step) and
    /// the merged nodes become the new selection, mirroring `paste(from:)`'s
    /// UX shape exactly ، a merge IS conceptually "paste from a different
    /// document" rather than the system pasteboard. Reusing that exact
    /// command type means the system Undo menu labels this step "لصق"
    /// (paste) rather than a merge-specific string; accepted as a known,
    /// minor label imprecision rather than forking a byte-identical command
    /// type solely to rename it.
    ///
    /// No-ops (via `try?` at the call site, matching every other
    /// `CanvasSession` mutator's established convention) if `url` is not a
    /// real, readable `.makhtoot` package, or if its scene has no nodes to
    /// merge.
    func mergeDesign(fromPackageAt url: URL) throws {
        let package = DocumentPackage(rootURL: url)
        let sourceScene = try package.readScene()
        guard !sourceScene.nodes.isEmpty else { return }
        let freshNodes = sourceScene.nodes.map { LayersModel.reassigningIDs($0) }
        try perform(MKInsertNodesCommand(nodes: freshNodes))
        setSelection(Set(freshNodes.map(\.id)))
    }
}

#if canImport(UIKit)
import UIKit

/// The actual `UIPasteboard` glue (packet: "Use `UIPasteboard` with a
/// custom private type identifier"). Kept to exactly two one-line methods
/// so the substantive logic above (encode/decode/reassign/offset/select)
/// stays UIKit-free and testable on the `swift test` macOS host ، mirrors
/// `KeyCommands.swift`'s own `#if canImport(UIKit)` split for
/// `MKCanvasKeyCommands`.
@MainActor
public extension CanvasSession {
    /// No-ops when the selection is empty (`copySelectionPayloadData()`
    /// returns `nil`) rather than clearing whatever the pasteboard already
    /// held ، matches every OS's own "copy with nothing selected does
    /// nothing" convention.
    func copySelectionToPasteboard(_ pasteboard: UIPasteboard = .general) {
        guard let data = copySelectionPayloadData() else { return }
        pasteboard.setData(data, forPasteboardType: Self.nodesPasteboardType)
    }

    /// No-ops (via `try?`) on an empty pasteboard, a foreign app's data
    /// under a colliding type (not realistic given the private UTI, but
    /// guarded anyway), or a malformed/future-schema payload ، the packet's
    /// "without crashing" requirement.
    func pasteFromPasteboard(_ pasteboard: UIPasteboard = .general) {
        guard let data = pasteboard.data(forPasteboardType: Self.nodesPasteboardType) else { return }
        try? paste(from: data)
    }
}
#endif
