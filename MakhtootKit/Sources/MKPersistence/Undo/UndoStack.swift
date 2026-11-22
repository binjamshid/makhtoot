import Foundation
import MKFoundation
import MKModel
import Observation

// WS-02 packet §5 task 11. In-memory undo/redo stack of `MKCommand`
// inverses, with gesture coalescing and a memory-budget eviction ladder.
//
// Coalescing correctness note: every concrete command in `Commands.swift`
// applies an ABSOLUTE new value and captures the ABSOLUTE prior value in
// its inverse (never a relative delta). That is what makes "keep first
// inverse, discard the rest" (§14.3) correct: if a drag gesture emits
// commands c1, c2, …, cN (all sharing one `coalescingKey`), the stack
// records only `c1.inverse(against: sceneBeforeC1)` ، an absolute "set
// back to the pre-gesture value" command. Applying THAT single inverse to
// the scene after c1...cN both (a) fully restores the pre-gesture value
// (because it sets, not deltas) and (b) is unaffected by c2...cN's
// intermediate values, because inverses never got captured from those
// intermediate scenes. `c2...cN`'s own computed inverses are simply
// discarded ، they were only ever "set back to the value one step
// earlier," which the merged undo entry doesn't need.
@MainActor
@Observable
public final class MKUndoStack {
    /// Stores INVERSES of applied commands (§14.2) ، undoing pops one and
    /// applies it; the redo entry is that inverse's own inverse, computed
    /// against the about-to-be-undone scene.
    public private(set) var undo: [any MKCommand] = []
    public private(set) var redo: [any MKCommand] = []

    private var gestureActive = false
    private var gestureCoalescingKey: String?

    /// Eviction budget (task 11: "bounded-by-memory... eviction drops
    /// OLDEST undo entries, 25% at a time" per ARCHITECTURE §14.2). A
    /// count-based ceiling stands in for a true byte-size governor
    /// registration (`MKMemoryGovernor`, WS-07's degradation ladder) ،
    /// this packet has no rendering/measurement dependency to compute a
    /// live byte budget, so it exposes `maxEntries` as the configurable
    /// knob WS-07 can tune down under real memory pressure via
    /// `setMaxEntries(_:)`.
    public private(set) var maxEntries: Int

    public init(maxEntries: Int = 500) {
        self.maxEntries = maxEntries
    }

    public func setMaxEntries(_ newMax: Int) {
        maxEntries = max(1, newMax)
        evictIfNeeded()
    }

    /// Marks the start of a coalescible gesture transaction (WS-06 canvas
    /// drags, inspector slider drags, keystroke bursts).
    public func beginGesture() {
        gestureActive = true
        gestureCoalescingKey = nil
    }

    /// Ends the current gesture transaction; the next `perform` starts a
    /// fresh (non-coalesced) undo entry.
    public func endGesture() {
        gestureActive = false
        gestureCoalescingKey = nil
    }

    /// Applies `command` to `currentScene` and records undo/redo state.
    /// Returns the new scene; the caller (`MakhtootDocument`) is
    /// responsible for adopting it as the new current scene.
    @discardableResult
    public func perform(_ command: any MKCommand, currentScene: MKScene) throws -> MKScene {
        let inverse = command.inverse(against: currentScene)
        let newScene = try command.apply(to: currentScene)

        if gestureActive, let key = command.coalescingKey, key == gestureCoalescingKey, !undo.isEmpty {
            // Coalesce: an undo entry for this gesture+key already exists
            // (from the FIRST command in this run) ، keep it, don't push
            // a new one. "Last apply" is already reflected in `newScene`
            // itself, which the caller adopts regardless.
        } else {
            undo.append(inverse)
            gestureCoalescingKey = gestureActive ? command.coalescingKey : nil
            evictIfNeeded()
        }
        redo.removeAll()
        return newScene
    }

    /// Pops the most recent undo entry, applies it to `currentScene`, and
    /// pushes its own inverse (computed against `currentScene`, i.e. the
    /// about-to-be-undone state) onto the redo stack.
    public func undoLast(currentScene: MKScene) throws -> MKScene? {
        guard let command = undo.popLast() else { return nil }
        let redoCommand = command.inverse(against: currentScene)
        let newScene = try command.apply(to: currentScene)
        redo.append(redoCommand)
        return newScene
    }

    public func redoLast(currentScene: MKScene) throws -> MKScene? {
        guard let command = redo.popLast() else { return nil }
        let undoCommand = command.inverse(against: currentScene)
        let newScene = try command.apply(to: currentScene)
        undo.append(undoCommand)
        return newScene
    }

