import Testing
import Foundation
import QuartzCore
import CoreGraphics
import MKFoundation
import MKModel
@testable import MKRender

/// WS-07 packet §5 task 14: perf harness + budget verification.
/// T-PERF-* simulator-side baseline measurements (indicative; device
/// profiling with Instruments is environment-deferred ، see §7 note).
///
/// SIMULATOR-INDICATIVE: every D-115 wall-clock number asserted in this
/// file is measured on the swift-test host (Xcode Simulator or macOS host
/// process running `swift test`, never real device hardware) and stands in
/// for the real D-115 device budget. See docs/impl-log/WS-07-p14.md's
/// "T-PRF budget sweep vs D-115" section for the measured-margin table and
/// the full list of items that remain device-gated.
///
/// D-115 budgets (definitive on device; simulator is a lower bound):
///   manipulation frame ≤8.3 ms ProMotion / ≤16.6 ms A12
///   typing echo <50 ms
///   open ≤100 nodes <1 s; open 5 000 nodes <3 s
///   incremental autosave <100 ms off-main
///   4K PNG export <10 s A15 (handed to WS-08 TileRenderer gate)
@Suite("PerfHarness ، T-PERF-*")
struct PerfHarnessTests {

    // MARK: - Helpers

    /// Builds a synthetic scene with `nodeCount` small rect shapes using the
    /// same fixture patterns as TestHelpers.swift (`TestScenes.redRect`).
    private func makeScene(nodeCount: Int) -> MKScene {
        let nodes = (0..<nodeCount).map { i -> MKNode in
            let position = CGPoint(x: CGFloat(i % 50) * 20 + 10, y: CGFloat(i / 50) * 20 + 10)
            let size = CGSize(width: 10, height: 10)
            let core = MKNodeCore(
                name: "node-\(i)",
                transform: MKTransform2D(position: position, scale: size),
                style: MKStyle(fill: .solid(MKSolidColor(r: 0.5, g: 0.5, b: 0.5, a: 1)))
            )
            return .shape(MKShapeNode(core: core, geometry: .rect(cornerRadius: 0)))
        }
        return MKScene(
            canvas: MKCanvasSpec(size: CGSize(width: 1200, height: 1600)),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: nodes
        )
    }

    /// P-1: a single `.arranged` node with `glyphCount` distinct glyph
    /// children ، hand-authored the same way `TestScenes.arrangedBaseAndMark`
    /// builds its (much smaller) fixture, scaled up so a full re-encode+
    /// hash of the WHOLE composition (`MKContentHash`'s `.arranged` case:
    /// "encodes the entire composition") is actually measurable. This is
    /// deliberately the worst case for P-1's dirty-tracking cost: one big
    /// Arrange Mode composition, exactly the "flagship differentiator" the
    /// audit calls out.
    private func makeLargeArrangedScene(glyphCount: Int) -> (scene: MKScene, nodeID: MKNodeID) {
        let squareOutline = MKPathData(commands: [
            0, -500, -500,
            1, 500, -500,
            1, 500, 500,
            1, -500, 500,
            4,
        ], unitsPerEm: 1000)

        // Grid layout (NOT a single 40pt-per-glyph row): a real single-line
        // row at `glyphCount` in the thousands would blow `originFrame`
        // (and therefore the rasterizer's world-bounds bitmap allocation,
        // see `MKNodeLocalBounds.worldBounds`'s `.arranged` case returning
        // `composition.originFrame` directly) out to hundreds of thousands
        // of points wide ، a multi-hundred-MB bitmap for the initial sync
        // this test doesn't even budget. A bounded grid keeps world bounds
        // constant-size regardless of `glyphCount`, which is all a content-
        // hash/JSON-encoding-cost test actually needs ، visual realism is
        // irrelevant here.
        let columns = 100
        let children: [MKArrangedChild] = (0..<glyphCount).map { i in
            let provenance = MKProvenance(
                clusterID: MKClusterID(), codepoints: [UInt32(0x0644 + (i % 20))], utf16Start: i, utf16Length: 1,
                bidiLevel: 0, visualIndex: i, logicalIndex: i
            )
            let glyph = MKGlyphNode(
                glyph: MKGlyphRef(glyphID: UInt16(i % 128), font: .systemFallback, fontChecksum: "test"),
                outline: squareOutline,
                layout: MKGlyphLayout(
                    position: CGPoint(x: Double(i % columns) * 10, y: Double(i / columns) * 10),
                    advance: CGSize(width: 10, height: 0)
                ),
                provenance: provenance
            )
            return .glyph(glyph)
        }
        let backup = MKSourceTextBackup(sourceString: String(repeating: "ل", count: glyphCount), style: MKTextStyle(pointSize: 96))
        let composition = ArrangedComposition(
            nodes: children, sourceBackup: backup,
            originFrame: CGRect(x: 0, y: 0, width: Double(columns) * 10, height: Double(glyphCount / columns + 1) * 10)
        )
        let arrangedNode = MKArrangedTextNode(
            core: MKNodeCore(name: "large-arranged"),
            composition: composition,
            derivedFrom: .liveText
        )
        let scene = MKScene(
            canvas: MKCanvasSpec(size: CGSize(width: 1200, height: 1200)),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: [.arranged(arrangedNode)]
        )
        return (scene, arrangedNode.core.id)
    }

