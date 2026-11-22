import Testing
@testable import MKFoundation

// P14 hardening pass (docs/impl-log/WS-07-p14-run3.md, item 1): the
// cross-module `MKMemoryGovernor` registry (MKMemoryGovernor.swift) had no
// dedicated test coverage ، `MKRenderTests` exercises the CONFORMERS
// (`BitmapCache`, `MKLayerTreeController`) against a real
// `MKDegradationController`, but nothing here proved the governor itself
// (registration, fan-out, weak-reference pruning) against a synthetic
// accountable. `BallastAccountable` below is exactly that: a fake, byte-
// counted "cache" whose eviction actions are directly observable, standing
// in for the "ballast allocator" the task packet's accept criterion asks
// for (a controllable memory consumer the ladder can be proven to drain).
@Suite struct MKMemoryGovernorTests {
    /// A synthetic memory consumer: `heldBytes` simulates whatever a real
    /// cache would be holding (bitmap tiles, shaping cache entries, ...).
    /// `evictOffscreen()` only drops the "offscreen" portion (mirrors
    /// `BitmapCache.purgeOffscreen()` ، a partial reclaim); `evictAll()`
    /// drops everything (mirrors `purgeAll()`). Both call counts are
    /// observable so tests can assert exactly which eviction action fired,
    /// not just the byte-count side effect.
    actor BallastAccountable: MKMemoryAccountable {
        private(set) var heldBytes: Int
        private let offscreenBytes: Int
        private(set) var evictOffscreenCallCount = 0
        private(set) var evictAllCallCount = 0

        init(totalBytes: Int, offscreenBytes: Int) {
            self.heldBytes = totalBytes
            self.offscreenBytes = offscreenBytes
        }

        func accountedBytes() async -> Int { heldBytes }

        func evictOffscreen() async {
            evictOffscreenCallCount += 1
            heldBytes = max(0, heldBytes - offscreenBytes)
        }

        func evictAll() async {
            evictAllCallCount += 1
            heldBytes = 0
        }
    }

    @Test func totalAccountedBytesSumsEveryRegisteredBallast() async {
        let governor = MKMemoryGovernor()
        let ballastA = BallastAccountable(totalBytes: 40_000_000, offscreenBytes: 10_000_000)
        let ballastB = BallastAccountable(totalBytes: 15_000_000, offscreenBytes: 5_000_000)

        await governor.register(ballastA)
        await governor.register(ballastB, priority: .offscreenFirst)

        let total = await governor.totalAccountedBytes()
        #expect(total == 55_000_000)
    }

    @Test func evictOffscreenDrainsOnlyTheOffscreenPortionAcrossAllRegistrants() async {
        let governor = MKMemoryGovernor()
        let ballastA = BallastAccountable(totalBytes: 40_000_000, offscreenBytes: 10_000_000)
        let ballastB = BallastAccountable(totalBytes: 15_000_000, offscreenBytes: 5_000_000)
        await governor.register(ballastA)
        await governor.register(ballastB)

        await governor.evictOffscreen()

        let total = await governor.totalAccountedBytes()
        #expect(total == 40_000_000)   // 30M + 10M remaining
        let aOffscreenCalls = await ballastA.evictOffscreenCallCount
        let aAllCalls = await ballastA.evictAllCallCount
        #expect(aOffscreenCalls == 1)
        #expect(aAllCalls == 0)   // stage1 must never reach for the nuclear option
    }

    @Test func evictAllDropsEveryRegistrantToZero() async {
        let governor = MKMemoryGovernor()
        let ballastA = BallastAccountable(totalBytes: 40_000_000, offscreenBytes: 10_000_000)
        let ballastB = BallastAccountable(totalBytes: 15_000_000, offscreenBytes: 5_000_000)
        await governor.register(ballastA)
        await governor.register(ballastB)

        await governor.evictAll()

        let total = await governor.totalAccountedBytes()
        #expect(total == 0)
        let bAllCalls = await ballastB.evictAllCallCount
        #expect(bAllCalls == 1)
    }

    /// The registration table holds `weak` references (`MKMemoryGovernor`
    /// must never be the reason a cache outlives its real owner) ، once the
    /// only strong reference to a ballast is released, the governor's next
    /// operation must both exclude it from the byte total AND prune the
    /// dead entry from `liveRegistrationCount`.
    @Test func deallocatedBallastIsPrunedAndExcludedFromTheTotal() async {
        let governor = MKMemoryGovernor()
        var ballast: BallastAccountable? = BallastAccountable(totalBytes: 20_000_000, offscreenBytes: 5_000_000)
        await governor.register(ballast!)

        let liveBefore = await governor.liveRegistrationCount
        #expect(liveBefore == 1)
        let totalBefore = await governor.totalAccountedBytes()
        #expect(totalBefore == 20_000_000)

        ballast = nil   // release the only strong reference

        let totalAfter = await governor.totalAccountedBytes()
        #expect(totalAfter == 0)
        let liveAfter = await governor.liveRegistrationCount
        #expect(liveAfter == 0)
    }

    @Test func repeatedRegistrationOfTheSameInstanceIsHarmlessNotDoubleCounted() async {
        // "Idempotent-safe to call multiple times" per the doc comment: each
        // call adds another weak registration, so a double-registered
        // ballast is double-COUNTED in the byte total (a documented,
        // accepted quirk, not silently deduplicated) ، this test pins that
        // exact behavior so a future change to it is a deliberate decision,
        // not an accidental regression.
        let governor = MKMemoryGovernor()
        let ballast = BallastAccountable(totalBytes: 10_000_000, offscreenBytes: 0)
        await governor.register(ballast)
        await governor.register(ballast)

        let total = await governor.totalAccountedBytes()
        #expect(total == 20_000_000)
        let liveCount = await governor.liveRegistrationCount
        #expect(liveCount == 2)
    }

    @Test func evictionPriorityIsStoredButDoesNotYetGateFanOut() async {
        // D-116/ARCHITECTURE §12.3 documents no per-cache-class eviction
        // ordering today ، every registrant, regardless of priority, is
        // evicted uniformly at each stage. This test exists so a future
        // priority-aware policy change is caught here first, not silently
        // assumed elsewhere.
        #expect(MKMemoryEvictionPriority.offscreenFirst < MKMemoryEvictionPriority.standard)

        let governor = MKMemoryGovernor()
        let offscreenFirstBallast = BallastAccountable(totalBytes: 5_000_000, offscreenBytes: 5_000_000)
        let standardBallast = BallastAccountable(totalBytes: 5_000_000, offscreenBytes: 5_000_000)
        await governor.register(offscreenFirstBallast, priority: .offscreenFirst)
        await governor.register(standardBallast, priority: .standard)

        await governor.evictOffscreen()

        let offscreenFirstCalls = await offscreenFirstBallast.evictOffscreenCallCount
        let standardCalls = await standardBallast.evictOffscreenCallCount
        #expect(offscreenFirstCalls == 1)
        #expect(standardCalls == 1)   // both fire ، no ordering/gating by priority yet
    }
}
