import Foundation
import MKModel

// P10-COMPLETION (Run-3, packet §5 task 14). SVG `@font-face` embedding
// needs raw FONT FILE BYTES (base64 `font/ttf` payload) ، a different need
// than `FontLicenseProviding` (which only answers rights/lockability
// booleans). `MKFontRegistry` (MKFonts, WS-09) already has this data
// (`record(for:)?.faces.first?.fileURL`) but is an `actor` requiring a
// live, running instance ، a runtime/composition-root concern, same
// "prefer wiring a real conformer at the composition root" posture
// `FontLicenseProviding.swift`'s own header already documents for THAT
// seam. This protocol is the SVG-specific sibling seam.
public protocol MKExportFontDataProviding: Sendable {
    /// Raw, whole (NOT subset ، see `SVGTextWriter.swift`'s header for the
    /// subsetting-deferral note) font-file bytes for `fontRef`, or `nil` if
    /// unavailable (falls back to `<text>` with only a `font-family` name,
    /// system-fallback risk documented via `FallbackReason
    /// .fontNotEmbedded` ، task 14's own named case, added to
    /// `FallbackReason` below).
    func fontFileData(for fontRef: MKFontRef) -> Data?
}

/// The v1 stub: no font data available (every font falls back to
/// `font-family`-only `<text>`, or an outline group when embedding rights
/// are ALSO absent ، see `MKEmbeddingRestrictionWalker`). A real conformer
/// (backed by `MKFontRegistry.record(for:)`, reading `MKFontFace.fileURL`)
/// is composition-root territory, same as `MKNoOpExportHistoryRecording`'s
/// own "no-op until the real substrate is wired at the app layer" pattern.
public struct MKNoFontDataProviding: MKExportFontDataProviding {
    public init() {}
    public func fontFileData(for fontRef: MKFontRef) -> Data? { nil }
}
