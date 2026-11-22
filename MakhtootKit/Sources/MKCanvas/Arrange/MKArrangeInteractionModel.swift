import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence
import MKRender
import Observation

// WS-06 packet §5 task 15 ("Arrange mode UX", deferred to this run ،
// `docs/impl-log/WS-06.md`'s task table + `docs/impl-log/WS-04.md`'s
// "Deferred to next slice"). PRD §6/§7/§8, ARCHITECTURE §5-§7/§10.3.
//
// Headless (`@Observable`, zero UIKit) interaction spine for Arrange Mode ،
// same architectural role `LayersModel`/`InspectorModel` already play for
// their own surfaces: `CanvasSession` holds a plain reference, SwiftUI/
// UIKit both bind to this, gesture code (`GestureCoordinator`) calls into
// it. Every mutation funnels through `session.perform(_:)` (the same
// journal/undo-stack path every other canvas command already uses ، R-4.19
// "undo restores the entire arrangement" falls out for free since arrange
// commands are ordinary `MKCommand`s on the SAME `MKUndoStack`).
@MainActor
@Observable
public final class MKArrangeInteractionModel {
    public let session: CanvasSession

    /// Injected by the app layer once `MKArrange` is reachable (mirrors
    /// `CanvasSession.geometrySource`/`.renderBridge`'s own injection
    /// pattern) ، `weak` since the adapter, not this model, owns its
    /// lifetime.
    public weak var engine: (any MKArrangeEngineProviding)?

    /// R-6.4's level toggle. FL-4 step 3: "Level defaults to 'أشكال'
    /// (glyphs)" on every fresh entry into Arrange Mode.
    public private(set) var granularity: MKSelectionGranularity = .glyph

    public private(set) var lastErrorMessage: String?

    /// True while an `enterArrangeMode` derive is in flight (Bug 16 follow-
    /// up: a long string's derive is not instantaneous, and until this
    /// property existed there was no way for the UI to distinguish "still
    /// working" from "the wand did nothing"). Drives the wand button's
    /// progress indicator.
    public private(set) var isDeriving = false

    /// The in-flight derive `Task`, tracked so a second `enterArrangeMode`
    /// call (double-tapping the wand while a derive is still running) can
    /// supersede it. `.cancel()` alone is best-effort here: `ArrangeDeriver
    /// .derive` (`MKArrange`, frozen/fidelity-tested surface, deliberately
    /// NOT touched by this fix) never calls `Task.checkCancellation`, so a
    /// cancelled task's underlying CoreText/outline work still runs to
    /// completion in the background. `deriveGeneration` below is what
    /// actually guarantees only the LATEST tap's result is ever applied.
    private var deriveTask: Task<(any MKCommand)?, Error>?
    /// Monotonic counter identifying the current (latest) derive attempt.
    private var deriveGeneration = 0

    private var tapCycleState = MKHitTestPolicy.TapCycleState()
    private var moveGestureID: UUID?

    public init(session: CanvasSession) {
        self.session = session
    }

    // MARK: - Active composition (mirrors `MKCanvasMode.scopedNodeID`)

    public var isActive: Bool {
        if case .arrange = session.mode { return true }
        return false
    }

    public var activeOwnerNodeID: MKNodeID? {
        guard case .arrange(let id) = session.mode else { return nil }
        return id
    }

    public var activeOwnerNode: MKArrangedTextNode? {
        guard let id = activeOwnerNodeID, case .arranged(let n)? = session.scene.node(id: id) else { return nil }
        return n
    }

    // MARK: - Entry / exit (R-6.1, R-6.10)

