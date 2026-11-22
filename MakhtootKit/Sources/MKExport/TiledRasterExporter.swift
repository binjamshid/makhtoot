import CoreGraphics
import Foundation
import MKModel
import MKRender
#if canImport(Darwin)
import Darwin
#endif

// WS-08 packet §5 task 8 ، "the memory-safety core". D-210 (tiled strip
// rendering) amended by D-223 (static 64 MB strip sizing + stage-3 PAUSE,
// never mid-export shrink ، D-210's "monitor can shrink strip height
// mid-export" claim is struck). Reuses WS-07's EXISTING single render path
// unchanged (`MKSnapshotRenderer.render`/`MKTileRenderer.tileRects` ،
// D-118/INV-2/INV-6: "there is exactly one context-creation helper and one
// drawing entry point" ، this file adds ZERO new drawing code, only
// bounds/assembly code around the existing entry point, same posture
// WS07-A2 already documented for its own tiling primitive).
//
// **ADR WS08-A1 (tiled strips + mmap assembly) ، implementation choice,
// logged per the packet's §10 codebase-memory duty**: ARCHITECTURE
// §16.4's illustrative pseudocode describes rendering each strip DIRECTLY
// into an offset pointer within one shared mmap'd buffer
// (`CGBitmapContext(data: basePtr + offset, …)`). This file instead
// renders EACH TILE into its OWN small, bounded `CGBitmapContext` via the
// unchanged `MKSnapshotRenderer.render` entry point (exactly as every
// other MKRender consumer does), then composites that tile's `CGImage`
// into a SEPARATE mmap-backed "assembly" context via `CGContext.draw(_:
// in:)` with interpolation disabled and integral destination rects.
// Tradeoff, stated once here (matches WS07-A2's own documented-tradeoff
// precedent): one extra `draw()` compositing pass per tile, in exchange
// for (a) reusing the renderer's own coordinate math with ZERO
// reimplementation risk (no hand-rolled row-order/byte-layout assumptions
// about a raw CG bitmap buffer, which is genuinely implementation-defined
// and the exact class of bug D-210 itself calls out as "an implementation
// risk flagged to WS-08... at pathological sizes"), and (b) every
// individual CG allocation staying provably ≤`maxTileBytes` (task 8
// accept: "8192×8192 PNG export peaks <300 MB resident"). The BIG buffer
// (`pixelWidth × pixelHeight × 4` bytes) is backed by an `mmap`'d,
// `unlink`'d-immediately temp file ، "unlink-then-hold-open" is the
// standard POSIX idiom for anonymous-yet-disk-backed storage, which is
// also what makes task 8's "cancellation between strips leaves no temp
// files" accept criterion trivially true (the file is never visible in any
// directory listing, from the instant it's created).
public protocol MKExportMemoryCooperating: Sendable {
    /// Checked at the top of every tile iteration AND inside the pause
    /// loop. `Task.checkCancellation()`/structured-concurrency cancellation
    /// is ALSO honored independently ، this is the caller-driven signal
    /// (e.g. a Cancel button), not a replacement for it.
    func isCancelled() -> Bool
    /// D-223: true while the memory ladder is at stage-3/critical. The
    /// CURRENTLY-RENDERING strip always completes first (never torn
    /// mid-strip, per D-223) ، this is checked only BETWEEN strips.
    func shouldPauseBeforeNextStrip() -> Bool
}

/// The default ، no memory-pressure integration, no cancellation. Real
/// wiring to WS-07's `MKMemoryPressureMonitor`/`MKDegradationController`
/// is an `ExportCoordinator`/app-composition-root concern
/// (`MKRender` → `MKExport` is already a real dependency edge, so a real
/// conformer can observe `MKDegradationController.stage` directly without
/// a new protocol on the `MKRender` side).
public struct MKNoOpMemoryCooperation: MKExportMemoryCooperating, Sendable {
    public init() {}
    public func isCancelled() -> Bool { false }
    public func shouldPauseBeforeNextStrip() -> Bool { false }
}

