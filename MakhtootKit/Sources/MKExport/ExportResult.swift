import CoreGraphics
import Foundation

// WS-08 packet §5 task 4. `ExportResult` ، "url, pixelSize, format,
// fallbacksApplied: [FallbackNote], colorProvenance, duration".
public struct MKExportResult: Sendable, Hashable, Equatable {
    public var fileURL: URL
    public var pixelSize: CGSize
    public var format: MKExportFormat
    public var fallbacksApplied: [FallbackNote]
    /// Free-text provenance of the color pipeline used ، `"sRGB"` for
    /// every format this session implements; the CMYK writers
    /// (P10-completion) will report `ICCProfileStore.profileProvenance`
    /// here (packet task 2, deferred).
    public var colorProvenance: String
    public var durationMS: Double

    public init(
        fileURL: URL, pixelSize: CGSize, format: MKExportFormat,
        fallbacksApplied: [FallbackNote] = [], colorProvenance: String = "sRGB", durationMS: Double
    ) {
        self.fileURL = fileURL
        self.pixelSize = pixelSize
        self.format = format
        self.fallbacksApplied = fallbacksApplied
        self.colorProvenance = colorProvenance
        self.durationMS = durationMS
    }
}

/// Every failure mode `ExportCoordinator`/`ExportGate` can throw. Distinct
/// from `MKExportBlockReason` (`ExportGate.swift`), which is a POLICY
/// decision surfaced BEFORE rendering starts (replace-or-subscribe flow,
/// D-119) ، `MKExportError` covers everything else (unimplemented writer,
/// degenerate geometry, cancellation, I/O failure).
public enum MKExportError: Error, Sendable, Equatable {
    /// The request's format has no writer in this build (P10-EARLY:
    /// `pdfRaster`/`svg`/`pdfVectorRGB`/`pdfVectorCMYK` ، see
    /// `MKExportFormat.hasImplementedWriter`).
    case formatNotYetImplemented(format: MKExportFormat)
    /// `ExportGate` refused the request (D-119/D-229) ، carries the typed
    /// reason for WS-13's replace-or-subscribe flow.
    case blocked(MKExportBlockReason)
    /// Target pixel size resolved to zero/negative width or height.
    case degenerateTargetSize
    /// `MKSnapshotRenderer`/`MKTileRenderer` returned `nil` for a tile or
    /// the whole canvas (should only happen for degenerate geometry ،
    /// surfaced distinctly so callers can tell "gate said no" apart from
    /// "the renderer produced nothing").
    case renderingProducedNoImage
    /// ImageIO's `CGImageDestination` finalize step failed.
    case encodingFailed
    /// The caller's `MKExportMemoryCooperating.isCancelled()` (or
    /// structured-concurrency task cancellation) fired mid-export (task 8
    /// accept: "cancellation between strips leaves no temp files").
    case cancelled
}