    /// Enters Arrange Mode on `nodeID` (packet task 15 accept: "mode toggle
    /// on selected text object"). If the node is already `.arranged`,
    /// this is a pure mode transition (R-6.10: "entering Arrange Mode again
    /// resumes per-node editing with all prior adjustments intact") ، no
    /// command, no re-derivation (R-6.3: never implicitly reshape). If it
    /// is `.liveText`/`.pathText`, derives fresh via `engine
    /// .deriveArrangeCommand` (R-6.1: "confirmation-free immediate
    /// derivation ، entry is non-destructive").
    public func enterArrangeMode(nodeID: MKNodeID) async {
        lastErrorMessage = nil
        guard let node = session.scene.node(id: nodeID) else {
            // Previously a silent no-op (Bug 16): the selection referenced
            // a node no longer in the scene (e.g. a race with a concurrent
            // delete). Every disabled/refused control states why.
            lastErrorMessage = nodeNotFoundMessage
            return
        }
        switch node {
        case .arranged:
            break
        case .liveText, .pathText:
            guard let engine else {
                lastErrorMessage = arrangeEngineUnavailableMessage
                return
            }
            guard let sourceLength = Self.sourceTextLength(of: node), sourceLength <= Self.deriveCharacterGuard else {
                lastErrorMessage = deriveTooLongMessage
                return
            }
            // A second entry attempt (double-tap the wand) while a derive
            // is still in flight supersedes the stale one ، see
            // `deriveTask`/`deriveGeneration`'s own doc comments for why
            // this is a generation counter, not reliance on
            // `CancellationError`.
            deriveTask?.cancel()
            deriveGeneration += 1
            let generation = deriveGeneration
            isDeriving = true
            let scene = session.scene
            let task = Task { try await engine.deriveArrangeCommand(sourceNodeID: nodeID, in: scene) }
            deriveTask = task
            let outcome: Result<(any MKCommand)?, Error>
            do {
                outcome = .success(try await task.value)
            } catch {
                outcome = .failure(error)
            }
            guard generation == deriveGeneration else {
                // Superseded by a newer tap while this one was awaiting ،
                // discarded silently: nothing about THIS derivation failed,
                // it simply lost the race, and `isDeriving`/`deriveTask`
                // belong to whichever generation is still current.
                return
            }
            isDeriving = false
            deriveTask = nil
            switch outcome {
            case .success(let command):
                guard let command else {
                    lastErrorMessage = deriveFailedMessage
                    return
                }
                do {
                    try session.perform(command)
                    // P-1: fresh derivation just replaced this node's
                    // composition wholesale ، bump so `MKLayerTreeController`
                    // never reuses a pre-derive cached hash for this id.
                    MKCompositionRevision.bump(nodeID)
                } catch {
                    lastErrorMessage = deriveFailedMessage
                    return
                }
            case .failure:
                lastErrorMessage = deriveFailedMessage
                return
            }
        default:
            // groups/shapes/images/background have no Arrange Mode (R-6.1
            // scope) ، previously a silent no-op.
            lastErrorMessage = noArrangeModeForNodeKindMessage
            return
        }
        granularity = .glyph
        session.mode = .arrange(nodeID: nodeID)
        session.setArrangeChildSelection([], granularity: .glyph, compositionScope: nodeID)
    }

    /// The exact source-text length `enterArrangeMode`'s size guard checks
    /// (UTF-16 count, matching `MKSourceText`/Swift `String` conventions
    /// elsewhere in this codebase). `nil` for node kinds the guard doesn't
    /// apply to (`.arranged` never derives; anything else already fails the
    /// `default:` case above).
    private static func sourceTextLength(of node: MKNode) -> Int? {
        switch node {
        case .liveText(let n): return n.text.string.utf16.count
        case .pathText(let n): return n.text.string.utf16.count
        default: return nil
        }
    }

    /// Generous upper bound on source-text length for a single Arrange-Mode
    /// derive (Bug 16 follow-up). `MKSignpost.arrangeDerive`'s own
    /// documented budget is "<100 ms for a 500-glyph composition"
    /// (`MKFoundation/MKLog.swift`) ، this guard sits an order of magnitude
    /// above that (whole paragraphs of Arabic text, not a realistic single
    /// design-canvas text object), so it only ever refuses genuinely
    /// pathological input, never a normal poster/logo/heading use case.
    private static let deriveCharacterGuard = 5000

    /// Clears a surfaced `lastErrorMessage` (dismiss action for whatever UI
    /// displays it ، `MKBanner`'s tap-to-dismiss in this codebase's case).
    public func dismissError() {
        lastErrorMessage = nil
    }

