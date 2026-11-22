import Testing
import Foundation
import MKFoundation
@testable import MKRender

// P14 hardening pass (docs/impl-log/WS-07-p14-run3.md, item 1): proves the
// REAL wiring end to end ، `MKDegradationController` driving a real
// `MKMemoryGovernor` driving a synthetic "ballast" `MKMemoryAccountable` ،
// rather than just the governor in isolation (`MKFoundationTests
// .MKMemoryGovernorTests`) or the ladder's save/fidelity side effects
// without any cache attached (`DegradationLadderTests`, pre-existing).
// `BitmapCache`/`MKLayerTreeController`'s own `MKMemoryAccountable`
// conformances are exercised directly in their own test files
// (`BitmapCacheTests`, `LayerTreeControllerTests`); this file is the
// GOVERNOR WIRING integration test the task packet's ballast-allocator
// accept criterion calls for.
@Suite struct MemoryGovernorIntegrationTests {
    /// Ordered, actor-serialized event log so save-before-evict ordering
    /// (INV-17/D-223) can be asserted across two independently-actor-isolated
    /// participants (the autosave recorder and the ballast) without a race.
    actor OrderLog {
        private(set) var events: [String] = []
        func record(_ event: String) { events.append(event) }
    }

    actor RecordingAutosave: MKAutosaveTriggering {
        let log: OrderLog
        init(log: OrderLog) { self.log = log }
        func flushForMemoryPressure(stage: MKMemoryStage) async {
            await log.record("save:\(stage)")
        }
        func flushJournalOnly() async {
            await log.record("save:journalOnly")
        }
    }

    /// A byte-counted stand-in for a real cache (the "ballast allocator") ،
    /// simulates a large in-memory allocation the ladder is responsible for
    /// draining. `offscreenBytes` models the portion a stage-1
    /// `evictOffscreen()` can reclaim (offscreen tiles/cold cache entries);
    /// the remainder only clears on `evictAll()` (critical stage).
    actor BallastAccountable: MKMemoryAccountable {
        let log: OrderLog
        private(set) var heldBytes: Int
        private let offscreenBytes: Int

        init(totalBytes: Int, offscreenBytes: Int, log: OrderLog) {
            self.heldBytes = totalBytes
            self.offscreenBytes = offscreenBytes
            self.log = log
        }

        func accountedBytes() async -> Int { heldBytes }

        func evictOffscreen() async {
            heldBytes = max(0, heldBytes - offscreenBytes)
            await log.record("evictOffscreen")
        }

        func evictAll() async {
            heldBytes = 0
            await log.record("evictAll")
        }
    }

    @Test func stage1TransitionDrainsOnlyOffscreenBytesFromTheRegisteredBallast() async {
        let log = OrderLog()
        let governor = MKMemoryGovernor()
        let ballast = BallastAccountable(totalBytes: 100_000_000, offscreenBytes: 30_000_000, log: log)
        await governor.register(ballast)

        let controller = await MKDegradationController(autosave: RecordingAutosave(log: log), governor: governor)

        let beforeBytes = await governor.totalAccountedBytes()
        #expect(beforeBytes == 100_000_000)

        await controller.forceTransition(to: .stage1)

        let afterBytes = await governor.totalAccountedBytes()
        #expect(afterBytes == 70_000_000)   // only the offscreen 30 MB reclaimed ، ballast-driven stage observed

        let events = await log.events
        #expect(events == ["save:stage1", "evictOffscreen"])   // INV-17: save completes BEFORE eviction
    }

    @Test func criticalTransitionDrainsTheBallastCompletelyAfterAJournalOnlyFlush() async {
        let log = OrderLog()
        let governor = MKMemoryGovernor()
        let ballast = BallastAccountable(totalBytes: 100_000_000, offscreenBytes: 30_000_000, log: log)
        await governor.register(ballast)

        let controller = await MKDegradationController(autosave: RecordingAutosave(log: log), governor: governor)

        await controller.forceTransition(to: .critical)

        let afterBytes = await governor.totalAccountedBytes()
        #expect(afterBytes == 0)   // D-223: critical = evictAll, the nuclear option

        let events = await log.events
        #expect(events == ["save:journalOnly", "evictAll"])   // journal-only save, THEN full drain
    }

    /// Stage2 (half-res fidelity) has no eviction action of its own
    /// (ARCHITECTURE §12.4 pseudocode: offscreen content was already
    /// reclaimed stepping up through stage1) ، the ballast must be
    /// untouched by a direct normal→stage2 jump that never passed through
    /// stage1.
    @Test func stage2AloneNeverTouchesTheGovernor() async {
        let log = OrderLog()
        let governor = MKMemoryGovernor()
        let ballast = BallastAccountable(totalBytes: 50_000_000, offscreenBytes: 20_000_000, log: log)
        await governor.register(ballast)

        let controller = await MKDegradationController(autosave: RecordingAutosave(log: log), governor: governor)
        await controller.forceTransition(to: .stage2)

        let bytes = await governor.totalAccountedBytes()
        #expect(bytes == 50_000_000)   // untouched
        let events = await log.events
        #expect(events == ["save:stage2"])   // no eviction event at all
    }

    /// A controller built with no governor (`governor: nil`, the default ،
    /// every pre-P14 call site) must still transition/save correctly; the
    /// governor calls are `governor?.` no-ops, never a crash or a silently
    /// skipped save.
    @Test func missingGovernorIsANoOpNotACrash() async {
        let log = OrderLog()
        let controller = await MKDegradationController(autosave: RecordingAutosave(log: log))
        await controller.forceTransition(to: .critical)
        let events = await log.events
        #expect(events == ["save:journalOnly"])
        let stage = await controller.stage
        #expect(stage == .critical)
    }

    /// Full ladder walk driven by an injected sampler (mirrors
    /// `DegradationLadderTests.monitorWalksStagesFromInjectedReadings`, this
    /// time with a real ballast attached) ، proves bytes actually drop as
    /// the SAMPLED fraction crosses each D-116 threshold, not just under
    /// `forceTransition`'s test-only bypass.
    @Test func sampledLadderWalkDrainsTheBallastAtEachRealThresholdCrossing() async {
        let log = OrderLog()
        let governor = MKMemoryGovernor()
        let ballast = BallastAccountable(totalBytes: 100_000_000, offscreenBytes: 40_000_000, log: log)
        await governor.register(ballast)
        let controller = await MKDegradationController(autosave: RecordingAutosave(log: log), governor: governor)
        let box = FractionBox(0)
        let monitor = MKMemoryPressureMonitor(sampler: { box.value }, ladder: controller)

        box.value = 0.75   // crosses stage1 (0.70)
        await monitor.sampleNow()
        var bytes = await governor.totalAccountedBytes()
        #expect(bytes == 60_000_000)

        box.value = 0.90   // crosses stage2 (0.85) ، no further eviction
        await monitor.sampleNow()
        bytes = await governor.totalAccountedBytes()
        #expect(bytes == 60_000_000)

        // Real critical only ever arrives via the DispatchSource `.critical`
        // event (never derived from a sampled fraction, §12.3) ، simulated
        // here the same way `MKMemoryPressureMonitor`'s own event handler
        // would drive it, via a direct forced transition (`transition(to:)`
        // is the same call the monitor's `.critical` branch makes).
        await controller.transition(to: .critical)
        bytes = await governor.totalAccountedBytes()
        #expect(bytes == 0)
    }
}
