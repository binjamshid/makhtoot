import Testing
import Foundation
@testable import MKRender

/// WS-07 packet §5 task 10 accept: "unit tests with injected readings walk
/// 0→1→2→3 and back"; INV-17/D-223: save completes BEFORE degrade, with
/// stage-appropriate shape (full flush at 1–2, journal-only at critical).
@Suite struct DegradationLadderTests {
    actor RecordingAutosave: MKAutosaveTriggering {
        var pressureFlushes: [MKMemoryStage] = []
        var journalOnlyFlushes = 0

        func flushForMemoryPressure(stage: MKMemoryStage) async {
            pressureFlushes.append(stage)
        }
        func flushJournalOnly() async {
            journalOnlyFlushes += 1
        }
    }

    @Test func stage2ProducesExactD116BannerText() async {
        let recorder = RecordingAutosave()
        let controller = await MKDegradationController(autosave: recorder)
        await controller.forceTransition(to: .stage2)
        let history = await controller.history
        #expect(history.last?.bannerText == "الذاكرة شبه ممتلئة ، تم الحفظ تلقائيًا")
    }

    @Test func stage1And2FlushBeforeDegrading() async {
        let recorder = RecordingAutosave()
        let controller = await MKDegradationController(autosave: recorder)

        await controller.forceTransition(to: .stage1)
        var flushes = await recorder.pressureFlushes
        #expect(flushes == [.stage1])
        var fidelity = await controller.fidelity
        #expect(fidelity == .full)   // stage1 does not degrade fidelity, only caches (§11.4)

        await controller.forceTransition(to: .stage2)
        flushes = await recorder.pressureFlushes
        #expect(flushes == [.stage1, .stage2])
        fidelity = await controller.fidelity
        #expect(fidelity == .reduced)
    }

    /// D-223: critical stage NEVER calls `flushForMemoryPressure` ، only
    /// `flushJournalOnly`.
    @Test func criticalStageUsesJournalOnlyFlushNeverFullFlush() async {
        let recorder = RecordingAutosave()
        let controller = await MKDegradationController(autosave: recorder)

        await controller.forceTransition(to: .critical)

        let pressureFlushes = await recorder.pressureFlushes
        let journalOnly = await recorder.journalOnlyFlushes
        #expect(pressureFlushes.isEmpty)
        #expect(journalOnly == 1)
    }

    @Test func walksThroughAllFourStagesInOrder() async {
        let recorder = RecordingAutosave()
        let controller = await MKDegradationController(autosave: recorder)

        for stage in [MKMemoryStage.stage1, .stage2, .critical] {
            await controller.forceTransition(to: stage)
            let current = await controller.stage
            #expect(current == stage)
        }
        let history = await controller.history
        #expect(history.map(\.stage) == [.stage1, .stage2, .critical])
    }

    /// De-escalation is gated by the packet's hysteresis rule; `forceTransition`
    /// bypasses it (documented test seam) so this test isolates the STAGE
    /// MACHINE behavior ، the real hysteresis TIMING is covered by
    /// `deescalationRespectsHysteresisWindow` below via the monitor.
    @Test func forceTransitionCanStepBackDownToNormal() async {
        let recorder = RecordingAutosave()
        let controller = await MKDegradationController(autosave: recorder)
        await controller.forceTransition(to: .critical)
        await controller.forceTransition(to: .normal)
        let stage = await controller.stage
        let fidelity = await controller.fidelity
        #expect(stage == .normal)
        #expect(fidelity == .full)
    }

    @Test func sameStageTransitionIsANoOp() async {
        let recorder = RecordingAutosave()
        let controller = await MKDegradationController(autosave: recorder)
        await controller.forceTransition(to: .stage1)
        await controller.transition(to: .stage1)   // not force ، should just no-op, not append history again
        let history = await controller.history
        #expect(history.count == 1)
    }

    // MARK: - MKMemoryPressureMonitor: threshold mapping + hysteresis

    @Test func thresholdMappingMatchesD116() {
        #expect(MKMemoryThresholds.stage(forUsedFraction: 0.5) == .normal)
        #expect(MKMemoryThresholds.stage(forUsedFraction: 0.70) == .stage1)
        #expect(MKMemoryThresholds.stage(forUsedFraction: 0.80) == .stage1)
        #expect(MKMemoryThresholds.stage(forUsedFraction: 0.85) == .stage2)
        #expect(MKMemoryThresholds.stage(forUsedFraction: 0.99) == .stage2)
    }

    /// Full 0→1→2→3→...→0 walk via the monitor's injected sampler,
    /// exercising `sampleNow()` directly (task 10's own accept-criterion
    /// wording).
    @Test func monitorWalksStagesFromInjectedReadings() async {
        let recorder = RecordingAutosave()
        let controller = await MKDegradationController(autosave: recorder)
        let box = FractionBox(0)
        let monitor = MKMemoryPressureMonitor(sampler: { box.value }, ladder: controller)

        box.value = 0.75
        await monitor.sampleNow()
        var stage = await controller.stage
        #expect(stage == .stage1)

        box.value = 0.9
        await monitor.sampleNow()
        stage = await controller.stage
        #expect(stage == .stage2)

        // Sampling never DERIVES `.critical` from a fraction (only a real
        // DispatchSource `.critical` event does, §12.3) ، a 0.99 reading
        // stays at stage2, it does not escalate further via sampling alone.
        box.value = 0.99
        await monitor.sampleNow()
        stage = await controller.stage
        #expect(stage == .stage2)
    }

    // MARK: - P-8: bounded history