    /// A refusal the CALLER detected before `enterArrangeMode(nodeID:)`
    /// could even be reached ، i.e. there was no single node id to pass.
    /// Exists so the app layer's Arrange-Mode entry point has the same
    /// "every refusal states why" guarantee this model already gives its
    /// own internal ones, instead of returning silently and leaving a
    /// dimmed wand button as the only feedback (user report, 2026-07-29:
    /// "the wand button is very buggy and unclear in its function").
    public enum ArrangeEntryRefusal: Sendable {
        case nothingSelected
        case multipleSelected
    }

    public func reportRefusal(_ refusal: ArrangeEntryRefusal) {
        switch refusal {
        case .nothingSelected: lastErrorMessage = nothingSelectedMessage
        case .multipleSelected: lastErrorMessage = multipleSelectedMessage
        }
    }

    /// R-6.7 "close" / FL-5 step 5: "Exits Arrange Mode (tap outside):
    /// composition persists exactly." Pure mode transition ، no command.
    public func exitArrangeMode() {
        session.mode = .browse
        session.clearSelection()
        tapCycleState = MKHitTestPolicy.TapCycleState()
    }

    // MARK: - Revert (R-6.12, FL-13)

    public func revertPreflight() -> MKArrangeRevertPreflight? {
        guard let node = activeOwnerNode, let engine else { return nil }
        return engine.revertPreflight(for: node)
    }

    /// FL-13 step 3: confirmation is the CALLER's job (app-layer alert
    /// bound to `MKArrangeRevertPreflight`'s copy) ، this performs the
    /// already-confirmed revert. Undo restores the full arrangement
    /// byte-identically (R-6.12/R-4.19, `MKReplaceNodeCommand.inverse`).
    public func revert() throws {
        guard let id = activeOwnerNodeID, let node = activeOwnerNode, let engine else { return }
        let command = try engine.revertCommand(arrangedNodeID: id, node: node)
        try session.perform(command)
        MKCompositionRevision.bump(id)   // P-1: the arranged composition no longer exists under this id
        session.mode = .browse
        session.setSelection([id])
    }

    /// R-6.11: arrange-then-edit-source conflict, "العودة والتعديل" branch
    /// ، revert, then immediately open the text overlay on the restored
    /// Live/Path Text node.
    @discardableResult
    public func revertAndEdit() throws -> MKNodeID? {
        guard let id = activeOwnerNodeID else { return nil }
        try revert()
        session.beginEditingText(nodeID: id)
        return id
    }

    /// R-6.11's "نسخ ثم تعديل" branch: duplicates the arranged composition
    /// (fresh ids throughout, so provenance never aliases the original ،
    /// same guarantee `LayersModel.duplicate` already provides), reverts
    /// the DUPLICATE for editing, and leaves the original arranged object
    /// completely untouched.
    @discardableResult
    public func duplicateThenRevertForEditing() throws -> MKNodeID? {
        guard let id = activeOwnerNodeID, let originalIndex = session.scene.nodes.firstIndex(where: { $0.id == id }),
              let originalNode = session.scene.node(id: id), case .arranged(let arranged) = originalNode,
              let engine
        else { return nil }
        let clone = Self.reassigningIDs(arranged)
        try session.perform(MKInsertNodeCommand(node: .arranged(clone), index: originalIndex + 1, parent: nil))
        MKCompositionRevision.bump(clone.core.id)   // P-1: brand-new id, but keep every mutation site consistent
        let revertCommand = try engine.revertCommand(arrangedNodeID: clone.core.id, node: clone)
        try session.perform(revertCommand)
        MKCompositionRevision.bump(clone.core.id)
        session.mode = .browse
        session.beginEditingText(nodeID: clone.core.id)
        return clone.core.id
    }

