# MKAssets

WS-14 packet (`AGENT_TASK_PACKETS/WS-14-assets-ornaments.md`) §5 task 15.
Bundled vector shapes, Arabic ornaments, frames, calligraphic elements, and
pattern backgrounds — plus the asset browser model, instantiator, pattern
fill, and thumbnail renderer WS-13's editor consumes. Depends only on
`MKFoundation`/`MKModel` (FOUNDATION §2), no third-party dependencies
(D-101).

## Model

- `MKAssetDescriptor` — one bundled asset: stable `assetID`, Arabic
  `nameAr`, `MKAssetCategory` (the five BRIEF-locked classes:
  `basicShapes`/`ornaments`/`frames`/`calligraphicElements`/
  `patternBackgrounds`), Arabic `tags`, `isPremium`, `pathData`
  (`MKAssetGeometry`), `defaultAspect`, `provenanceRef`, `libraryVersion`,
  and (`.frames` only) `nineSliceInsets`.
- `MKAssetGeometry` — subpaths + fill rule + styleable regions, the
  authoring-time vector representation. Lowers to `MKModel.MKPathData` via
  `toPathData()` for scene placement, or to a raw `CGPath` via `cgPath()`
  for the internal thumbnail rasterizer.
- `MKAssetPathBuilder` — shared construction primitives (regular/star
  polygons, circular arcs, rounded rects, variable-width "ribbon" strokes)
  every generator builds on.
- `MKPatternFill` — pattern-background model: one `MKPatternTile`
  (geometry + tile size), a repeat mode (`grid`/`halfDrop`), and two
  styleable colors.
- `MKAssetProvenance` / `MKAssetProvenanceStore` — see
  `Resources/ASSET_SOURCING_RULES.md` (the sourcing/licensing rules) and
  `MKAssetProvenanceLibrary` (the generated-from-descriptors record set).

## Library

