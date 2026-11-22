import Testing
import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKRender
@testable import MKExport

/// EU-4 (AUDIT_2026-07-28.md): `MKExportCoordinator.progressUpdates()` /
/// `MKExportCancellationToken` regression coverage. Every case here forces
/// a genuinely TILED render (not the untiled fast path a small export
/// takes) via `MKExportCoordinator(maxTileBytes:)` — mirroring
/// `TiledRasterExporterTests`' own `maxTileBytes:` override pattern on
/// `MKTiledRasterExporter.renderAssembled` directly, just one layer up,
/// through the real PUBLIC `MKExportCoordinator.export(...)` API — so this
/// stays fast and deterministic instead of actually rendering a 4096px+
/// bitmap in a unit test. Production call sites never override
/// `maxTileBytes`, so this exercises the exact same code path production
/// takes, just at a smaller, cheaper tile grid.
@Suite struct ExportCoordinatorProgressTests {
    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mk-export-progress-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// A tiny `maxTileBytes` on a 512×512 canvas forces the SAME 4×4 = 16
    /// tile grid `TiledRasterExporterTests
    /// .tiledPathIsPixelIdenticalToUntiledForEvenlyDivisibleDimensions`
    /// already relies on for a fast, deterministic tile count at this exact
    /// budget/canvas-size pair (128pt tiles, dividing 512 evenly).
    @Test func progressFiresMonotonicallyFromZeroToOneDuringATiledExport() async throws {
        let coordinator = MKExportCoordinator(maxTileBytes: 64 * 1024)
        let scene = TestScenes.rectScene(canvasSize: CGSize(width: 512, height: 512))
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Subscribe BEFORE `export(...)` starts (per `progressUpdates()`'s
        // own doc comment) ، consumed concurrently on a separate `Task` so
        // it doesn't block the `export(...)` call below.
        let progressStream = await coordinator.progressUpdates()
        let collector = Task<[Double], Never> {
            var collected: [Double] = []
            for await fraction in progressStream { collected.append(fraction) }
            return collected
        }

        let result = try await coordinator.export(
            MKExportRequest(format: .pngOpaque, target: .custom(pixelSize: CGSize(width: 512, height: 512))),
            scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium, destinationDirectory: dir
        )
        #expect(FileManager.default.fileExists(atPath: result.fileURL.path))

        let observed = await collector.value
        #expect(!observed.isEmpty, "a genuinely tiled export must yield at least one progress fraction")
        #expect(observed.allSatisfy { $0 >= 0 && $0 <= 1 }, "every fraction must land in 0...1")
        #expect(observed == observed.sorted(), "progress must be monotonically nondecreasing")
        #expect(observed.last == 1.0, "the final progress value must reach exactly 1.0")
        // 16 tiles + 1 pre-loop check (`TiledRasterExporter.swift`'s own
        // call cadence, mirrored by `MKExportCoordinator
        // .expectedTileCount(canvasSize:pixelSize:)`) = 17 calls.
        #expect(observed.count == 17)
    }

    /// An export small enough to take the untiled fast path
    /// (`MKTiledRasterExporter.renderAssembled`'s own `estimatedBytes <=
    /// maxTileBytes` branch) never touches `MKExportMemoryCooperating
    /// .isCancelled()` at all (`TiledRasterExporter.swift`, unmodified) ،
    /// so a caller that subscribed to `progressUpdates()` still gets a
    /// clean, immediately-finished, zero-value stream, never a hang.
    @Test func untiledFastPathYieldsNoProgressButStillFinishesTheStream() async throws {
        let coordinator = MKExportCoordinator()
        let scene = TestScenes.rectScene(canvasSize: CGSize(width: 64, height: 64))
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let progressStream = await coordinator.progressUpdates()
        let collector = Task<[Double], Never> {
            var collected: [Double] = []
            for await fraction in progressStream { collected.append(fraction) }
            return collected
        }

        _ = try await coordinator.export(
            MKExportRequest(format: .pngOpaque, target: .custom(pixelSize: CGSize(width: 64, height: 64))),
            scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium, destinationDirectory: dir
        )

        let observed = await collector.value
        #expect(observed.isEmpty)
    }

    /// A vector format (never routed through `MKTiledRasterExporter` at
    /// all, see `MKExportCoordinator.export(_:)`'s own `.svg`/
    /// `.pdfVectorRGB` dispatch arms) behaves the same way ، zero progress
    /// values, stream still finishes cleanly.
    @Test func vectorFormatYieldsNoProgressButStillFinishesTheStream() async throws {
        let coordinator = MKExportCoordinator()
        let scene = TestScenes.rectScene()
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let progressStream = await coordinator.progressUpdates()
        let collector = Task<[Double], Never> {
            var collected: [Double] = []
            for await fraction in progressStream { collected.append(fraction) }
            return collected
        }

        _ = try await coordinator.export(
            MKExportRequest(format: .svg, target: .preset(id: "social.square")),
            scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium, destinationDirectory: dir
        )

        let observed = await collector.value
        #expect(observed.isEmpty)
    }

    // MARK: - MKExportCancellationToken

    /// Cancelling an `MKExportCancellationToken` (passed as `cooperation:`,
    /// EU-4's UI-facing handle) before a tiled export even starts stops it
    /// and throws `MKExportError.cancelled` ، the SAME
    /// `MKExportMemoryCooperating.isCancelled()` call sites
    /// `TiledRasterExporterTests`'s own `AlwaysCancelledCooperation`
    /// already exercises directly against `MKTiledRasterExporter`, here
    /// exercised end-to-end through the PUBLIC `MKExportCoordinator
    /// .export(cooperation:)` API instead.
    @Test func cancellationTokenStopsATiledExportAndThrowsCancelled() async {
        let coordinator = MKExportCoordinator(maxTileBytes: 64 * 1024)
        let scene = TestScenes.rectScene(canvasSize: CGSize(width: 512, height: 512))
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let token = MKExportCancellationToken()
        token.cancel()

        await #expect(throws: MKExportError.cancelled) {
            _ = try await coordinator.export(
                MKExportRequest(format: .pngOpaque, target: .custom(pixelSize: CGSize(width: 512, height: 512))),
                scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium, destinationDirectory: dir,
                cooperation: token
            )
        }

        let contents = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        #expect(contents.isEmpty, "a cancelled export must not leave a partial output file")
    }

