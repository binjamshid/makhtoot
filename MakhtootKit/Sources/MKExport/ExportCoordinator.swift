import CoreGraphics
import Foundation
import MKColor
import MKFoundation
import MKModel
import MKRender

// WS-08 packet §5 task 18. P10-EARLY shipped raster formats
// (jpeg/pngOpaque/pngAlpha) only; P10-COMPLETION (Run-3,
// `docs/impl-log/WS-08.md`) adds the four PDF/SVG writers
// (`PDFRasterExporter`/`PDFVectorExporter`/`PDFPrintCMYKExporter`/
// `SVGSerializer`) behind the SAME gate → render/write → `MKExportResult`
// pipeline ، no format-specific branching exists above the gate check;
// only the terminal "which writer" dispatch differs.
//
// "Exports run off-main on snapshots (D-102), serialized one at a time":
// satisfied structurally ، `MKExportCoordinator` is an `actor`, so
// concurrent `export(...)` calls from multiple callers queue rather than
// interleave, and `scene`/`request` are both `Sendable` value types so no
// snapshot can be mutated out from under an in-flight export (D-102).
public protocol MKExportHistoryRecording: Sendable {
    func record(_ result: MKExportResult) async
    func recordFailure(_ error: Error, request: MKExportRequest) async
}

/// D-112-style history persistence is WS-02's `MKPersistence` metadata
/// store (ARCHITECTURE §16.7). `MetadataStore.recordExport(projectID:
/// format:pixelWidth:pixelHeight:presetID:wasPremium:success:)` already
/// ships (WS-02) ، this protocol's `record(_:projectID:presetID:
/// wasPremium:)` overload below carries EXACTLY those fields (plus the
/// `MKExportResult` itself) so a real conformer at the app composition
/// root is a mechanical 1-to-1 bridge, never a redesign. `MKExport`'s
/// `Package.swift`-declared dependency graph does not (and per
/// DEPENDENCY_GRAPH.md should not) include `MKPersistence` directly ، see
/// `MKExportFormat.metadataFormatString` for the vocabulary bridge (this
/// module owns the mapping since it owns `MKExportFormat`, not
/// `MKPersistence`).
public struct MKNoOpExportHistoryRecording: MKExportHistoryRecording {
    public init() {}
    public func record(_ result: MKExportResult) async {}
    public func recordFailure(_ error: Error, request: MKExportRequest) async {}
}

/// EU-4 (AUDIT_2026-07-28.md): a UI-facing cancellation handle. The caller
/// (`EditorViewModel`, per export call) creates ONE, passes it as
/// `export(...)`'s existing `cooperation:` parameter, keeps it around to
/// bind a Cancel button to `cancel()`, and lets it go out of scope once the
/// export completes. Conforms to `MKExportMemoryCooperating`
/// (`TiledRasterExporter.swift`, unmodified by this fix — its
/// `isCancelled()`/`shouldPauseBeforeNextStrip()` call sites inside
/// `MKTiledRasterExporter.renderAssembled`'s tile loop are exactly what
/// makes this token's `cancel()` actually stop an in-flight tiled/CMYK-PDF
/// export, with zero changes to that file). `final class` + `NSLock` (not
/// an `actor`): `isCancelled()` is a synchronous, non-`async` protocol
/// requirement, called directly from that loop with no `await` — it cannot
/// be actor-isolated state.
public final class MKExportCancellationToken: MKExportMemoryCooperating, @unchecked Sendable {
    private let lock = NSLock()
    private var cancelledFlag = false

    public init() {}

    /// Call from the UI's Cancel button. Safe from any thread/actor.
    public func cancel() {
        lock.lock()
        cancelledFlag = true
        lock.unlock()
    }

    public func isCancelled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelledFlag
    }

    /// No memory-pressure integration here (out of EU-4's scope — see
    /// `MKNoOpMemoryCooperation`'s own doc comment on that being a separate,
    /// composition-root concern) ، this token is cancellation-only.
    public func shouldPauseBeforeNextStrip() -> Bool { false }
}