    private static func reassigningIDs(_ node: MKArrangedTextNode) -> MKArrangedTextNode {
        var core = node.core
        core.id = MKNodeID()
        var remap: [MKNodeID: MKNodeID] = [:]
        for child in node.composition.nodes { remap[child.id] = MKNodeID() }
        var composition = node.composition
        composition.nodes = composition.nodes.map { child -> MKArrangedChild in
            switch child {
            case .glyph(var g): g.id = remap[g.id] ?? MKNodeID(); return .glyph(g)
            case .mark(var m):
                m.id = remap[m.id] ?? MKNodeID()
                if let attached = m.attachedTo { m.attachedTo = remap[attached] ?? attached }
                return .mark(m)
            case .ligature(var l):
                l.id = remap[l.id] ?? MKNodeID()
                l.attachedMarks = l.attachedMarks.map { remap[$0] ?? $0 }
                return .ligature(l)
            }
        }
        return MKArrangedTextNode(core: core, composition: composition, derivedFrom: node.derivedFrom)
    }

    // MARK: - Granularity switch (R-6.4)

    /// Switches the selection level, translating the CURRENT selection
    /// through `LevelMapping` so nothing is lost (D-105's bidirectional map
    /// ، the accept criterion this method exists to satisfy literally).
    public func setGranularity(_ newValue: MKSelectionGranularity) {
        guard newValue != granularity else { return }
        granularity = newValue
        guard let node = activeOwnerNode else { return }
        guard let engine, !session.selection.ids.isEmpty else {
            session.setArrangeChildSelection(session.selection.ids, granularity: newValue, compositionScope: node.core.id)
            return
        }
        let ranges = engine.utf16Ranges(forNodeIDs: session.selection.ids, in: node.composition)
        var translated: Set<MKNodeID> = []
        for range in ranges {
            translated.formUnion(engine.nodeIDs(forUTF16Range: range, in: node.composition, includeMarks: newValue == .letter))
        }
        session.setArrangeChildSelection(translated, granularity: newValue, compositionScope: node.core.id)
    }

    // MARK: - Hit test / tap-select inside the composition (R-6.9, R-4.6 cycling)

    /// Tap-select at glyph OR letter granularity (R-6.4) inside the active
    /// composition. Letter granularity expands the hit child to every node
    /// sharing its UTF-16 span (R-6.14's per-run split is handled by
    /// `utf16Ranges`/`nodeIDs` already only ever covering ONE contiguous
    /// span per call here ، a single tap never itself spans a bidi-run
    /// boundary; the boundary-split behavior applies to a drag/marquee
    /// RANGE selection, see `selectLetterRange(from:to:)`).
    @discardableResult
    public func tap(at point: CGPoint, zoomScale: CGFloat, now: TimeInterval = Date().timeIntervalSinceReferenceDate, additive: Bool = false) -> MKNodeID? {
        guard let ownerID = activeOwnerNodeID, let node = activeOwnerNode, let geometrySource = session.geometrySource else { return nil }
        let tolerance = MKHitTestPolicy.touchTolerance(zoomScale: zoomScale)
        guard let hit = geometrySource.arrangedChildHit(at: point, ownerNodeID: ownerID, in: session.scene, tolerance: tolerance) else {
            if !additive { session.setArrangeChildSelection([], granularity: granularity, compositionScope: ownerID) }
            return nil
        }
        let resolved = resolvedSelection(forTappedChild: hit.childID, in: node)
        if additive {
            session.setArrangeChildSelection(session.selection.ids.symmetricDifference(resolved), granularity: granularity, compositionScope: ownerID)
        } else {
            session.setArrangeChildSelection(resolved, granularity: granularity, compositionScope: ownerID)
        }
        return hit.childID
    }

    private func resolvedSelection(forTappedChild childID: MKNodeID, in node: MKArrangedTextNode) -> Set<MKNodeID> {
        guard granularity == .letter, let engine else { return [childID] }
        let ranges = engine.utf16Ranges(forNodeIDs: [childID], in: node.composition)
        var expanded: Set<MKNodeID> = []
        for range in ranges { expanded.formUnion(engine.nodeIDs(forUTF16Range: range, in: node.composition, includeMarks: true)) }
        return expanded.isEmpty ? [childID] : expanded
    }