    /// Cancellation partway through a multi-tile render (after a few tiles
    /// have already completed and reported progress), not just the
    /// "already cancelled before the first check" case above. Uses a
    /// deterministic, call-count-driven `MKExportMemoryCooperating`
    /// conformer (mirrors `TiledRasterExporterTests
    /// .CancelAfterFirstTileCooperation`'s own pattern exactly) rather than
    /// a real concurrent `Task` racing to call `.cancel()` at "the right
    /// moment" ، that would make this test flaky by construction on a
    /// multi-core scheduler. This ALSO proves progress-tracking composes
    /// with (never replaces) a caller-supplied `cooperation:` conformer
    /// other than `MKExportCancellationToken` itself, per
    /// `MKExportProgressTrackingCooperation`'s own doc comment.
    private final class CancelAfterNCallsCooperation: MKExportMemoryCooperating, @unchecked Sendable {
        private let lock = NSLock()
        private var calls = 0
        private let cancelAfter: Int
        init(cancelAfter: Int) { self.cancelAfter = cancelAfter }
        func isCancelled() -> Bool {
            lock.lock(); defer { lock.unlock() }
            calls += 1
            return calls > cancelAfter
        }
        func shouldPauseBeforeNextStrip() -> Bool { false }
    }

    @Test func cancellationMidExportStopsItAndComposesWithProgressTracking() async throws {
        let coordinator = MKExportCoordinator(maxTileBytes: 64 * 1024)
        let scene = TestScenes.rectScene(canvasSize: CGSize(width: 512, height: 512))
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Allow the pre-loop check + first 3 tiles through (calls 1-4 all
        // report "not cancelled"), then report cancelled on call 5 ، the
        // loop throws immediately, never reaching the remaining 13 tiles.
        let cooperation = CancelAfterNCallsCooperation(cancelAfter: 4)
        let progressStream = await coordinator.progressUpdates()
        let collector = Task<[Double], Never> {
            var collected: [Double] = []
            for await fraction in progressStream { collected.append(fraction) }
            return collected
        }

        await #expect(throws: MKExportError.cancelled) {
            _ = try await coordinator.export(
                MKExportRequest(format: .pngOpaque, target: .custom(pixelSize: CGSize(width: 512, height: 512))),
                scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium, destinationDirectory: dir,
                cooperation: cooperation
            )
        }

        let observed = await collector.value
        // `MKExportProgressTrackingCooperation.isCancelled()` yields a
        // fraction on EVERY call, including the 5th (the one that reports
        // cancelled) ، exactly 5 values expected, matching `cancelAfter: 4`.
        #expect(observed.count == 5)
        #expect(observed == observed.sorted())
        let last = try #require(observed.last)
        #expect(last < 1.0, "a cancelled export must never report 100% progress")
    }

    /// A fresh token that is never cancelled has no effect ، `export(...)`
    /// completes normally end to end (belt-and-suspenders against a
    /// regression where merely CONSTRUCTING/PASSING a token would itself
    /// block or interfere with the export).
    @Test func unCancelledTokenDoesNotAffectANormalExport() async throws {
        let coordinator = MKExportCoordinator()
        let scene = TestScenes.rectScene()
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let token = MKExportCancellationToken()
        let result = try await coordinator.export(
            MKExportRequest(format: .jpegDefault, target: .preset(id: "social.square")),
            scene: scene, entitlement: FakeEntitlementResolver.alwaysFree, destinationDirectory: dir,
            cooperation: token
        )
        #expect(FileManager.default.fileExists(atPath: result.fileURL.path))
    }
}