/// EU-4: derives a monotonically nondecreasing 0→1 progress fraction purely
/// from the EXISTING call cadence of `MKExportMemoryCooperating
/// .isCancelled()` inside `MKTiledRasterExporter.renderAssembled`'s tile
/// loop (`TiledRasterExporter.swift`, unmodified, outside this agent's Owns
/// list for this wave): that loop calls `isCancelled()` exactly once before
/// the loop starts, plus once per tile (see that file's own call sites) ،
/// and never at all on the untiled fast path a small export takes, which is
/// exactly the "long export" scope EU-4 asks progress for.
/// `expectedTotalCalls` is computed independently by `MKExportCoordinator`
/// (mirroring `MKTiledRasterExporter`'s own tiling decision via the same
/// public `MKTileRenderer` API), so this stays correct with no change to
/// that file. Wraps (never replaces) whatever `cooperation` the caller
/// passed in, so an explicit `MKExportCancellationToken`/custom
/// `MKExportMemoryCooperating` still works exactly as before.
private final class MKExportProgressTrackingCooperation: MKExportMemoryCooperating, @unchecked Sendable {
    private let base: any MKExportMemoryCooperating
    private let expectedTotalCalls: Int
    private let continuation: AsyncStream<Double>.Continuation
    private let lock = NSLock()
    private var callCount = 0

    init(base: any MKExportMemoryCooperating, expectedTileCount: Int, continuation: AsyncStream<Double>.Continuation) {
        self.base = base
        // +1: the tile loop's own pre-loop check (`TiledRasterExporter
        // .swift`'s line ~103) fires once before any tile-specific check.
        self.expectedTotalCalls = max(expectedTileCount, 0) + 1
        self.continuation = continuation
    }

    func isCancelled() -> Bool {
        let cancelled = base.isCancelled()
        lock.lock()
        callCount += 1
        let fraction = min(1.0, Double(callCount) / Double(expectedTotalCalls))
        lock.unlock()
        continuation.yield(fraction)
        return cancelled
    }

    func shouldPauseBeforeNextStrip() -> Bool {
        base.shouldPauseBeforeNextStrip()
    }
}