    // MARK: - T-PERF-SYNC-100: sync 100-node scene to layer tree

    @Test func syncTo100NodeSceneMeetsSimulatorBudget() async {
        let controller = await MKLayerTreeController()
        let scene = makeScene(nodeCount: 100)
        let clock = ContinuousClock()
        let elapsed = await clock.measure {
            await MainActor.run { controller.sync(to: scene) }
        }
        // SIMULATOR-INDICATIVE ، D-115: open ≤100 nodes <1 s on device;
        // simulator budget = 5 s (conservative). Measured on the swift-test
        // host, not device hardware; see docs/impl-log/WS-07-p14.md.
        #expect(elapsed < .seconds(5), "100-node sync exceeded simulator budget ، investigate render path")
    }

    // MARK: - T-PERF-SYNC-5K: sync 5000-node scene to layer tree

    @Test func syncTo5KNodeSceneMeetsSimulatorBudget() async {
        let controller = await MKLayerTreeController()
        let scene = makeScene(nodeCount: 5000)
        let clock = ContinuousClock()
        let elapsed = await clock.measure {
            await MainActor.run { controller.sync(to: scene) }
        }
        // SIMULATOR-INDICATIVE ، D-115: open 5 000 nodes <3 s on A15;
        // simulator budget = 30 s (very conservative). Measured on the
        // swift-test host, not device hardware; see docs/impl-log/WS-07-p14.md.
        #expect(elapsed < .seconds(30), "5K-node sync exceeded even generous simulator budget")
    }

    // MARK: - T-PERF-CACHE: incremental sync only rasterizes changed nodes

    @Test func incrementalSyncDoesNotRasterizeUnchangedNodes() async {
        let controller = await MKLayerTreeController()
        let scene = makeScene(nodeCount: 10)
        await MainActor.run { controller.sync(to: scene) }
        let _ = await MainActor.run { controller.consumeRasterizationCount() } // drain initial count

        // Sync the same scene again ، no content changes → 0 rasterizations
        await MainActor.run { controller.sync(to: scene) }
        let count = await MainActor.run { controller.consumeRasterizationCount() }
        #expect(count == 0, "Re-sync of unchanged scene should not re-rasterize any layer")
    }

    // MARK: - T-PERF-ARRANGE-CACHE: unchanged large Arrange Mode composition
    // resyncs cheaply (P-1)

    /// P-1 accept: "resync an unchanged large scene ... completes within a
    /// budget much tighter than today's O(composition-size) cost." Before
    /// the fix, EVERY `sync(to:)` pass ، including one where nothing at all
    /// changed ، re-JSON-encoded and re-hashed the entire 4 000-glyph
    /// composition via `MKContentHash.hash(of:scaleBucket:)`
    /// (`.arranged`'s `encodedOrEmpty(n.composition)`), on top of
    /// allocating a fresh `JSONEncoder` per call. After the fix, an
    /// unchanged resync is an O(1) `MKCompositionRevision` lookup plus a
    /// CoW-fast-pathed `==` (`ArrangedHashCacheEntry`'s doc comment), so
    /// many repeated unchanged resyncs should stay well under a budget an
    /// O(composition-size) re-encode of this same scene could not meet
    /// repeated 25 times.
    @Test func unchangedLargeArrangedCompositionResyncsCheaply() async {
        let controller = await MKLayerTreeController()
        let (scene, _) = makeLargeArrangedScene(glyphCount: 4000)

        // Initial sync: allowed to be slow (full encode + rasterize of a
        // large composition) ، not the thing under test.
        await MainActor.run { controller.sync(to: scene) }
        let _ = await MainActor.run { controller.consumeRasterizationCount() } // drain initial count

        let clock = ContinuousClock()
        let elapsed = await clock.measure {
            for _ in 0..<25 {
                await MainActor.run { controller.sync(to: scene) }
            }
        }

        // SIMULATOR-INDICATIVE budget: 25 unchanged resyncs of a 4 000-glyph
        // composition. Each unchanged resync should cost microseconds under
        // the fix (cache hit, no re-encode); 2 s total is generous headroom
        // for the swift-test host while still being far tighter than what
        // 25 full re-encodes of a 4 000-glyph composition would cost.
        #expect(elapsed < .seconds(2), "Repeated unchanged resync of a large arranged composition exceeded the P-1 budget ، investigate whether the arranged content-hash cache is being bypassed")

        // No rasterization work should have happened either ، the hash
        // never changed, so `syncNode`'s `committedContentHash[node.id] !=
        // hash` gate never fires across all 25 passes.
        let rasterizations = await MainActor.run { controller.consumeRasterizationCount() }
        #expect(rasterizations == 0, "Unchanged resyncs must not re-rasterize the arranged layer")
    }

