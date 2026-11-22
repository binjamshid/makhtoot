import Foundation
import MKFoundation

// WS-07 packet §5 tasks 10–11 (AGENT_TASK_PACKETS/WS-07-rendering-performance.md).
// D-116/D-223 memory-pressure ladder ، the P4 slice of this packet shipped
// the STAGE MACHINE + FIDELITY SEAM (this file) and the SAMPLING SEAM
// (MemoryPressureMonitor.swift) so drawers can honor `.editorPreview(stage:)`.
// P14 hardening pass (docs/impl-log/WS-07-p14.md): wires the cross-module
// `MKFoundation.MKMemoryGovernor` (built this pass, resolving WS07-A3's
// "no cross-module MKMemoryGovernor" gap) into `transition(to:)` so stage
// transitions fire REAL cache eviction against whatever accountables the
// app composition root registered (`MKLayerTreeController`, `BitmapCache`),
// not just the fidelity/save side effects the P4 slice already had.

/// The D-116 ladder's four stages. Declared here (not in `MKFoundation`,
/// where ARCHITECTURE §12.4's illustrative sketch places the equivalent
/// `MKMemoryStage`) because `MKFoundation` is outside this packet's fence ،
/// see CONTRACTS.md's WS-07 section for the cross-module note. A future
/// P14/WS-01 pass may hoist this to `MKFoundation` as an additive move once
/// `MKMemoryGovernor` exists to consume it; every other module can adopt
/// that canonical type without an MKRender API change since the raw values
/// (0...3) and case order are fixed to match ARCHITECTURE §12.4 exactly.
public enum MKMemoryStage: Int, Sendable, Comparable, CaseIterable {
    case normal = 0
    case stage1 = 1
    case stage2 = 2
    case critical = 3

