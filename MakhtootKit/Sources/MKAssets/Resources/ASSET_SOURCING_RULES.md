# MKAssets — Asset Sourcing Rules

WS-14 packet (`AGENT_TASK_PACKETS/WS-14-assets-ornaments.md`) §5 task 2, the
"legal core" of this module. This document governs how ANY vector asset
may enter `MKAssets`'s bundled library — v1's 57 assets and every future
addition. It mirrors WS-09's font-license-verification discipline
(FOUNDATION §12: "no invented legal/policy facts") for non-font assets.

## 1. Default posture: original authorship

Every v1 asset is **original geometry authored for Makhtoot** — procedurally
constructed Islamic geometric patterns (girih/star-polygon constructions
from mathematical definitions) or hand-authored control points, built via
`MKAssetPathBuilder`'s primitives (regular/star polygons, circular arcs,
rounded rects, variable-width "ribbon" strokes) and the per-category
generators in `Sources/MKAssets/Generators/`.

**Regular/star-polygon constructions themselves are not copyrightable** —
they are mathematical definitions (an "{n/k} star polygon," a regular
hexagon, a circle) that predate any specific software or artist. What IS
original, and what this library actually claims authorship over, is **the
specific authored path data**: the exact control points, proportions,
compositions, and combinations this codebase generates (e.g. an 8-point
star plus a specific bounding ring at a specific radius ratio, wound in a
specific direction for a specific hole effect). `MKAssetProvenanceLibrary`
records this distinction per asset — see each record's `notes` field.

No market-study citation is needed for any v1 asset (unlike fonts) because
**nothing is redistributed** — every asset is generated from first
principles by this codebase's own generator code, never traced, copied,
downloaded, or extracted from any third party's work.

## 2. Derivation from external sources — permitted ONLY under strict conditions

A future asset MAY be `derivedVerified` (see `MKAssetProvenance.origin`)
**only** when:

1. The source has a **verified redistribution license** — public-domain
   heritage pattern documentation, CC0-licensed vector art with a captured
   license file, or similar. "Looks free on the internet" is never
   sufficient (mirrors WS-09's "never trust aggregator 'free download'
   pages as license evidence" standard, market study §5).
2. **OFL font glyphs are NOT permitted as decorative assets** without first
   verifying OFL's scope explicitly extends to that use — v1 policy is to
   **avoid this entirely** (see §4 below and task 7's calligraphic-element
   rule: no calligraphic asset is ever derived from a font file).
3. A **license file is captured** into this module's resources
   (`licenseFilePath` on the provenance record must point at a real,
   checked-in file — a URL alone is never sufficient).
4. A **transformation note** records what was changed from the source, so
   the derivation is traceable, not a blind copy.

**No `derivedVerified` asset exists in v1.** Every shipped asset is
`originalWork`. This section exists so the rule is written down BEFORE it
is ever needed, not invented under pressure later.

## 3. Forbidden sources (absolute, no exceptions)

The following are never acceptable inputs to any bundled asset, at any
version:

- Clip-art sites and "free vector" aggregators (Freepik, Vecteezy,
  Flaticon, and equivalents) — their own license terms are frequently
  attribution-required, editorial-only, or simply unverifiable at the
  individual-asset level.
- Stock-photo/vector marketplaces (Shutterstock, iStock, Getty, and
  equivalents) without a purchased, verified commercial redistribution
  license (none purchased in v1 — moot).
- Any other app's asset dump (competitor ornament/shape libraries,
  extracted or copied — market study notes Diwan and Ana Khattat both ship
  ornament/shape libraries; this codebase's constructions are independently
  authored, never traced from theirs).
- AI-image-tracing of unknown-provenance images, or any AI-generated raster
  converted to vector — provenance is unverifiable and licensing status of
  the training data / output is unresolved.
- Font glyph outlines used as decorative shapes (see §4).
- KFGQPC/Uthmani-family assets or anything visually presented as Qur'anic
  content (BRIEF Q67–68 — see §5).

`AssetProvenanceAudit` (T12, `Tests/MKAssetsTests/
AssetProvenanceAuditTests.swift`) mechanically greps every provenance
record's `notes` field for a marker list matching this section
(`MKAssetForbiddenSourceMarkers.markers`) and fails the build if any
shipped asset's notes mention one — a structural, automated backstop to
this written rule, not a replacement for it.

## 4. Font-glyph-derived decorations: avoided entirely in v1

Task 7's calligraphic divider/flourish set is drawn as **variable-width
outlines baked as filled paths** (`MKAssetPathBuilder.ribbon`), evoking a
calligraphic brush stroke through pure geometry — never by extracting a
glyph outline from any font file (bundled or otherwise). This sidesteps
OFL Reserved Font Name / scope questions entirely, matching this run's
policy of never inventing a legal conclusion about font-license scope.
If a future version wants to build a decoration FROM a font glyph, it must
first run WS-09's font-license-verification protocol against that specific
use case — not assumed permitted by analogy to normal text rendering.

## 5. No Qur'anic or religious textual content

BRIEF Q67–68: no preloaded Qur'anic content of any kind, extended here to
decorative assets. Every ornament/frame/calligraphic element in this
library is **aniconic geometry or floral/architectural abstraction** — no
verses, no textual content of any kind, no مصحف (Qur'an) frame marketed as
such. The "simple mihrab-arch outline" ornament is an **architectural
form** (a pointed-arch silhouette), not religious text, and is acceptable
under this rule exactly as the packet's §6 compliance notes describe.

## 6. Every shipped asset requires a provenance record

`AssetProvenanceAudit` fails the build if:

- Any manifest asset (`MKAssetLibrary.standard.all`) lacks a matching
  `MKAssetProvenance` record (missing record = excluded by audit, per this
  rule's own title).
- Any `derivedVerified` record's `licenseFilePath` does not point at a real
  file under this module's resources.
- Any record's `notes` mentions a forbidden-source marker (§3).
- Any asset's `category` falls outside the five BRIEF-locked
  `MKAssetCategory` cases.
- Any asset is missing its `isPremium` flag (structurally impossible in
  Swift — the field is non-optional — so this check is a schema-level
  guarantee, not a runtime gap).

## 7. Gating: pattern backgrounds are premium (D-215)

BRIEF Q34 locks the free tier to "solid colors only" for canvas
backgrounds. Neither BRIEF nor FOUNDATION.md stated pattern-background
gating explicitly until this workstream required a ruling — recorded as
**D-215** in `DECISIONS_LOG.md` (Run-1 self-review amendment): pattern
backgrounds (and all non-solid background fills) are premium content; free
tier backgrounds remain solid colors only, exactly per Q34. Every
`.patternBackgrounds`-category asset in this library has `isPremium ==
true`, verified by `AssetProvenanceAudit` (§6's audit list) and
`MKPatternBackgroundTests`.