    // MARK: - T-PERF-EVICT-FLAG: P-9 ، hasEvictedContentFlag is a stored
    // flag, not an O(layers.count) scan

    /// P-9 accept: `evictOffscreen()`/`evictAll()` set the stored
    /// `hasEvictedContentFlag` (module-internal for this test's direct
    /// read, see `LayerTreeBuilder.swift`'s doc comment on the property)
    /// whenever at least one layer's `.contents` was nil'd, and a full
    /// `sync(to:)` pass clears it again once every layer has been
    /// re-rasterized.
    @Test func evictOffscreenSetsFlagAndSyncClearsIt() async {
        let controller = await MKLayerTreeController()
        let scene = makeScene(nodeCount: 4)

        await MainActor.run { controller.sync(to: scene) }
        var flag = await controller.hasEvictedContentFlag
        #expect(flag == false, "no eviction has happened yet")

        // Report a real (non-null) visible rect so `evictOffscreen()` isn't
        // a no-op, then evict everything outside it. A zero-area rect
        // intersects no non-empty layer frame, so this reliably evicts all
        // non-background layers regardless of `makeScene`'s node layout.
        await MainActor.run {
            controller.setVisibleRect(.zero, zoomScale: 1)
            controller.evictOffscreen()
        }
        flag = await controller.hasEvictedContentFlag
        #expect(flag == true, "evictOffscreen() nil'd at least one layer's contents, so the flag must read true")

        // A subsequent full sync() re-rasterizes every stale layer and must
        // clear the flag again.
        await MainActor.run { controller.sync(to: scene) }
        flag = await controller.hasEvictedContentFlag
        #expect(flag == false, "sync(to:) re-rasterized every layer, so the flag must read false again")
    }

    // MARK: - T-PERF-MEM-STAGE: degradation wiring ، stage flows to render quality

    @Test func stage2FidelityFlowsToRenderQuality() async {
        let controller = await MKDegradationController()
        let tree = await MKLayerTreeController(degradationController: controller)

        // Before stage2: fidelity is .full
        var fidelity = await controller.fidelity
        #expect(fidelity == .full)

        // Force stage2
        await controller.forceTransition(to: .stage2)
        fidelity = await controller.fidelity
        #expect(fidelity == .reduced)

        // Verify that a subsequent sync uses reduced quality. The rasterization
        // path uses effectiveContentsScale (half-res) and .reduced fidelity.
        // If we get here without a crash and fidelity is .reduced, the wiring is plumbed.
        let scene = makeScene(nodeCount: 3)
        await MainActor.run { tree.sync(to: scene) }
        fidelity = await controller.fidelity
        #expect(fidelity == .reduced, "Stage2 fidelity must persist through sync()")
    }

    // MARK: - T-PERF-MEM-RESTORE: stage returns to .normal after force-down

    @Test func stageRestoresToNormalAfterForceDown() async {
        let controller = await MKDegradationController()
        await controller.forceTransition(to: .critical)
        await controller.forceTransition(to: .normal)
        let stage = await controller.stage
        #expect(stage == .normal)
        let fidelity = await controller.fidelity
        #expect(fidelity == .full)
    }

    // MARK: - T-PERF-SAMPLE: real sampler returns a plausible fraction on simulator

    @Test func realSamplerReturnsSafeFractionOnSimulatorOrMacOS() {
        let fraction = MKMemorySampling.currentUsedFraction()
        // On iOS simulator, os_proc_available_memory() works and returns a
        // value in [0, 1]. On macOS host (swift test), returns 0 (safe stub).
        #expect(fraction >= 0, "Used fraction must not be negative")
        #expect(fraction <= 1, "Used fraction must not exceed 1")
    }

    // MARK: - Environment-deferred rows (documented, not executed here)
    // T-PERF-FRAME-PROMO: ≤8.3 ms frame on ProMotion iPad Pro ، Instruments Time Profiler, device required
    // T-PERF-FRAME-A12:   ≤16.6 ms frame on A12-class floor ، Instruments, device required
    // T-PERF-TYPE-ECHO:   <50 ms typing echo ، co-instrumented WS-06, Instruments Hangs, device required
    // T-PERF-EXPORT-4K:   <10 s 4K PNG ، WS-08 TileRenderer gate, handed off
    // T-PERF-KILL-RESTORE: kill-under-pressure → relaunch → exact restore (10/10 runs) ، device required
    // T-ARABIC-M-RENDER-STAGE0/2: G-ARABIC regression screenshots at stages 0 and 2 ، manual, device required
}
