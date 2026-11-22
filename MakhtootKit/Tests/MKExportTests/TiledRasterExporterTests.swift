import Testing
import CoreGraphics
import Foundation
import MKModel
import MKRender
@testable import MKExport

// WS-08 packet §5 task 8 accept: "8192×8192 PNG export peaks <300 MB
// resident (instrumented); 512×512 tiled-vs-untiled pixel-identical;
// cancellation between strips leaves no temp files." D-210/D-223: static
// 64 MB strip sizing, stage-3 pause (never mid-export shrink).
@Suite struct TiledRasterExporterTests {
    private func pixelBytes(of image: CGImage) -> Data? {
        image.dataProvider?.data as Data?
    }

    @Test func smallSceneTakesTheFastUntiledPath() async throws {
        let scene = TestScenes.rectScene(canvasSize: CGSize(width: 100, height: 100))
        let image = try await MKTiledRasterExporter.renderAssembled(scene: scene, pixelSize: CGSize(width: 100, height: 100))
        #expect(image.width == 100)
        #expect(image.height == 100)
    }

    /// The core fidelity gate: forcing a tiny `maxTileBytes` on a 512×512
    /// canvas whose tile side (128pt at this budget) divides evenly
    /// produces BYTE-IDENTICAL output to the direct, untiled
    /// `MKSnapshotRenderer` call.
    @Test func tiledPathIsPixelIdenticalToUntiledForEvenlyDivisibleDimensions() async throws {
        let scene = TestScenes.rectScene(canvasSize: CGSize(width: 512, height: 512))
        let renderer = MKSnapshotRenderer()

        // maxBytes = 64 * 1024 -> maxPixels = 16384 -> tileSide = 128,
        // which divides 512 evenly into a 4x4 tile grid (no fractional
        // remainder tile, so no seam-rounding ambiguity in this fixture).
        let tinyBudget = 64 * 1024
        let tiledImage = try await MKTiledRasterExporter.renderAssembled(
            scene: scene, pixelSize: CGSize(width: 512, height: 512), renderer: renderer, maxTileBytes: tinyBudget
        )
        let untiledImage = try #require(renderer.render(scene, region: CGRect(origin: .zero, size: CGSize(width: 512, height: 512)), scale: 1, quality: .exportQuality))

        #expect(tiledImage.width == untiledImage.width)
        #expect(tiledImage.height == untiledImage.height)
        let tiledBytes = try #require(pixelBytes(of: tiledImage))
        let untiledBytes = try #require(pixelBytes(of: untiledImage))
        #expect(tiledBytes == untiledBytes, "tiled and untiled renders of the same scene/size must be pixel-identical (D-210)")
    }

