# MKFonts

Owner: WS-09 (`AGENT_TASK_PACKETS/WS-09-fonts-licensing.md`). Cross-referenced
against ARCHITECTURE.md §17 (Fonts Subsystem) — the canonical `MKLicenseRecord`
shape (D-227) lives in `MKLicenseRecord.swift` and must not diverge from that
section without a corresponding DECISIONS_LOG amendment.

## Architecture

```
MKFontRegistry (actor)              — single source of truth: faces, license
  ├─ BundledFontIndex                 records, lock state, catalog snapshot
  ├─ MKFontRegistrar                  stream. CTFontManagerRegisterFontURLs
  ├─ MKFontDownloader                 (.process), per D-122/D-219.
  ├─ MKFontImporter
  └─ MKFontLockController (T17)
MKFontCatalog (actor)                — browse/search/preview façade over the
  ├─ MKFontSearchIndex                 registry snapshot (T6-T9).
  └─ MKCoverageAnalyzer
MKFontCatalogStore (@ModelActor)     — SwiftData favorites/tags/download-state
                                        persistence (its own context over
                                        MKPersistence's shared ModelContainer
                                        — see the type's own doc comment for
                                        why it doesn't touch MetadataStore.swift).
MKLicensingDataSource (actor)        — Settings→Support→Licensing data feed (T16).
MKCatalogManifestFetchService        — DF-7 foreground-only manifest fetch,
  (actor)                              24h TTL, disk cache, empty state (T22).
MKRegistryFontProvider               — MKFontProviding conformer that replaces
  (struct)                             SystemFontStubProvider app-wide once
                                        injected at the composition root.
```

## Protocol conformance (stub replacement)

`MKRegistryFontProvider` conforms to `MKFontProviding`
(`MKFoundation/Stubs/MKFontProviding.swift`) with the exact same
round-trip-verified resolution contract `SystemFontStubProvider` established
(WS-07's fix, `docs/impl-log/WS-07.md`) — any registered PostScript name
resolves to itself; anything else falls back to the system stub. Every WS-03/
WS-07 call site that default-injects `SystemFontStubProvider()` needs zero
changes; only the app composition root's default `fonts:` argument changes.

## Bundled fonts: acquisition + verification

See `Resources/VERIFICATION_PROTOCOL.md` for the 8-step process and
`Resources/EXCLUDED_FONTS.md` for every D-120 candidate not unconditionally
shipped, including the run's primary open item: D-222's arrange-fidelity
gate (steps 7, T-AR-31/32/33/36-38) could not be executed this run because
`MKArrange` (WS-04) does not exist yet in this repo snapshot — every shipped
font's verification record carries `blocked_pending_ws04`, not a pass, for
that specific gate. Re-run required once Arrange Mode ships.

Five candidates (Amiri, Amiri Quran, Aref Ruqaa, Rakkas, Qahiri) additionally
carry a real, tool-verified GPOS LookupType-3 (cursive attachment) finding
(D-222 step 8) with no corresponding D-105 cursive-pair support in `MKModel`
yet. They are registered (so the packet's own app-boot/Amiri-shaping smoke
test remains possible) but excluded from `MKFontCatalog.browse()`'s default
list — see `isProvisionalShip` and `Resources/EXCLUDED_FONTS.md`.

## Premium catalog (D-121) / FD-04

`MKPremiumDelivery.current` is `.bundledFallback` — FD-04 (premium font
hosting location) is founder-pending. `catalog-manifest-v1.json`'s schema and
`MKFontDownloader`/`MKCatalogManifestFetchService` are fully implemented
against `.hosted(manifestURL:)` and exercised in tests via a local
`URLProtocol` stub server; switching to `.hosted` in a real build is a
one-constant change once FD-04 resolves (see WS-15's build-settings doc).

## FD-07 (commercial foundry licensing) — inert v1 hook

`MKLicenseType.commercial`/`.prohibited` cases exist for schema
forward-compatibility only; `MKCatalogManifestDecoder` and this module's own
seed data never produce a `commercial` license type in v1 — every shipped
manifest/catalog entry is `.ofl11`.

## Testing

`MKFontsTests` covers: sfnt accept/reject fixtures (`MKFontValidatorTests`),
coverage over Arabic ranges (`CoverageAnalysisTests`), manifest decode
(`CatalogManifestTests`), plus registry/catalog/search/license-audit/lock/
import/download/manifest-fetch-service coverage per T1-T22. `FontLicenseAuditTests`
is the T20 build gate (implemented as a test case rather than a standalone
SPM target — see that file's header comment for the rationale).
