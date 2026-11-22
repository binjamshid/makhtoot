import MKFonts
import MKModel

// WS-08 packet §3 ("Font license seam stub: AllOFLLicenseStub") / §8
// deliverables ("FontLicenseProviding.swift (+ AllOFLLicenseStub)"). Owned
// by MKExport (not MKFonts) because the CONSUMER of embedding-rights
// decisions is the PDF/SVG writer's per-license text-vs-outline switch
// (D-118/§16.5/§16.6), and the packet's own mission statement frames the
// v1 stub explicitly: "a per-license switch fed by WS-09 metadata (stub:
// all OFL)".
//
// **Drift note** (same class of drift D-227 already reconciled for the
// canonical `MKLicenseRecord`/SVG schema): this packet was written before
// WS-09 shipped its real `MKFontRegistry` (`Sources/MKFonts/
// MKFontRegistry.swift`), which already exposes `licenseRecord(for:) ->
// MKLicenseRecord?` with the canonical `embeddingRights: MKEmbeddingRights`
// bitset (D-227(1)) ، a real actor-backed catalog, not a stub. This
// protocol therefore does TWO jobs with two different maturity levels:
//
// 1. **Content-gating query** (`isLockableFont`) ، needed NOW by
//    `ExportGate` (task 5, P10-EARLY) to compute `premiumContentPresent`.
//    `MKScene`/`MKFontRef` carry no live registry handle (the model layer
//    is intentionally registry-free), so this is answered from `MKFontRef`
//    alone: `userImported` is a direct, persisted signal; the `fontID`
//    naming convention (§17.1: `"bundled.<x>"` / `"premium.<catalogID>"` /
//    `"user.<digest>"` / `"system.<x>"`) lets a caller-free heuristic
//    recognize a premium-catalog font WITHOUT an async registry round trip
//    inside a synchronous scene walk.
// 2. **Embedding-rights query** (`embeddingRights`) ، needed by the PDF/SVG
//    writers (packet tasks 11/14, P10-completion, deferred this session).
//    Reuses `MKFonts.MKEmbeddingRights` directly (MKExport already depends
//    on MKFonts) rather than inventing a parallel bitset ، D-227(1)'s
//    "WS-08's embedPDF/embedSVG consumers become accessors over
//    embeddingRights" instruction, honored even though the writers
//    themselves don't exist yet.
//
// **Coordination note for whoever builds the PDF/SVG writers
// (P10-completion)**: prefer wiring a REAL conformer backed by
// `MKFontRegistry.licenseRecord(for:)`/`.record(for:)` (async, actor-
// isolated) at the composition root instead of extending
// `AllOFLLicenseStub` ، the stub's job is exactly what its name says
// (every font behaves as freely-embeddable OFL, matching v1's actual
// catalog composition per D-227(5): "v1's premium-catalog fonts are OFL"),
// not a long-term substitute for the real registry.
public protocol FontLicenseProviding: Sendable {
    /// Whether `fontRef` counts toward `premiumContentPresent` (D-119/
    /// D-229): a font that locks on entitlement lapse (premium-catalog
    /// download OR user import) or whose rights are otherwise unknowable.
    /// Bundled/system fonts never lock (D-120: the ten bundled fonts ship
    /// free, unconditionally).
    func isLockableFont(_ fontRef: MKFontRef) -> Bool

    /// Per-format embedding rights (D-227(1)) ، consumed by the deferred
    /// PDF/SVG writers' text-vs-outline switch. `AllOFLLicenseStub`
    /// answers `[.pdf, .svg, .commercialUse]` for every font (v1's actual
    /// OFL-only catalog composition, D-227(5)), EXCEPT a user-imported
    /// font, which always answers `[]` (T15's documented rule: imported
    /// fonts' rights are unknowable, no embedding).
    func embeddingRights(_ fontRef: MKFontRef) -> MKEmbeddingRights
}

/// The v1 stub: every font behaves as a freely-embeddable OFL font except
/// user-imported ones (rights unknowable, T15). Named `AllOFLLicenseStub`
/// per the packet's own naming ، matches v1's real catalog composition
/// (D-227(5)), so this "stub" is not a fiction the way a fake entitlement
/// resolver is; it is the CORRECT v1 answer, just not derived from the real
/// per-font `MKLicenseRecord` lookup (which requires the async
/// `MKFontRegistry` ، see the type's doc comment above).
public struct AllOFLLicenseStub: FontLicenseProviding, Sendable {
    public init() {}

    public func isLockableFont(_ fontRef: MKFontRef) -> Bool {
        if fontRef.userImported { return true }
        return fontRef.fontID.hasPrefix("premium.")
    }

    public func embeddingRights(_ fontRef: MKFontRef) -> MKEmbeddingRights {
        fontRef.userImported ? [] : [.pdf, .svg, .commercialUse]
    }
}