    public static func < (lhs: MKMemoryStage, rhs: MKMemoryStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Render fidelity the degradation controller drives (§11.4): `.reduced`
/// is half-resolution layer bitmaps + simplified (flat, no-blur) shadows +
/// low-interpolation images + no tile prefetch. Transitions are driven
/// EXCLUSIVELY by the memory ladder, never by entitlement (§12.5 ، this is
/// an engineering safeguard, not a feature cap).
public enum MKRenderFidelity: Sendable, Equatable {
    case full
    case reduced
}

/// The autosave seam the ladder calls at every stage transition, saving
/// BEFORE degrading (INV-17, amended D-223: stages 1–2 get a full
/// debounced-flush-equivalent, critical gets a journal-only append). This
/// protocol lets MKRender drive real autosave without importing
/// `MKPersistence` (not a DEPENDENCY_GRAPH.md edge ، `MKExport`/`MKCanvas`
/// depend on `MKRender`, not the reverse into persistence). WS-13's
/// `AppEnvironment` is expected to supply an adapter over
/// `MKPersistence.AutosaveController`/`MakhtootDocument.saveNow(reason:)`
/// (whose `MKSaveReason` cases `.memoryPressureStage1/.memoryPressureStage2
/// /.memoryPressureCritical` already exist for exactly this call, per
/// `docs/impl-log/WS-07.md`).
public protocol MKAutosaveTriggering: Sendable {
    /// Stage 1 (70%) or stage 2 (85%): full scene flush-equivalent.
    func flushForMemoryPressure(stage: MKMemoryStage) async
    /// Critical: D-223 journal-only append, no scene re-encode.
    func flushJournalOnly() async
}

/// A no-op conformer so `MKDegradationController` is usable standalone
/// (tests, pre-WS-13 development) without a real autosave wiring.
public struct MKNoOpAutosaveTriggering: MKAutosaveTriggering {
    public init() {}
    public func flushForMemoryPressure(stage: MKMemoryStage) async {}
    public func flushJournalOnly() async {}
}

/// FC-3 (AUDIT_2026-07-28.md) reclaim seam for the undo/redo stack: a
/// SECOND, independent path from the `MKMemoryAccountable`/`MKMemoryGovernor`
/// registration `MKUndoStack` also participates in (P-5, this same wave's
/// sibling Agent 2.1 conformance) ، that path only fires at stage1
/// (`evictOffscreen()`) and critical (`evictAll()`). This one is driven
/// directly off the ladder's own stage1 AND stage2 branches below, so the
/// undo budget shrinks earlier and, at stage2, further than the governor
/// path alone would. Declared here (not importing `MKPersistence`, where
/// `MKUndoStack` lives) for the same reason `MKAutosaveTriggering` above is
/// ، no DEPENDENCY_GRAPH.md edge from `MKRender` into persistence.
/// `MKUndoStack.setMaxEntries(_:)` (`MKPersistence/Undo/UndoStack.swift`)
/// already has exactly this shape; the composition root supplies an
/// adapter. Optional, like `governor` below ، `nil` (the default) keeps
/// every existing call site source-compatible until that wiring lands.
public protocol MKUndoCapReclaiming: Sendable {
    /// Shrinks the undo/redo budget to at most `newMax` entries. Mirrors
    /// `MKUndoStack.setMaxEntries(_:)`'s own documented eviction behavior
    /// exactly ، this seam does not impose a different eviction policy of
    /// its own.
    func setMaxEntries(_ newMax: Int) async
}

/// One ladder-stage transition event, for banner/HUD observers (WS-13
/// wires the stage2 banner UI off this; `MKDegradationController` itself
/// has no UIKit/SwiftUI dependency).
public struct MKMemoryStageEvent: Sendable, Equatable {
    public var stage: MKMemoryStage
    public var bannerText: String?

    public init(stage: MKMemoryStage, bannerText: String? = nil) {
        self.stage = stage
        self.bannerText = bannerText
    }
}

/// D-116/§11.4/§12.4 ladder state machine: owns the current `MKMemoryStage`
/// and the `MKRenderFidelity` it implies, drives the save-before-degrade
/// sequence (INV-17/D-223), and applies the ≥10 s-below-threshold-minus-5pt
/// hysteresis on the way back down. `@MainActor`-isolated (not an `actor`):
/// `fidelity`/`stage` are read every render pass from the main-actor canvas
/// path (§11.2), and ARCHITECTURE §12.3's own `VERIFY-AT-IMPLEMENTATION`
/// note (DF-12) flags this exact isolation choice as needing an explicit
/// decision at implementation time ، `@MainActor` is it: the sampling
/// actor (`MKMemoryPressureMonitor`) hops onto the main actor to call
/// `transition(to:)`, keeping this type's state single-threaded and simple
/// rather than lock-guarded.
@MainActor
public final class MKDegradationController {
    private let autosave: any MKAutosaveTriggering
    /// The cross-module cache registry (P14). Held strongly ، the governor
    /// is a lightweight actor with no back-reference to this controller, so
    /// there is no retain cycle; both are owned by the same composition root
    /// with the same lifetime in practice (`Makhtoot/AppShell/Scenes/Editor
    /// /EditorViewModel.swift`).
    private let governor: MKMemoryGovernor?
    /// FC-3 seam ، see `MKUndoCapReclaiming`'s doc comment above. `nil`
    /// until the composition root wires a real `MKUndoStack` adapter
    /// through; the stage1/stage2 branches below no-op via `?.` until then,
    /// same pattern `governor` already establishes.
    private let undoCapReclaimer: (any MKUndoCapReclaiming)?
    private var stageEnteredAt: [MKMemoryStage: Date] = [:]

    public private(set) var stage: MKMemoryStage = .normal
    /// Sequence of stage transitions, most-recent last ، test/HUD
    /// observability (task 10 accept: "unit tests... walk 0→1→2→3 and back").
    /// P-8 (AUDIT_2026-07-28.md): bounded to `maxHistoryEntries` ، an
    /// unbounded array here is a slow, unnoticed leak for any session that
    /// runs near the memory ceiling for a long time (many stage
    /// transitions), since nothing ever reads more than the last few
    /// entries for the banner/HUD use case this array exists for.
    public private(set) var history: [MKMemoryStageEvent] = []

    /// P-8 cap on `history`'s length ، oldest events are dropped first,
    /// ordering (most-recent last) preserved.
    public nonisolated static let maxHistoryEntries = 64

    /// D-116's exact Arabic banner copy ، posted verbatim (byte-for-byte)
    /// on every entry into `.stage2`. Packet §7 gate: "banner string exact
    /// match to D-116."
    public static let stage2BannerText = "الذاكرة شبه ممتلئة ، تم الحفظ تلقائيًا"

    /// FC-3 undo-cap reclaim targets ، both strictly below `MKUndoStack`'s
    /// own 500-entry default, and stage2 strictly smaller than stage1 (D-116:
    /// stage2 is the more severe of the two pre-critical stages, so its
    /// reclaim is more aggressive).
    nonisolated static let stage1UndoCap = 200
    nonisolated static let stage2UndoCap = 75

    public init(
        autosave: any MKAutosaveTriggering = MKNoOpAutosaveTriggering(),
        governor: MKMemoryGovernor? = nil,
        undoCapReclaimer: (any MKUndoCapReclaiming)? = nil
    ) {
        self.autosave = autosave
        self.governor = governor
        self.undoCapReclaimer = undoCapReclaimer
    }

    public var fidelity: MKRenderFidelity {
        stage >= .stage2 ? .reduced : .full
    }

    /// Advances (or retreats) the ladder to `newStage`. Downward transitions
    /// enforce the D-116 hysteresis themselves via `canStepDown(to:at:)` ،
    /// callers (the monitor) should call this on every sample; a same-stage
    /// "transition" is a harmless no-op re-assertion (still save-safe, since
    /// §12.4's ordering only matters on an actual stage CHANGE).
    public func transition(to newStage: MKMemoryStage, now: Date = Date()) async {
        guard newStage != stage else { return }

        // Downward moves are gated by hysteresis; upward moves (or a
        // `.critical` event, which "never downgrades" per ARCHITECTURE
        // §12.3) are immediate ، the ladder must react fast to rising
        // pressure and only slow-walk the retreat.
        if newStage < stage, !canStepDown(to: newStage, at: now) {
            return
        }

        // INV-17/D-223: save completes BEFORE the fidelity/eviction side
        // effect takes hold, and the save's SHAPE differs by stage. Cache
        // eviction (the governor calls) matches ARCHITECTURE §12.4's
        // pseudocode exactly: stage1 → evictOffscreen(), critical →
        // evictAll(); stage2 has no eviction call of its own (its whole
        // effect is the fidelity drop + banner, both below) since
        // offscreen content was already evicted stepping UP through
        // stage1 on the way here.
        switch newStage {
        case .normal:
            break   // stepping down to normal: no save needed, just restore fidelity
        case .stage1:
            await autosave.flushForMemoryPressure(stage: newStage)
            await governor?.evictOffscreen()
            await undoCapReclaimer?.setMaxEntries(Self.stage1UndoCap)   // FC-3
        case .stage2:
            await autosave.flushForMemoryPressure(stage: newStage)
            await undoCapReclaimer?.setMaxEntries(Self.stage2UndoCap)   // FC-3
        case .critical:
            await autosave.flushJournalOnly()   // D-223: journal-only, never flushForMemoryPressure
            await governor?.evictAll()
        }

        stage = newStage
        stageEnteredAt[newStage] = now
        let banner = (newStage == .stage2) ? Self.stage2BannerText : nil
        history.append(MKMemoryStageEvent(stage: newStage, bannerText: banner))
        // P-8: bound history to the last `maxHistoryEntries`, most-recent last.
        if history.count > Self.maxHistoryEntries {
            history.removeFirst(history.count - Self.maxHistoryEntries)
        }
    }

    /// D-116 hysteresis: "step down a stage only after 10 s below
    /// (threshold − 5 pts)". Modeled here as "the target stage must have
    /// been continuously eligible (i.e. this call pattern) for ≥10 s" ،
    /// callers drive this by calling `transition(to:)` repeatedly as new
    /// samples arrive; `MKMemoryPressureMonitor` owns the actual
    /// used-fraction→stage mapping including the −5pt margin, this method
    /// only guards the TIME component so a single instantaneous dip can't
    /// immediately de-escalate fidelity/caches.
    private func canStepDown(to newStage: MKMemoryStage, at now: Date) -> Bool {
        guard let firstEligible = pendingDownStageSince[newStage] else {
            pendingDownStageSince[newStage] = now
            return false
        }
        return now.timeIntervalSince(firstEligible) >= Self.hysteresisInterval
    }

    private var pendingDownStageSince: [MKMemoryStage: Date] = [:]
    nonisolated static let hysteresisInterval: TimeInterval = 10

    /// Test seam: bypasses hysteresis entirely (unit tests that assert the
    /// stage machine's save-ordering/banner logic in isolation from the
    /// 10 s timer ، the timer itself is covered by dedicated hysteresis
    /// tests that inject synthetic dates).
    public func forceTransition(to newStage: MKMemoryStage) async {
        pendingDownStageSince[newStage] = Date.distantPast
        await transition(to: newStage)
    }
}