    public var canUndo: Bool { !undo.isEmpty }
    public var canRedo: Bool { !redo.isEmpty }

    /// Evicts the oldest entries 25% at a time until `undo.count` is back
    /// at or under `maxEntries`. LOOPED (not a single slice) as of P-5
    /// (AUDIT_2026-07-28.md): the original single-pass version was only
    /// ever exercised via `perform(_:currentScene:)`, where the cap is
    /// crossed by exactly one entry at a time, so one 25% slice always
    /// converged back under budget. `setMaxEntries(_:)` can now ALSO be
    /// called directly by a governor-driven `evictOffscreen()`/`evictAll()`
    /// (below) with a MUCH smaller new cap than the current count, which a
    /// single slice would not converge under ، looping preserves the exact
    /// existing incremental-eviction behavior (still one iteration in that
    /// case) while making the governor-driven case correct too.
    private func evictIfNeeded() {
        while undo.count > maxEntries {
            let evictCount = max(1, undo.count / 4) // 25% at a time
            undo.removeFirst(min(evictCount, undo.count))
        }
    }
}

// MARK: - MKMemoryAccountable (P-5, D-116 governor wiring)

/// P-5 (AUDIT_2026-07-28.md): "`MKUndoStack` does not conform to
/// `MKMemoryAccountable`, so `MKMemoryGovernor` ... cannot see it or shrink
/// it." Entry cost is not uniform ، the inverse of a delete is an
/// `MKInsertNodeCommand` holding the ENTIRE removed node, including a full
/// arranged composition (`Commands.swift`'s own doc comment) ، so a long
/// session of delete/re-delete through Arrange Mode can pin substantial
/// memory the ladder was structurally unable to reclaim before this.
///
/// Mirrors `MKRender.MKLayerTreeController`'s own established shape for
/// this exact protocol: a bare `extension ...: MKMemoryAccountable {}`
/// conformance declaration, with the three requirement methods implemented
/// as plain synchronous members inside the type's own `@MainActor` class
/// body above (Swift allows a synchronous, actor-isolated method to
/// satisfy an `async` protocol requirement ، see `MKMemoryGovernor.swift`'s
/// own header for the isolation-story rationale this reuses verbatim).
extension MKUndoStack: MKMemoryAccountable {
    /// Sampled, not per-entry: encoding EVERY undo/redo command via
    /// `MKCommandCoder` on every governor query would itself be an
    /// O(stack-size) cost paid on a low-frequency (D-116 ladder-driven)
    /// path ، the exact anti-pattern this whole audit fights elsewhere
    /// (P-6's per-byte hash loop). Samples the `accountingSampleSize` MOST
    /// RECENT entries across both stacks (newest entries are the ones most
    /// likely to be the expensive `MKInsertNodeCommand`-holding-a-whole-
    /// composition case this finding calls out) and extrapolates an
    /// average-entry-size estimate across the full count ، any entry that
    /// fails to encode (e.g. a not-yet-`MKCommandCoder`-registered command
    /// type, a pre-existing gap logged elsewhere in this codebase) is
    /// treated as `0` bytes for that sample rather than throwing, so a
    /// single unencodable command never poisons the whole estimate.
    public func accountedBytes() -> Int {
        let pool = undo + redo
        guard !pool.isEmpty else { return 0 }
        let sample = pool.suffix(Self.accountingSampleSize)
        let sampledBytes = sample.reduce(0) { total, command in
            total + ((try? MKCommandCoder.encode(command).count) ?? 0)
        }
        guard sampledBytes > 0 else { return 0 }
        let averageBytes = Double(sampledBytes) / Double(sample.count)
        return Int((averageBytes * Double(pool.count)).rounded())
    }

    /// D-116 stage 1: halves the entry ceiling, reusing the existing
    /// `setMaxEntries(_:)` knob (WS-02's own doc comment on that method:
    /// "the configurable knob WS-07 can tune down under real memory
    /// pressure" ، this is that wiring, previously dead).
    public func evictOffscreen() {
        setMaxEntries(maxEntries / 2)
    }

    /// D-116/D-223 critical: `MKMemoryAccountable.evictAll()`'s own
    /// documented contract is "drop everything (`purgeAll()`-equivalent)"
    /// ، a full clear, matching every sibling conformer's own "nuclear
    /// option, critical only" scope (`MKLayerTreeController.evictAll()`
    /// drops every layer's bitmap unconditionally). `redo` is cleared too:
    /// once `undo` is gone, a stale `redo` stack could reapply changes
    /// whose own inverses no longer exist to undo them again.
    public func evictAll() {
        undo.removeAll()
        redo.removeAll()
    }

    private static let accountingSampleSize = 20
}