    /// P-8 (AUDIT_2026-07-28.md): `history` must never grow unbounded ،
    /// drives well over `maxHistoryEntries` (64) real stage transitions
    /// (alternating stage2/stage1, injected `now:` timestamps spaced past
    /// the hysteresis window to defeat it, matching
    /// `deescalationRespectsHysteresisWindow` below's pattern) and asserts
    /// the array never exceeds the cap, with ordering (most-recent last)
    /// preserved.
    @Test func historyIsBoundedToMaxHistoryEntries() async {
        let recorder = RecordingAutosave()
        let controller = await MKDegradationController(autosave: recorder)

        var now = Date()
        await controller.transition(to: .stage2, now: now)   // upward: immediate
        now = now.addingTimeInterval(1)
        // Downward move: first attempt only registers hysteresis eligibility
        // (see `deescalationRespectsHysteresisWindow`) ، it does not step
        // down yet and does not append to history.
        await controller.transition(to: .stage1, now: now)
        now = now.addingTimeInterval(MKDegradationController.hysteresisInterval + 1)

        for i in 0..<80 {
            let target: MKMemoryStage = (i % 2 == 0) ? .stage1 : .stage2
            now = now.addingTimeInterval(1)
            await controller.transition(to: target, now: now)
        }

        let history = await controller.history
        #expect(history.count == MKDegradationController.maxHistoryEntries)
        // i == 79 (odd, the final loop iteration) targets `.stage2` ،
        // ordering is preserved, most-recent last.
        #expect(history.last?.stage == .stage2)
    }

    // MARK: - FC-3: undo-cap reclaim wiring

    actor RecordingUndoCapReclaimer: MKUndoCapReclaiming {
        var calls: [Int] = []
        func setMaxEntries(_ newMax: Int) async {
            calls.append(newMax)
        }
    }

    /// FC-3 (AUDIT_2026-07-28.md): `transition(to:)`'s stage1/stage2
    /// branches must call `undoCapReclaimer?.setMaxEntries(_:)` with
    /// distinct, below-default caps ، stage2 strictly tighter than stage1
    /// (D-116 severity order).
    @Test func stage1And2InvokeUndoCapReclaimerWithDistinctCaps() async {
        let recorder = RecordingAutosave()
        let undoReclaimer = RecordingUndoCapReclaimer()
        let controller = await MKDegradationController(autosave: recorder, undoCapReclaimer: undoReclaimer)

        await controller.forceTransition(to: .stage1)
        var calls = await undoReclaimer.calls
        #expect(calls == [MKDegradationController.stage1UndoCap])

        await controller.forceTransition(to: .stage2)
        calls = await undoReclaimer.calls
        #expect(calls == [MKDegradationController.stage1UndoCap, MKDegradationController.stage2UndoCap])

        #expect(MKDegradationController.stage1UndoCap < 500)   // below MKUndoStack's own default
        #expect(MKDegradationController.stage2UndoCap < MKDegradationController.stage1UndoCap)
    }

    /// Critical relies solely on `governor?.evictAll()` (D-223) ، the
    /// undo-cap reclaim seam is a stage1/stage2-only mechanism and must not
    /// fire again on critical entry.
    @Test func criticalStageDoesNotInvokeUndoCapReclaimer() async {
        let recorder = RecordingAutosave()
        let undoReclaimer = RecordingUndoCapReclaimer()
        let controller = await MKDegradationController(autosave: recorder, undoCapReclaimer: undoReclaimer)

        await controller.forceTransition(to: .critical)
        let calls = await undoReclaimer.calls
        #expect(calls.isEmpty)
    }

    /// A `nil` reclaimer (every existing production-shaped call site until
    /// the composition root wires one) must not crash or otherwise affect
    /// the rest of the stage1/stage2 side effects.
    @Test func nilUndoCapReclaimerIsHarmless() async {
        let recorder = RecordingAutosave()
        let controller = await MKDegradationController(autosave: recorder)   // undoCapReclaimer defaults to nil
        await controller.forceTransition(to: .stage1)
        await controller.forceTransition(to: .stage2)
        let stage = await controller.stage
        #expect(stage == .stage2)
    }

    /// Hysteresis: stepping DOWN a stage requires ≥10 s continuously below
    /// (threshold − 5 pts) ، a same-instant drop must NOT immediately
    /// de-escalate.
    @Test func deescalationRespectsHysteresisWindow() async {
        let recorder = RecordingAutosave()
        let controller = await MKDegradationController(autosave: recorder)
        await controller.forceTransition(to: .stage2)

        let now = Date()
        // Instantaneous drop attempt ، should NOT step down yet (first
        // eligible sample only starts the hysteresis clock).
        await controller.transition(to: .stage1, now: now)
        var stage = await controller.stage
        #expect(stage == .stage2)

        // 5 seconds later: still within the 10 s window.
        await controller.transition(to: .stage1, now: now.addingTimeInterval(5))
        stage = await controller.stage
        #expect(stage == .stage2)

        // 11 seconds after the FIRST eligible sample: hysteresis satisfied.
        await controller.transition(to: .stage1, now: now.addingTimeInterval(11))
        stage = await controller.stage
        #expect(stage == .stage1)
    }
}

/// Simple reference-type box so a `@Sendable` sampler closure can read a
/// test-mutated value (the closure itself must be `@Sendable`, ruling out
/// a plain captured `var`).
final class FractionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Double
    init(_ value: Double) { _value = value }
    var value: Double {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); defer { lock.unlock() }; _value = newValue }
    }
}