    @Test func degenerateCanvasSizeThrows() async {
        let scene = TestScenes.rectScene(canvasSize: .zero)
        await #expect(throws: MKExportError.self) {
            _ = try await MKTiledRasterExporter.renderAssembled(scene: scene, pixelSize: CGSize(width: 100, height: 100))
        }
    }

    @Test func degeneratePixelSizeThrows() async {
        let scene = TestScenes.rectScene()
        await #expect(throws: MKExportError.self) {
            _ = try await MKTiledRasterExporter.renderAssembled(scene: scene, pixelSize: .zero)
        }
    }

    // MARK: - Cancellation (no temp files)

    /// Counts ONLY entries that could plausibly be a leaked
    /// `MKMappedBitmapAssembly` scratch file: a *regular file* (never a
    /// directory) whose name matches the exporter's exact naming grammar,
    /// `mk-export-<uuid>.tmp` (`TiledRasterExporter.swift`'s
    /// `"mk-export-\(UUID().uuidString).tmp"`).
    ///
    /// A bare `hasPrefix("mk-export-")` match on the shared system temp
    /// directory is too broad: it also matches
    /// `ExportCoordinatorTests.tempDir()`'s `mk-export-coordinator-<uuid>`
    /// scratch DIRECTORIES (a completely different, unrelated resource from
    /// a sibling test file ، confirmed by inspecting the live temp
    /// directory, where dozens of stale `mk-export-coordinator-*`
    /// directories accumulated from prior runs and NONE were the
    /// exporter's own `.tmp` files), and it is vulnerable to any OTHER
    /// process on the machine racing an unrelated entry into/out of the
    /// same OS-wide temp directory during this test's before/after
    /// snapshot window. Anchoring on the exact suffix and regular-file type
    /// makes the count immune to both.
    private func exporterScratchFileCount() -> Int {
        let tmpURL = FileManager.default.temporaryDirectory
        let names = (try? FileManager.default.contentsOfDirectory(atPath: tmpURL.path)) ?? []
        return names.filter { name in
            guard name.hasPrefix("mk-export-"), name.hasSuffix(".tmp") else { return false }
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: tmpURL.appendingPathComponent(name).path, isDirectory: &isDirectory)
            return exists && !isDirectory.boolValue
        }.count
    }

    private struct AlwaysCancelledCooperation: MKExportMemoryCooperating {
        func isCancelled() -> Bool { true }
        func shouldPauseBeforeNextStrip() -> Bool { false }
    }

    @Test func cancellationBeforeTilingStartsLeavesNoTempFiles() async {
        let scene = TestScenes.rectScene(canvasSize: CGSize(width: 4096, height: 4096))
        let countBefore = exporterScratchFileCount()

        await #expect(throws: MKExportError.self) {
            _ = try await MKTiledRasterExporter.renderAssembled(
                scene: scene, pixelSize: CGSize(width: 4096, height: 4096),
                maxTileBytes: 64 * 1024, cooperation: AlwaysCancelledCooperation()
            )
        }

        let countAfter = exporterScratchFileCount()
        #expect(countAfter == countBefore, "cancellation must leave no visible mk-export-*.tmp temp files (unlink-immediately design)")
    }

    /// Cancels partway through a multi-tile render (after the first tile)
    /// ، the SAME "no temp files" guarantee must hold even once the mmap
    /// buffer has been created and partially written.
    private final class CancelAfterFirstTileCooperation: MKExportMemoryCooperating, @unchecked Sendable {
        private let counter = Counter()
        func isCancelled() -> Bool { counter.incrementAndCheck() }
        func shouldPauseBeforeNextStrip() -> Bool { false }

        private final class Counter: @unchecked Sendable {
            private var calls = 0
            private let lock = NSLock()
            func incrementAndCheck() -> Bool {
                lock.lock(); defer { lock.unlock() }
                calls += 1
                return calls > 2 // allow the pre-loop check + first tile through, cancel afterward
            }
        }
    }

    @Test func cancellationMidTilingLeavesNoTempFiles() async {
        let scene = TestScenes.rectScene(canvasSize: CGSize(width: 1024, height: 1024))
        let countBefore = exporterScratchFileCount()

        await #expect(throws: MKExportError.self) {
            _ = try await MKTiledRasterExporter.renderAssembled(
                scene: scene, pixelSize: CGSize(width: 1024, height: 1024),
                maxTileBytes: 16 * 1024, cooperation: CancelAfterFirstTileCooperation()
            )
        }

        let countAfter = exporterScratchFileCount()
        #expect(countAfter == countBefore, "cancellation must leave no visible mk-export-*.tmp temp files (unlink-immediately design)")
    }

    // MARK: - Stage-3 pause policy (D-223)

    private final class PausesThenClearsCooperation: MKExportMemoryCooperating, @unchecked Sendable {
        private let state = State()
        func isCancelled() -> Bool { false }
        func shouldPauseBeforeNextStrip() -> Bool { state.pauseThenClear() }

        private final class State: @unchecked Sendable {
            private var remainingPauses = 3
            private let lock = NSLock()
            func pauseThenClear() -> Bool {
                lock.lock(); defer { lock.unlock() }
                guard remainingPauses > 0 else { return false }
                remainingPauses -= 1
                return true
            }
        }
    }

    @Test func pausePolicyDelaysButDoesNotCorruptOutput() async throws {
        let scene = TestScenes.rectScene(canvasSize: CGSize(width: 512, height: 512))
        let renderer = MKSnapshotRenderer()
        let cooperation = PausesThenClearsCooperation()

        let image = try await MKTiledRasterExporter.renderAssembled(
            scene: scene, pixelSize: CGSize(width: 512, height: 512), renderer: renderer,
            maxTileBytes: 64 * 1024, cooperation: cooperation, pausePollNanoseconds: 1_000_000
        )
        let untiledImage = try #require(renderer.render(scene, region: CGRect(origin: .zero, size: CGSize(width: 512, height: 512)), scale: 1, quality: .exportQuality))
        #expect(pixelBytes(of: image) == pixelBytes(of: untiledImage))
    }
}