    /// R-6.14: a letter-level RANGE selection (e.g. a marquee/drag spanning
    /// several letters) splits into per-bidi-run sub-selections at the run
    /// boundary rather than one span-crossing selection. `ids` is the raw
    /// glyph/mark/ligature id set a geometry-space selection (marquee)
    /// already picked out at glyph granularity; this re-expresses it as the
    /// covering letter-level groups, split at every `bidiLevel` change
    /// among the underlying provenance.
    public func letterLevelSubSelections(coveringChildIDs ids: Set<MKNodeID>, in node: MKArrangedTextNode) -> [Set<MKNodeID>] {
        guard let engine else { return ids.isEmpty ? [] : [ids] }
        let ranges = engine.utf16Ranges(forNodeIDs: ids, in: node.composition)
        guard !ranges.isEmpty else { return [] }
        // Group contiguous ranges into per-bidi-run runs using each range's
        // covering nodes' bidiLevel ، a run boundary is any point where the
        // level of the node ending a span differs from the node starting
        // the next.
        var subSelections: [Set<MKNodeID>] = []
        for range in ranges {
            let coveredIDs = engine.nodeIDs(forUTF16Range: range, in: node.composition, includeMarks: true)
            let levelGroups = Dictionary(grouping: coveredIDs) { id -> UInt8 in
                Self.bidiLevel(of: id, in: node.composition) ?? 0
            }
            for (_, group) in levelGroups.sorted(by: { $0.key < $1.key }) {
                subSelections.append(Set(group))
            }
        }
        return subSelections
    }

    private static func bidiLevel(of id: MKNodeID, in composition: ArrangedComposition) -> UInt8? {
        for child in composition.nodes {
            switch child {
            case .glyph(let g) where g.id == id: return g.provenance.bidiLevel
            case .mark(let m) where m.id == id: return m.provenance.bidiLevel
            case .ligature(let l) where l.id == id: return l.provenance.bidiLevel
            case .ligature(let l):
                if case .decomposed(let d) = l.state, let component = d.components.first(where: { $0.id == id }) {
                    return component.provenance.bidiLevel
                }
            default: continue
            }
        }
        return nil
    }

    // MARK: - Move (R-6.5 glyph move, R-7.4 mark move ، same primitive)

    public func beginMove() {
        session.beginGesture()
        moveGestureID = UUID()
    }

    /// Nudges every currently-selected child by `delta` (composition-space)
    /// in ONE command per frame (coalesced by `moveGestureID`, so a whole
    /// drag = one undo entry ، same D-112 contract every other canvas
    /// gesture already honors).
    public func updateMove(byDelta delta: CGSize) {
        guard let engine, let node = activeOwnerNode, let gid = moveGestureID, !session.selection.ids.isEmpty else { return }
        let command = engine.nudgePositionCommand(by: delta, forChildIDs: session.selection.ids, ownerNode: node, gestureID: gid)
        if (try? session.perform(command)) != nil {
            MKCompositionRevision.bump(node.core.id)
        }
    }

    public func endMove() {
        session.endGesture()
        moveGestureID = nil
    }

    // MARK: - Marks (R-7.5)

    public func detachSelectedMark() throws {
        guard let markID = session.selection.single, let node = activeOwnerNode, let engine,
              let command = engine.detachMarkCommand(markID: markID, ownerNode: node)
        else { return }
        try session.perform(command)
        MKCompositionRevision.bump(node.core.id)
    }

    /// R-7.5's "select mark + base → attach": re-attaches `markID` to
    /// `baseID`, recomputing the relative offset from CURRENT positions
    /// (D-220's normative formula, on the `MKArrange` side of this seam).
    public func reattachMark(_ markID: MKNodeID, toBase baseID: MKNodeID) throws {
        guard let node = activeOwnerNode, let engine, let command = engine.reattachMarkCommand(markID: markID, toBase: baseID, ownerNode: node) else { return }
        try session.perform(command)
        MKCompositionRevision.bump(node.core.id)
    }

    // MARK: - Join break/restore (§8.1) + boundary picking

