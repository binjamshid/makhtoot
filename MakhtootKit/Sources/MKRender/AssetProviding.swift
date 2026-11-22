import CoreGraphics
import MKModel

// WS-07 packet §5 task 2 (`ImageDrawer`: "asset bitmap via WS-02 asset
// store"). ARCHITECTURE §3.5 sketches a `MKSceneSnapshot` wrapper
// (`scene` + `fontHandles` + `assetURLs` + `renderIntent` + `entitlement`)
// as "the ONLY input MKRender accepts" ، WS-02 did not ship that wrapper
// type (verified: no `Snapshot` type exists anywhere in `MKModel`/
// `MKPersistence` today), and building the full orchestration wrapper
// (resolving font handles + hard-linking asset URLs + freezing entitlement
// state) is cross-cutting persistence/document-session work outside this
// packet's fence (`MKRender sources/tests` only).
//
// `MKScene` itself is ALREADY an immutable `Sendable` value type
// (`Hashable, Sendable, Codable`), which is the concrete requirement D-102/
// INV-2 state ("renderer works on immutable snapshots (value-type scene
// graph) so export/preview never race the editor") ، so `MKSceneRenderer`
// accepts `MKScene` directly. Asset resolution is decoupled the same way
// font resolution already is (`MKFontProviding`, WS-01): this protocol,
// paralleling that one, lets any caller (a future `MKPersistence`-aware
// document session, or a test fixture) hand in resolved images without
// MKRender depending on `MKPersistence`/`MKAssetStore` (not a
// DEPENDENCY_GRAPH.md edge). Logged in `docs/impl-log/WS-07.md` as a
// deliberate simplification of ARCHITECTURE §3.5's illustrative sketch,
// not an oversight.
public protocol MKAssetProviding: Sendable {
    /// Resolves a raster asset (`MKImageKind.raster`) to a decoded
    /// `CGImage`. `nil` = missing/undecoded ، the renderer records a
    /// `.missingAsset` substitution and skips drawing that node's image,
    /// never crashes or silently draws nothing without reporting it.
    func resolveRasterImage(_ ref: MKAssetRef) -> CGImage?

    /// Resolves a vector PDF asset (`MKImageKind.vectorPDF`) to its first
    /// page.
    func resolvePDFPage(_ ref: MKAssetRef) -> CGPDFPage?

    // `MKImageKind.vectorSVG` resolution needs `MKAssetVectorProgram`
    // (ARCHITECTURE §11.1/§16.6 ، the pre-parsed SVG element model shared
    // by the renderer and the SVG *writer*), owned by `MKAssets` (WS-14,
    // not yet built, and `MKRender` does not depend on it per
    // DEPENDENCY_GRAPH.md). SVG image nodes render as a `.missingAsset`
    // substitution in this packet; wiring resolveSVGProgram(_:) through
    // this protocol is the natural extension point once `MKAssets` ships.
}

/// Resolves nothing ، every asset lookup reports a `.missingAsset`
/// substitution. The default for `MKSceneRenderer`/`MKSnapshotRenderer`
/// until a real provider (document-session-backed) is injected; safe for
/// fixtures/tests that don't exercise `MKImageNode`.
public struct MKEmptyAssetProvider: MKAssetProviding {
    public init() {}
    public func resolveRasterImage(_ ref: MKAssetRef) -> CGImage? { nil }
    public func resolvePDFPage(_ ref: MKAssetRef) -> CGPDFPage? { nil }
}