`MKAssetLibrary.standard` aggregates all five generators
(`MKBasicShapeGenerator`, `MKOrnamentGenerator`, `MKFrameGenerator`,
`MKCalligraphicGenerator`, `MKPatternTileGenerator`) into the v1 bundled
set (57 assets) — the RUNTIME source of truth (no JSON parsing on the hot
path). `Resources/assets-manifest.json` / `Resources/provenance-records.json`
are periodically-regenerated, checked-in Codable snapshots of the same data
(the T1-mandated on-disk manifest artifact + T2's provenance store) —
regenerate via `MKAssetManifestGenerator.regenerate()`
(`swift test --filter regenerateManifestResources`) after changing any
generator, then commit the updated `Resources/*.json` files.

## Instantiation (self-contained serialization)

`MKAssetInstantiator.place(asset:)` returns a plain `.shape(MKShapeNode
(geometry: .path(MKPathData)))` node with the asset's FULL path data
inlined — no reference back to `MKAssets` anywhere in the node. A
`.makhtoot` document renders correctly on any device/app-version with zero
knowledge of `MKAssets` ever having existed (verified by
`MKAssetInstantiationTests.decodedSceneContainsNoReferenceToTheSourceAssetID`).
`MKPatternInstantiator.placeBackground(_:fill:canvasSize:)` realizes a
pattern background as a `.group` of tiled `.shape` nodes (see that file's
header for the documented `MKBackgroundContent` schema-gap workaround).

**MKModel coordination note** (see `MKAssetInstantiator.swift`'s file
header for the full writeup): the packet's task 3 also asks for an
"assetID provenance attribute for future dedup/re-link" living on the
placed node. The shipped `MKModel` schema has no generic metadata slot for
this, and adding one is outside this run's fence (`MKAssets` sources only).
Proposed, ready-to-apply addition for whoever next has `MKModel` in scope:

```swift
// MKNode.swift, MKNodeCore:
public var sourceAssetID: String?   // Codable, defaults nil, additive
```

Until then, `MKPlacementRecord` (returned alongside every placed node) and
`MKPremiumContentLedger` (T13) carry this bookkeeping at the call site.

## Browser model

`MKAssetBrowserModel` (`@MainActor @Observable`) — sections by category,
Arabic-normalized search (`MKAssetSearchNormalizer`, tashkeel/hamza/
ta-marbuta-insensitive), favorites + recents (`MKAssetMetadataStoring`
protocol seam, in-memory stub until `MKPersistence` integrates), premium
lock badges (`MKEntitlementProviding`), and the single placement entry
point `select(_:at:canvasSize:)`.

**Paywall-routing note**: `select(_:)` signals a blocked premium placement
via `MKFoundation.MKPremiumCapability.premiumAssets` (already
cross-module), not an app-target `PaywallContext` type (`MKAssets` cannot
import the app target). WS-13's integration is a one-line addition to
`Makhtoot/AppShell/Navigation/MKRoute.swift`'s `PremiumFeature` enum
(`case premiumAsset`) plus a one-line paywall-presentation call site,
mirroring the existing `.customCanvas` call site exactly.

## Thumbnails & visual QA

`MKAssetThumbnailRenderer` — a small internal CG rasterizer (no `MKRender`
dependency, per the packet's own framing) + actor-owned LRU cache. Fill
rule is plain nonzero winding (CG's default, matching
`MKRender.StylePainting.paint` exactly) — every asset with a "hole"
(crescent, rosette rings, frame borders) is authored with opposite-wound
subpaths so nonzero fill alone produces the correct subtraction (see
`MKAssetGeometry.swift`'s file header). `MKAssetContactSheetGenerator`
produces the T11 visual-QA contact sheets (256pt/1024pt), written as PNG
evidence under `docs/impl-log/WS-14-contact-sheets/`.

## Gating (D-215/D-217/D-119)

- `basicShapes`: always free.
- `ornaments`/`frames`/`calligraphicElements`: mixed free/premium per
  category (see each generator's file header for the exact split and
  rationale).
- `patternBackgrounds`: ALWAYS premium (D-215 — BRIEF Q34's "free tier
  backgrounds = solid colors only" extends to pattern fills).
- `MKPremiumContentLedger` computes the D-119 "premium content present"
  project marker from placement records (T13) — the real `MKModel` manifest
  field this ultimately feeds is a separate coordination note (see
  `MKPremiumContentLedger.swift`'s file header).

## Explicit NON-goals

- **No templates** (BRIEF Q61–62, locked). Nothing in this module composes
  multiple elements plus text into a pre-arranged design; the asset browser
  places exactly one object per tap. The only template-related surface is
  respecting WS-13's own extension seam (T15 there) — `MKAssets` adds none
  of its own beyond the `libraryVersion` field below.
- **No downloadable asset packs in v1** (§2 OUT, v2 seam). The seam is
  limited to `MKAssetDescriptor.libraryVersion` (currently `1` for every
  asset — the one bundled pack) + stable `assetID`s — no dormant download
  code, no catalog-fetch machinery, nothing partially built.
- **No Qur'anic/religious textual content** (BRIEF Q67–68). Every asset is
  aniconic geometry or floral/architectural abstraction; the "mihrab-arch"
  ornament/frame are architectural silhouettes, never text-bearing.
- **User-imported assets** are out of this module's scope (WS-02/06/08
  import pipeline territory) — the browser MAY list them via
  `MKPersistence`'s asset store as a separate section (contract only, not
  built here).

## Testing

`Tests/MKAssetsTests` — one suite per packet task (T1–T14) plus the
manifest-resource sync check. `AssetProvenanceAudit` (T12) is implemented
as a `@Suite`/`enum` pair inside this test target (not a separate SPM test
target — this codebase's grain is one test target per module) with its own
tamper tests proving the audit fails correctly on bad input, not just
passes on good input.