    /// The logical previous/next GLYPH neighbor of `id` within the same
    /// composition (join-break/restore only ever applies between adjacent
    /// letters, never marks/ligatures) ، "join-break boundary picking":
    /// resolves WHICH neighbor a "فصل الاتصال" action targets from a single
    /// selected glyph, by walking `provenance.logicalIndex`.
    public func logicalGlyphNeighbors(of id: MKNodeID) -> (previous: MKGlyphNode?, next: MKGlyphNode?) {
        guard let node = activeOwnerNode else { return (nil, nil) }
        let glyphs = node.composition.nodes.compactMap { child -> MKGlyphNode? in
            if case .glyph(let g) = child { return g }
            return nil
        }.sorted { $0.provenance.logicalIndex < $1.provenance.logicalIndex }
        guard let index = glyphs.firstIndex(where: { $0.id == id }) else { return (nil, nil) }
        let previous = index > 0 ? glyphs[index - 1] : nil
        let next = index < glyphs.count - 1 ? glyphs[index + 1] : nil
        return (previous, next)
    }

    /// Breaks the join between `id` and its logical NEXT glyph neighbor
    /// (R-8.2's "فك الارتباط"). No-op if there is no next neighbor.
    public func breakJoinWithNext(_ id: MKNodeID) async throws {
        guard let next = logicalGlyphNeighbors(of: id).next, let node = activeOwnerNode, let engine else { return }
        let command = try await engine.breakJoinCommand(nodeAID: id, nodeBID: next.id, ownerNode: node)
        try session.perform(command)
        MKCompositionRevision.bump(node.core.id)
    }

    /// Breaks the join between `id` and its logical PREVIOUS glyph
    /// neighbor.
    public func breakJoinWithPrevious(_ id: MKNodeID) async throws {
        guard let previous = logicalGlyphNeighbors(of: id).previous, let node = activeOwnerNode, let engine else { return }
        let command = try await engine.breakJoinCommand(nodeAID: previous.id, nodeBID: id, ownerNode: node)
        try session.perform(command)
        MKCompositionRevision.bump(node.core.id)
    }

    /// R-8.6 "إعادة الارتباط": restores the join with the next neighbor.
    public func restoreJoinWithNext(_ id: MKNodeID) async throws {
        guard let next = logicalGlyphNeighbors(of: id).next, let node = activeOwnerNode, let engine else { return }
        let command = try await engine.restoreJoinCommand(nodeAID: id, nodeBID: next.id, ownerNode: node)
        try session.perform(command)
        MKCompositionRevision.bump(node.core.id)
    }

    public func restoreJoinWithPrevious(_ id: MKNodeID) async throws {
        guard let previous = logicalGlyphNeighbors(of: id).previous, let node = activeOwnerNode, let engine else { return }
        let command = try await engine.restoreJoinCommand(nodeAID: previous.id, nodeBID: id, ownerNode: node)
        try session.perform(command)
        MKCompositionRevision.bump(node.core.id)
    }

    // MARK: - Form selector (R-8.3)

    /// The most recently loaded form-selector model ، `selectForm(_:for:)`
    /// builds its command from THIS (never a fresh async re-resolve), so
    /// callers must `loadFormSelector(for:)` before `selectForm` (the
    /// popover UI always does ، it needs the model to render the 4
    /// previews in the first place).
    private var loadedFormSelector: MKArrangeFormSelectorModel?

    @discardableResult
    public func loadFormSelector(for nodeID: MKNodeID) async -> MKArrangeFormSelectorModel? {
        guard let node = activeOwnerNode, let engine else { return nil }
        let model = await engine.formSelectorModel(for: nodeID, ownerNode: node)
        loadedFormSelector = model
        return model
    }

    public func selectForm(_ form: MKJoiningForm, for nodeID: MKNodeID) throws {
        guard let node = activeOwnerNode, let engine, let loadedFormSelector, loadedFormSelector.nodeID == nodeID,
              let command = engine.formSelectionCommand(selecting: form, from: loadedFormSelector, ownerNode: node)
        else { return }
        try session.perform(command)
        MKCompositionRevision.bump(node.core.id)
        self.loadedFormSelector = nil
    }

    // MARK: - Ligature decompose/recompose (§8.2)