public enum MKTiledRasterExporter {
    /// Renders `scene` at `pixelSize` (device pixels ، already resolved by
    /// `ExportGate`/`ExportPresets`, free-tier-clamped or premium-native)
    /// and returns the assembled `CGImage`. Sizes whose FULL RGBA8
    /// footprint already fits `maxTileBytes` take the fast, untiled path
    /// (a single `MKSnapshotRenderer.render` call ، task 8's own
    /// ARCHITECTURE reference: "sizes where a single context fits the
    /// budget → single context"); larger sizes tile per D-210/D-223.
    public static func renderAssembled(
        scene: MKScene,
        pixelSize: CGSize,
        renderer: MKSnapshotRenderer = MKSnapshotRenderer(),
        quality: MKRenderQuality = .exportQuality,
        maxTileBytes: Int = MKTileRenderer.maxTileBytes,
        cooperation: any MKExportMemoryCooperating = MKNoOpMemoryCooperation(),
        pausePollNanoseconds: UInt64 = 200_000_000
    ) async throws -> CGImage {
        guard pixelSize.width > 0, pixelSize.height > 0 else { throw MKExportError.degenerateTargetSize }
        let canvasSize = scene.canvas.size
        guard canvasSize.width > 0, canvasSize.height > 0 else { throw MKExportError.degenerateTargetSize }

        let scale = pixelSize.width / canvasSize.width
        let canvasBounds = CGRect(origin: .zero, size: canvasSize)
        let pixelWidth = Int(pixelSize.width.rounded())
        let pixelHeight = Int(pixelSize.height.rounded())
        guard pixelWidth > 0, pixelHeight > 0 else { throw MKExportError.degenerateTargetSize }

        let estimatedBytes = pixelWidth * 4 * pixelHeight
        if estimatedBytes <= maxTileBytes {
            guard let image = renderer.render(scene, region: canvasBounds, scale: scale, quality: quality) else {
                throw MKExportError.renderingProducedNoImage
            }
            return image
        }

        if cooperation.isCancelled() { throw MKExportError.cancelled }
        let tileRects = MKTileRenderer.tileRects(covering: canvasBounds, scale: scale, maxBytes: maxTileBytes)
        guard !tileRects.isEmpty else { throw MKExportError.renderingProducedNoImage }

        let assembly = try MKMappedBitmapAssembly(pixelWidth: pixelWidth, pixelHeight: pixelHeight)
        do {
            for tileRect in tileRects {
                if cooperation.isCancelled() { throw MKExportError.cancelled }
                while cooperation.shouldPauseBeforeNextStrip() {
                    if cooperation.isCancelled() { throw MKExportError.cancelled }
                    try await Task.sleep(nanoseconds: pausePollNanoseconds)
                }
                try Task.checkCancellation()

                guard let tileImage = MKTileRenderer.renderTile(scene, rect: tileRect, scale: scale, quality: quality, renderer: renderer) else {
                    throw MKExportError.renderingProducedNoImage
                }
                assembly.draw(tileImage, canvasTileRect: tileRect, canvasBounds: canvasBounds, scale: scale)
            }
        } catch {
            assembly.discard()
            throw error
        }

        guard let image = assembly.finishAndMakeImage() else {
            throw MKExportError.renderingProducedNoImage
        }
        return image
    }
}

/// The mmap-backed assembly buffer described in the file header's ADR.
/// Not `Sendable`-shared across tasks (used only within one
/// `renderAssembled` call, sequentially) ، `final class` for reference
/// semantics over the raw pointer/fd, never exposed outside this file.
final class MKMappedBitmapAssembly {
    private let fd: Int32
    private var mapped: UnsafeMutableRawPointer?
    private let byteCount: Int
    private var ownershipTransferred = false
    let ctx: CGContext
    let pixelWidth: Int
    let pixelHeight: Int
    let bytesPerRow: Int