public actor MKExportCoordinator {
    private let gate: MKExportGate
    private let history: any MKExportHistoryRecording
    private let renderer: MKSnapshotRenderer
    private let fonts: any MKFontProviding
    private let fontLicense: any FontLicenseProviding
    private let fontData: any MKExportFontDataProviding
    private let assets: any MKAssetProviding
    private let cmykProfile: () -> MKICCProfile
    /// EU-4: overridable ONLY so `ExportCoordinatorProgressTests` can force
    /// a small, fast, genuinely-multi-tile render (mirrors the existing
    /// `TiledRasterExporterTests`/`maxTileBytes:` override pattern) without
    /// actually rendering a 4096px+ bitmap in a unit test. Production call
    /// sites never override this, so behavior is unchanged from before this
    /// fix (`MKTileRenderer.maxTileBytes`, the same 64 MB budget
    /// `MKTiledRasterExporter.renderAssembled`'s own default already used).
    private let maxTileBytes: Int
    /// EU-4: set (once) by `progressUpdates()`, consumed and finished by
    /// the NEXT `export(...)` call. Every existing call site constructs a
    /// fresh `MKExportCoordinator` per export (`EditorViewModel`'s five
    /// export methods), so "one continuation per instance" matches actual
    /// usage.
    private var progressContinuation: AsyncStream<Double>.Continuation?

    public init(
        gate: MKExportGate = MKExportGate(),
        history: any MKExportHistoryRecording = MKNoOpExportHistoryRecording(),
        renderer: MKSnapshotRenderer = MKSnapshotRenderer(),
        fonts: any MKFontProviding = SystemFontStubProvider(),
        fontLicense: any FontLicenseProviding = AllOFLLicenseStub(),
        fontData: any MKExportFontDataProviding = MKNoFontDataProviding(),
        assets: any MKAssetProviding = MKEmptyAssetProvider(),
        cmykProfile: @escaping @Sendable () -> MKICCProfile = { ICCProfileStore.loadBundled() },
        maxTileBytes: Int = MKTileRenderer.maxTileBytes
    ) {
        self.gate = gate
        self.history = history
        self.renderer = renderer
        self.fonts = fonts
        self.fontLicense = fontLicense
        self.fontData = fontData
        self.assets = assets
        self.cmykProfile = cmykProfile
        self.maxTileBytes = maxTileBytes
    }

    /// EU-4: subscribe to progress updates for the NEXT `export(...)` call
    /// on this coordinator instance. Call this BEFORE `export(...)` (e.g.
    /// via `async let`/a concurrent `Task`), not after — an `AsyncStream`
    /// created once the tile loop has already started has nothing to
    /// replay. The stream finishes when `export(...)` returns or throws,
    /// whichever comes first — including immediately, with zero values, for
    /// formats that never touch the tiled/CMYK path (`.svg`,
    /// `.pdfVectorRGB`) or a canvas small enough to take the untiled fast
    /// path.
    public func progressUpdates() -> AsyncStream<Double> {
        AsyncStream { continuation in
            self.progressContinuation = continuation
        }
    }

    /// Mirrors `MKTiledRasterExporter.renderAssembled`'s own untiled-vs-
    /// tiled decision (`TiledRasterExporter.swift`, unmodified) via the
    /// same public `MKTileRenderer` API, so progress tracking stays exactly
    /// in sync with that file's real tile count without touching it.
    /// Returns 0 for the untiled fast path (no `isCancelled()` calls at all
    /// happen there).
    private func expectedTileCount(canvasSize: CGSize, pixelSize: CGSize) -> Int {
        guard canvasSize.width > 0, canvasSize.height > 0, pixelSize.width > 0, pixelSize.height > 0 else { return 0 }
        let scale = pixelSize.width / canvasSize.width
        let pixelWidth = Int(pixelSize.width.rounded())
        let pixelHeight = Int(pixelSize.height.rounded())
        let estimatedBytes = pixelWidth * 4 * pixelHeight
        guard estimatedBytes > maxTileBytes else { return 0 }
        let canvasBounds = CGRect(origin: .zero, size: canvasSize)
        return MKTileRenderer.tileRects(covering: canvasBounds, scale: scale, maxBytes: maxTileBytes).count
    }

    /// The full gate-check → pipeline-dispatch → result pipeline (task 18).
    /// `filenameBase` is the (already project-title-derived, if the caller
    /// has one) string `MKFilenameSanitizer` runs on ، see that file's
    /// header for why `MKScene` itself carries no title.
    @discardableResult
    public func export(
        _ request: MKExportRequest,
        scene: MKScene,
        entitlement: any MKEntitlementProviding,
        premiumAssetNodeIDs: Set<MKNodeID> = [],
        filenameBase: String = "مخطوط",
        destinationDirectory: URL = FileManager.default.temporaryDirectory,
        cooperation: any MKExportMemoryCooperating = MKNoOpMemoryCooperation()
    ) async throws -> MKExportResult {
        let start = Date()
        // P14 hardening pass (docs/impl-log/WS-07-p14-run3.md, item 2):
        // `WS-08`'s own impl log recorded "signposts not added this session
        // (P10-completion polish)" for `ExportCoordinator` ، the <10 s 4K
        // export budget (D-115) had zero `xctrace`-visible instrumentation
        // anywhere. A raw `beginInterval`/`endInterval` pair (same idiom
        // `MakhtootDocument.open`/`AutosaveController.flushNow` already use)
        // rather than `MKRender`'s `MKRenderSignposts.interval` closure
        // wrapper ، `MKExportCoordinator` is an `actor`, and handing an
        // actor-isolated closure to that wrapper's nonisolated static
        // method trips Swift 6's `SendingRisksDataRace` diagnostic (probed:
        // confirmed by trying the wrapper first). `defer` covers every
        // return/throw path below, including a `.blocked` gate decision.
        let signpostState = MKSignpost.signposter.beginInterval("export")
        defer { MKSignpost.signposter.endInterval("export", signpostState) }
        // EU-4: covers EVERY exit path below, including the early
        // `.blocked` gate throw — a caller that subscribed via
        // `progressUpdates()` must always see its stream finish, never hang
        // waiting on a continuation this call never touches again.
        defer {
            progressContinuation?.finish()
            progressContinuation = nil
        }

        let decision = gate.evaluate(request, scene: scene, entitlement: entitlement, premiumAssetNodeIDs: premiumAssetNodeIDs)
        let pixelSize: CGSize
        switch decision {
        case .allowed(let resolved):
            pixelSize = resolved
        case .blocked(let reason):
            let error = MKExportError.blocked(reason)
            await history.recordFailure(error, request: request)
            throw error
        }

        var fallbacks: [FallbackNote] = []
        if !entitlement.state.grantsPremiumAccess {
            let baseSize = baseTargetSize(for: request.target)
            if let baseSize, MKFreeTierBudget.exceedsBudget(baseSize) {
                fallbacks.append(FallbackNote(reason: .downscaledForFreeTierBudget(
                    requestedPixelWidth: Int(baseSize.width), requestedPixelHeight: Int(baseSize.height)
                )))
            }
        }

        let renderScene = preparedScene(for: request, scene: scene)
        let filename = "\(MKFilenameSanitizer.sanitize(filenameBase)).\(fileExtension(for: request.format))"
        let url = destinationDirectory.appendingPathComponent(filename)

        // EU-4: only wrap `cooperation` when someone is actually listening
        // (`progressUpdates()` was called before this `export(...)`) —
        // otherwise `continuation.yield(_:)` would buffer into a stream
        // nobody ever consumes. Wrapping composes with (never replaces) an
        // explicit `MKExportCancellationToken`/custom `cooperation` the
        // caller already passed, so cancellation keeps working unchanged.
        let effectiveCooperation: any MKExportMemoryCooperating
        if let progressContinuation {
            let expectedTiles = expectedTileCount(canvasSize: renderScene.canvas.size, pixelSize: pixelSize)
            effectiveCooperation = MKExportProgressTrackingCooperation(
                base: cooperation, expectedTileCount: expectedTiles, continuation: progressContinuation
            )
        } else {
            effectiveCooperation = cooperation
        }

        do {
            let colorProvenance: String
            switch request.format {
            case .jpeg, .pngOpaque, .pngAlpha:
                let image = try await MKTiledRasterExporter.renderAssembled(
                    scene: renderScene, pixelSize: pixelSize, renderer: renderer,
                    maxTileBytes: maxTileBytes, cooperation: effectiveCooperation
                )
                try encode(image, format: request.format, to: url, dpi: request.dpi)
                colorProvenance = "sRGB"

            case .pdfRaster:
                let image = try await MKTiledRasterExporter.renderAssembled(
                    scene: renderScene, pixelSize: pixelSize, renderer: renderer,
                    maxTileBytes: maxTileBytes, cooperation: effectiveCooperation
                )
                try PDFRasterExporter.export(image: image, pixelSize: pixelSize, dpi: request.dpi, title: filenameBase, to: url)
                colorProvenance = "sRGB"

            case .pdfVectorRGB:
                let writerResult = try PDFVectorExporter.export(
                    scene: renderScene, pixelSize: pixelSize, dpi: request.dpi, title: filenameBase,
                    fontLicense: fontLicense, fonts: fonts, assets: assets, to: url
                )
                fallbacks.append(contentsOf: writerResult.fallbacks)
                colorProvenance = "sRGB"

            case .pdfVectorCMYK:
                let profile = cmykProfile()
                // Note: `PDFPrintCMYKExporter.export` has no `maxTileBytes:`
                // parameter of its own (that file is outside this agent's
                // Owns list for this wave) — its internal tiled render
                // always uses `MKTileRenderer.maxTileBytes` regardless of
                // this coordinator's own override, so `expectedTileCount`
                // above (computed against `self.maxTileBytes`) would be
                // inaccurate for a TEST coordinator built with a
                // non-default `maxTileBytes`. Production call sites never
                // override it, so this is a test-only edge case, not a
                // production correctness gap; `ExportCoordinatorProgressTests`
                // exercises progress via the raster path instead, where the
                // override does apply end-to-end.
                let writerResult = try await PDFPrintCMYKExporter.export(
                    scene: renderScene, pixelSize: pixelSize, dpi: request.dpi, title: filenameBase,
                    renderer: renderer, profile: profile, cooperation: effectiveCooperation, to: url
                )
                fallbacks.append(contentsOf: writerResult.fallbacks)
                let provenanceLabel = profile.provenance.mayClaimPDFX ? "bundledICC" : "appleGenericCMYK"
                colorProvenance = "CMYK: \(profile.name) [\(provenanceLabel)]"

            case .svg:
                let writerResult = SVGSerializer.export(
                    scene: renderScene, pixelSize: pixelSize, fonts: fonts, fontLicense: fontLicense,
                    fontData: fontData, assets: assets
                )
                try writerResult.svg.write(to: url, atomically: true, encoding: .utf8)
                fallbacks.append(contentsOf: writerResult.fallbacks)
                colorProvenance = "sRGB"
            }

            let result = MKExportResult(
                fileURL: url, pixelSize: pixelSize, format: request.format,
                fallbacksApplied: fallbacks, colorProvenance: colorProvenance,
                durationMS: Date().timeIntervalSince(start) * 1000
            )
            await history.record(result)
            return result
        } catch {
            await history.recordFailure(error, request: request)
            throw error
        }
    }

    /// D-118: alpha PNG renders a CLEAR background (background node
    /// hidden), opaque formats composite the canvas background normally
    /// (the renderer's existing, unmodified default behavior ، this
    /// function only ever produces a value-type COPY with `background
    /// .core.isHidden` flipped, never a `MKRender`/`MKModel` source
    /// change).
    private func preparedScene(for request: MKExportRequest, scene: MKScene) -> MKScene {
        guard request.background == .transparent else { return scene }
        var copy = scene
        copy.background.core.isHidden = true
        return copy
    }

    private func baseTargetSize(for target: MKExportTarget) -> CGSize? {
        switch target {
        case .preset(let id): return gate.presets.preset(id: id)?.pixelSize
        case .custom(let size): return size
        }
    }

    private func fileExtension(for format: MKExportFormat) -> String {
        switch format {
        case .jpeg: return "jpg"
        case .pngOpaque, .pngAlpha: return "png"
        case .pdfRaster, .pdfVectorRGB, .pdfVectorCMYK: return "pdf"
        case .svg: return "svg"
        }
    }

    private func encode(_ image: CGImage, format: MKExportFormat, to url: URL, dpi: Double) throws {
        switch format {
        case .jpeg(let quality):
            try MKRasterEncoders.writeJPEG(image, to: url, quality: quality, dpi: dpi)
        case .pngOpaque, .pngAlpha:
            try MKRasterEncoders.writePNG(image, to: url, dpi: dpi)
        case .pdfRaster, .svg, .pdfVectorRGB, .pdfVectorCMYK:
            // Unreachable from `export(_:)` (each has its own dispatch arm
            // above, never routed through `encode`) ، kept exhaustive so a
            // future format added to the enum fails loudly, never silently.
            throw MKExportError.formatNotYetImplemented(format: format)
        }
    }
}