    public func canDecompose(_ groupID: MKNodeID) -> Bool {
        guard let node = activeOwnerNode, let engine else { return false }
        return engine.canDecompose(groupID: groupID, ownerNode: node)
    }

    /// Returns `true` when D-221's fidelity clamp auto-refused fidelity
    /// mode (R-8.10's notice-UX trigger) ، the caller surfaces the notice.
    @discardableResult
    public func decompose(_ groupID: MKNodeID, fidelity: Bool) async throws -> Bool {
        guard let node = activeOwnerNode, let engine else { return false }
        let result = try await engine.decomposeCommand(groupID: groupID, ownerNode: node, fidelity: fidelity)
        try session.perform(result.command)
        MKCompositionRevision.bump(node.core.id)
        return result.fidelityAutoRefused
    }

    public func recomposePreflight(_ groupID: MKNodeID) -> MKArrangeRecomposePreflight? {
        guard let node = activeOwnerNode, let engine else { return nil }
        return engine.recomposePreflight(groupID: groupID, ownerNode: node)
    }

    public func recompose(_ groupID: MKNodeID, force: Bool = false) throws {
        guard let node = activeOwnerNode, let engine else { return }
        let command = try engine.recomposeCommand(groupID: groupID, ownerNode: node, force: force)
        try session.perform(command)
        MKCompositionRevision.bump(node.core.id)
    }

    // MARK: - Style (task 13, R-6.5 per-node fill/stroke/shadow/opacity)

    public func setStyleForSelection(_ style: MKStyle, gestureID: UUID = UUID()) {
        guard let node = activeOwnerNode, let engine, !session.selection.ids.isEmpty else { return }
        if (try? session.perform(engine.setStyleCommand(style, forChildIDs: session.selection.ids, ownerNode: node, gestureID: gestureID))) != nil {
            // P-1: per-child style edit replaces the composition (same
            // `ArrangeCommands.replaceComposition` path `updateMove` uses
            // above), and this is a live-drag call site (`gestureID`) just
            // like `updateMove` ، without this bump every frame of a style
            // drag would fall through the cheap revision pre-filter and
            // pay the full `composition == composition` structural compare
            // in `MKLayerTreeController.contentHash(for:)` instead.
            MKCompositionRevision.bump(node.core.id)
        }
    }

    public func setOpacityForSelection(_ opacity: Double, gestureID: UUID = UUID()) {
        guard let node = activeOwnerNode, let engine, !session.selection.ids.isEmpty else { return }
        if (try? session.perform(engine.setOpacityCommand(opacity, forChildIDs: session.selection.ids, ownerNode: node, gestureID: gestureID))) != nil {
            // P-1: see `setStyleForSelection` above ، same reasoning.
            MKCompositionRevision.bump(node.core.id)
        }
    }

    private var arrangeEngineUnavailableMessage: String {
        // Latin gloss: the arrange engine is unavailable
        "محرّك الترتيب غير متاح"
    }
    private var deriveFailedMessage: String {
        // Latin gloss: could not convert this text to a free arrangement
        "تعذّر تحويل هذا النص إلى تنسيق حر"
    }
    private var nodeNotFoundMessage: String {
        // Latin gloss: the selected object could not be found
        "تعذّر العثور على العنصر المحدد"
    }
    private var noArrangeModeForNodeKindMessage: String {
        // Latin gloss: this kind of object has no free arrangement mode
        "هذا النوع من العناصر لا يملك وضع تنسيق حر"
    }
    private var nothingSelectedMessage: String {
        // Latin gloss: select a text object first, then tap the wand to
        // arrange each letter and mark on its own
        "اختر عنصر نص أولًا، ثم اضغط العصا لترتيب كل حرف وحركة على حدة"
    }
    private var multipleSelectedMessage: String {
        // Latin gloss: the free arrangement works on one text object at a time
        "الترتيب الحر يعمل على عنصر نص واحد في كل مرة"
    }
    private var deriveTooLongMessage: String {
        // Latin gloss: this text is too long to convert to a free arrangement
        "هذا النص طويل جدًا لتحويله إلى تنسيق حر"
    }
}