    init(pixelWidth: Int, pixelHeight: Int) throws {
        // Query CoreGraphics' own preferred `bytesPerRow` alignment for
        // this width via a throwaway 1-row probe context, so the mmap'd
        // buffer's stride matches EXACTLY what a real
        // `CGContext(data:...)` would choose (never hand-computed/assumed
        // ، row alignment padding is a CoreGraphics implementation detail).
        guard let probe = CGContext(
            data: nil, width: max(1, pixelWidth), height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw MKExportError.renderingProducedNoImage
        }
        let bpr = probe.bytesPerRow
        let totalBytes = bpr * pixelHeight
        guard totalBytes > 0 else { throw MKExportError.degenerateTargetSize }

        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-export-\(UUID().uuidString).tmp").path
        let opened = path.withCString { open($0, O_RDWR | O_CREAT | O_EXCL, 0o600) }
        guard opened >= 0 else { throw MKExportError.renderingProducedNoImage }
        // Unlink IMMEDIATELY: the open fd (and later the mmap) keep the
        // storage alive with no visible directory entry at any point ،
        // task 8 accept: "cancellation between strips leaves no temp
        // files" holds unconditionally, not just on the happy path.
        unlink(path)

        guard ftruncate(opened, off_t(totalBytes)) == 0 else {
            close(opened)
            throw MKExportError.renderingProducedNoImage
        }
        let ptr = mmap(nil, totalBytes, PROT_READ | PROT_WRITE, MAP_SHARED, opened, 0)
        guard ptr != UnsafeMutableRawPointer(bitPattern: -1), let ptr else {
            close(opened)
            throw MKExportError.renderingProducedNoImage
        }
        guard let context = CGContext(
            data: ptr, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: bpr,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            munmap(ptr, totalBytes)
            close(opened)
            throw MKExportError.renderingProducedNoImage
        }

        self.fd = opened
        self.mapped = ptr
        self.byteCount = totalBytes
        self.ctx = context
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.bytesPerRow = bpr
    }

    /// Composites one tile's already-rendered `CGImage` into the assembly
    /// context at the destination pixel rect corresponding to
    /// `canvasTileRect` within `canvasBounds` at `scale` ، the SAME
    /// canvas→device transform `MKSceneRenderer.canvasToDevice(region:
    /// scale:)` derives (that function is `internal` to `MKRender`, not
    /// exported, so its documented closed-form ، `a: scale, b: 0, c: 0,
    /// d: -scale, tx: -scale*region.origin.x, ty: scale*region.maxY` ، is
    /// replicated here verbatim; `SceneRendererTests` in `MKRenderTests`
    /// is the source of truth this must keep matching). Interpolation is
    /// disabled and the destination rect is pixel-integral so adjacent
    /// tiles abut with no seam resampling (D-210: "strip clipping must not
    /// change antialiasing at seams").
    func draw(_ tileImage: CGImage, canvasTileRect: CGRect, canvasBounds: CGRect, scale: CGFloat) {
        let canvasToDevice = CGAffineTransform(
            a: scale, b: 0, c: 0, d: -scale,
            tx: -scale * canvasBounds.origin.x, ty: scale * canvasBounds.maxY
        )
        let deviceRect = canvasTileRect.applying(canvasToDevice).integral
        ctx.interpolationQuality = .none
        ctx.draw(tileImage, in: deviceRect)
    }

    /// Flushes pending draws, hands the mmap'd buffer's OWNERSHIP to a
    /// zero-copy `Data`/`CGDataProvider` chain, and returns the assembled
    /// `CGImage`. The `munmap`+`close` pair runs exactly once, whenever the
    /// LAST reference into that chain (the returned `CGImage`, or nothing
    /// if this method itself fails) is released ، best-effort zero-copy:
    /// `Data(bytesNoCopy:...)`'s bridge to `CFData` is not contractually
    /// guaranteed copy-free by Foundation, but is the standard/expected
    /// behavior on Apple platforms for this exact pattern (documented
    /// assumption, not independently re-verified this session ، flagged
    /// for the P14 hardening pass alongside D-210's other stated
    /// unknowns).
    func finishAndMakeImage() -> CGImage? {
        ctx.flush()
        guard let mapped else { return nil }
        let capturedFD = fd
        let capturedBytes = byteCount
        let data = Data(bytesNoCopy: mapped, count: byteCount, deallocator: .custom { ptr, count in
            munmap(ptr, count)
            close(capturedFD)
            _ = capturedBytes
        })
        ownershipTransferred = true
        self.mapped = nil

        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    /// Error/cancellation path: unmap and close directly (no `CGImage` was
    /// ever produced, so nothing else could hold a reference).
    func discard() {
        guard !ownershipTransferred else { return }
        if let mapped {
            munmap(mapped, byteCount)
            self.mapped = nil
        }
        close(fd)
        ownershipTransferred = true
    }

    deinit {
        // Safety net: `discard()` should always have run on every non-
        // success path, and `finishAndMakeImage()` transfers ownership on
        // success ، this only fires if a future call site forgets one of
        // the two, and prevents a leaked fd/mapping either way.
        if !ownershipTransferred {
            if let mapped { munmap(mapped, byteCount) }
            close(fd)
        }
    }
}
