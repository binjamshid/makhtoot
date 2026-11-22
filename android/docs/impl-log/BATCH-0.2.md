# Batch 0 · Agent 0.2 — Golden-fixture exporter (Swift)

Status: complete. All acceptance criteria in `ANDROID_TASK_PACKETS/BATCH-0.md` (lines 110–206)
met. No blockers that stopped a required export; two documented findings below (fixture-schema
drift, CoreText font substitution) that a later batch should know about.

The counts and results below describe the original run. The four PDF references were later removed from tracked source because their embedded system font subsets and color profiles lack verified redistribution terms. Use the [export fixture checks](../../../docs/BUILD.md#export-fixture-checks) to regenerate the PDFs locally and compare their structure.

## What was produced

| Output | Path | Status |
|---|---|---|
| `MKGoldenExport` executable target | `MakhtootKit/Package.swift` (+15 lines, new target only) | builds clean |
| Exporter source | `MakhtootKit/Sources/MKGoldenExport/**` (15 files) | builds clean, `swift build` green |
| 11 engine-golden categories | `android/fixtures/{shaping,joining,ligature,marks,arrange,pathtext,scenecodec,render,export,canvas,assets}/` | 1,358 files total, byte-identical on a second run except 4 named PDFs |
| Determinism exclusion manifest | `android/fixtures/DETERMINISM_EXCLUSIONS.json` | machine-readable, for `gate.sh` |

`android/fixtures/resources/**` was never touched (Agent 0.4's, verified: not present in this
agent's `git status` diff).

## Per-category fixture counts (this run)

| Category | Files | Coverage |
|---|---|---|
| `shaping/` | 630 | 45 families × 14 corpus fixtures (F-1..F-12, with F-6/F-7 split a/b) |
| `joining/` | 45 | 45 families × 42 swept letters (U+0621–064A minus marks) × up to 4 forms each |
| `ligature/` | 315 | 45 families × (6 detect fixtures + 1 decompose/recompose fixture) |
| `marks/` | 270 | 45 families × 6 fixtures (F-3, F-4, F-6a/b, F-8 + a U+06D6/06ED synthetic probe) |
| `arrange/` | 29 | 4 canonical scenes (1 with a derivable `.liveText` node) + 2 families × 14-corpus sweep |
| `pathtext/` | 24 | 3 paths (straight/curved-open/closed-circle) × 2 families × 4 corpus strings |
| `scenecodec/` | 5 | 4 round-trip byte-goldens + 1 migration-behavior manifest (3 outcomes) |
| `render/` | 8 | 4 fixtures × (PNG + report) |
| `export/` | 20 | 4 fixtures × (png, png-alpha, jpg, svg, pdf) |
| `canvas/` | 4 | 4 fixtures, hit-test geometry (see "New categories" below) |
| `assets/` | 8 | 4 fixtures × (thumbnail PNG + manifest JSON) (see "New categories" below) |
| **Total** | **1,358** | plus `android/fixtures/DETERMINISM_EXCLUSIONS.json` (1 file) = **1,359 files in this work item** |

## Double-run determinism — literal result

Procedure: deleted all 11 category directories under `android/fixtures/`, ran
`swift run MKGoldenExport` from `MakhtootKit/` twice in a row, copied the tree after run 1 to a
scratch location, then `diff -rq` against the tree after run 2.

```
=== FULL DIFF (all categories) ===
Files .../export/fixture-100-nodes.pdf and android/fixtures/export/fixture-100-nodes.pdf differ
Files .../export/fixture-5000-nodes.pdf and android/fixtures/export/fixture-5000-nodes.pdf differ
Files .../export/fixture-arabic-basic.pdf and android/fixtures/export/fixture-arabic-basic.pdf differ
Files .../export/fixture-arranged-la.pdf and android/fixtures/export/fixture-arranged-la.pdf differ
```

**Every file in every category is byte-identical across the two runs except the 4
`export/*.pdf` files.** That includes `export/*.jpg`: JPEG was *expected* to be non-deterministic
(ImageIO's encoder carries no bit-stability contract) and is kept in the exclusion list on that
basis, but empirically, in this environment, on this run, the 4 JPEG files were also
byte-identical across both runs. PDF differs because `PDFVectorExporter`/`CGPDFContext` stamps a
`/CreationDate` (confirmed by grepping the two `.pdf` files for `/CreationDate` — present, and the
only substantive byte difference between the two versions of the same file).

Per-category breakdown, run twice independently and confirmed clean:
`shaping` ✅ · `joining` ✅ · `ligature` ✅ · `marks` ✅ · `arrange` ✅ · `pathtext` ✅ ·
`scenecodec` ✅ · `render` ✅ · `export` (png/png-alpha/jpg/svg ✅, pdf ❌ as documented) ·
`canvas` ✅ · `assets` ✅.

## Exclusion list exposed for `gate.sh`

`android/fixtures/DETERMINISM_EXCLUSIONS.json`, written by `DeterminismManifest.swift`, machine
list of `{category, pathGlob, reason, deterministic}` entries:

```json
{
  "nonDeterministicExclusions": [
    {"category": "export", "pathGlob": "export/*.jpg", "reason": "ImageIO JPEG encoder is not contractually bit-stable across process invocations.", "deterministic": false},
    {"category": "export", "pathGlob": "export/*.pdf", "reason": "CGPDFContext stamps /CreationDate (and often /ModDate) at creation time.", "deterministic": false}
  ]
}
```

`gate.sh` (Agent 1.1, later batch) should diff every file under `android/fixtures/` on a second
run **except** a path matching one of these globs. JPEG is kept in the list despite this run's own
empirical byte-identical result, because Apple documents no bit-stability contract for the
encoder — a future toolchain/OS update could change that at any time, and the manifest's job is
to state the *contract*, not just this run's observation.

## Determinism discipline against non-deterministic source types

`MKID<Tag>` (`MKClusterID`/`MKNodeID`) defaults to a freshly-random `UUID` at construction
(`MKFoundation/MKID.swift`), and `MKSourceTextBackup.createdAt` is a `Date`. Both are minted fresh
by the shipped engine on every shaping/derivation call, which would silently break byte-identical
determinism if serialized raw. This exporter never encodes either type directly:

- Every DTO (`*Export.swift`) hand-maps only deterministic-content fields.
- `MKClusterID`/`MKNodeID` values are replaced by their **array-position ordinal** within the
  same shaping/derivation call that produced them (`clusterOrdinalMap`/`nodeOrdinalMap`,
  `Support.swift`) — never the raw UUID.
- `MKSourceTextBackup.createdAt` is dropped; `contentHash`/`sourceString`/`style` (all
  deterministic) are kept.
- `MKRenderReport.duration` (wall-clock `TimeInterval`) is dropped from the `render/` category's
  report DTO for the same reason.

Verified empirically by the double-run diff above, not just reasoned about.

## New categories (`canvas/`, `assets/`) — scope note

Per this agent's own dispatch: "`canvas/` and `assets/` are new categories added by the spine
correction — the BATCH-0.md ownership appendix predates that correction and omits them; per the
spine-wins rule you own and must produce them too." No Batch 0 packet section names a concrete
reads/port-map row for either category (the packet text predates the correction), so their exact
content is this agent's documented judgment call:

- **`canvas/`**: `MKRender.HitTester.worldGeometry(of:in:)` (local bounds + world transform) and
  `.containsPrecise(nodeID:worldPoint:in:)` at 5 deterministic sample points (center + 4 corners)
  per node, plus `.allHits(at:in:)` at canvas center, over the 4 canonical fixture scenes (capped
  at 25 nodes for the two 100/5000-node fixtures). Chosen because Batch 5.1's own port map
  (`ANDROID_TASK_PACKETS/BATCH-5.md`, `Geometry/MKCanvasGeometrySource.swift` row) names exactly
  these two `HitTester` entry points as what `MkCanvasGeometrySource` adapts — this is the
  concrete, load-bearing subset that agent's own port map already implies it needs, not an
  arbitrary choice.
- **`assets/`**: a deterministic 512px-long-edge thumbnail PNG (`MKSnapshotRenderer
  .renderThumbnail`, the same call `MKPersistence`'s own thumbnail path uses) plus a per-node
  asset-reference manifest (node id/kind, `MKAssetRef.digest`/`.ext` for `.image` nodes), per
  fixture scene. Chosen to match `ANDROID_TASK_PACKETS/BATCH-5.md`'s own two citations: "Manifest
  goldens" (Agent 5.5a) and "Provenance/thumbnail goldens" (Agent 5.5b) — kept deliberately
  distinct from `android/fixtures/resources/**` (Agent 0.4's verbatim copies of the raw
  `assets-manifest.json`/`provenance-records.json` *source* files): this category instead
  exercises real rendering/inventory code, giving Batch 5.5a/5.5b something to diff their own
  logic against rather than a copy of the input.

Both are intentionally narrower than the (a)–(i) categories this agent's packet explicitly
specifies — they cover the concrete cross-references other packets make, not an exhaustive sweep.
If Batch 5.1/5.2/5.5 need more than this once they start, that is a new `CONTRACT_CHANGES.md`
entry against this category's scope, not a silent gap.

## Findings worth a later batch's attention

**1. Pre-existing `Tests/Fixtures/*.makhtoot` schema drift (worked around, not fixed — this
agent's fence forbids editing `Tests/**`).** All 4 checked-in fixture scenes' `style` JSON objects
predate `MKTextStyle` gaining `isBold`/`isItalic`/`isUnderline`/`isStrikethrough`
(`Sources/MKModel/MKTextStyle.swift`) — those 4 keys are simply absent (verified directly via
`python3 -c "json.load(...)"` on `fixture-arabic-basic.makhtoot/scene.json`). `MKTextStyle`'s
`Codable` is the plain synthesized conformance (no `decodeIfPresent`-based defaults, unlike
`MKProvenance.cursiveAttached`'s deliberately additive-safe custom decoder), so
`MKSceneCodec.decode` throws `keyNotFound(isBold)` on every one of these 4 files as committed.
`Tests/MKModelTests/FixtureGenerator.swift`'s own doc comment says the generator is "idempotent —
skips a fixture that already exists on disk", and all 4 already exist in git, so the drift is
permanent until someone deletes and regenerates them. Worked around in
`MKGoldenExport/FixtureSceneLoader.swift` via a narrowly-scoped JSON preprocessing pass
(backfills exactly those 4 boolean fields to `false`, `MKTextStyle.init`'s own documented default,
wherever a JSON object looks like an `MKTextStyle` — has `pointSize`+`font` — and lacks them)
before handing bytes to `MKSceneCodec.decode`. **Flagging for whoever next owns `Tests/Fixtures/`
regeneration**: delete and regenerate the 4 `.makhtoot` directories via
`FixtureGenerator.ensureAllFixtures()` to close this drift at the source; until then, any other
Swift-side consumer of these exact checked-in files (not just this exporter) will hit the same
`keyNotFound` unless it applies an equivalent workaround.

**2. CoreText automatic font-cascade substitution, observed on real fonts.** Registering a
family (e.g. "Alef") and shaping/deriving `لا` (F-1) through it can capture a *different* resolved
font on the shaped run (`MKShapedRun.font`, e.g. "GeezaPro") than the one requested — this is
expected, already-designed-around Core Text behavior (`MKShapingEngine.resolvedFont(for:)`'s own
doc comment: every downstream consumer reads the font back off the captured run precisely because
Core Text, not the caller, has final say on what actually drew the glyphs), not an exporter defect
or a shipped-engine bug. Recorded here because a Kotlin/HarfBuzz port has no equivalent automatic
substitution mechanism and will need to either replicate the specific substitution or register it
as a Class C shaping delta (`ANDROID_SPINE.md` §12) per affected (family, corpus) pair once Batch
3 runs its parity sweep against these `shaping/`/`ligature/` goldens.

**3. Dead conditional in `LigatureDecomposer.swift` (observed, not fixed — outside this agent's
fence).** `Sources/MKArrange/LigatureDecomposer.swift:204`:
`font: group.provenance.clusterID == group.provenance.clusterID ? composed.glyph.font : composed.glyph.font`
— both ternary branches are identical, so the condition is always `true` and has no effect
(harmless dead code, always resolves to `composed.glyph.font` either way). Not a correctness bug;
noted for whoever next touches that file.

## Outline geometry scoping choice

`joining/` deliberately omits `MKResolvedForm.outline` (kept to glyphID/advance/form/coercion
only) — full per-glyph outline geometry is a per-font rendering detail already covered by the
`render/`/`pathtext/` categories and the G4 render-tolerance gate (`ANDROID_SPINE.md` §12); D-325's
Class A/B/C shaping-delta classification (`§12`) cares about glyph id/form/mark presence/ligature
composition, never sub-glyph outline geometry. Logged per spine §9's "a tolerance/scoping choice
an agent had to pick is always logged" rule.

## Swift-side limitations that stopped nothing (informational)

None found that blocked a required export. The two findings above were worked around
(schema drift) or are expected behavior to document forward (font substitution), not blockers.

## Verification commands run

```
cd MakhtootKit && swift build --product MKGoldenExport   # clean
cd MakhtootKit && swift build                              # whole package, clean (16 library targets + MKGoldenExport)
cd MakhtootKit && swift run MKGoldenExport                 # populates all 11 category dirs, ~10s
# (run twice, diff -rq the two trees — see "Double-run determinism" above)
```

Note on the `swift test --no-parallel` wedge (`EXECUTION_PLAN_2026-07-28.md` ground rule 3): that
hang is specific to XCTest's parallel worker-process scheduling colliding with Core Text's
process-wide font-registration state. `MKGoldenExport` is a plain `swift run` executable, not
`swift test` — it never spawns parallel XCTest workers, so the wedge does not apply to running
this tool (documented in `main.swift`'s header too, for the next person who wonders). Separately:
`swift build` has no `--no-parallel` flag at all (that flag exists only on `swift test`) — the
packet's own acceptance line ("`swift build --no-parallel` still succeeds") is satisfied here via
plain `swift build`, which is the closest command that actually exists.

## Files in scope

- `MakhtootKit/Package.swift` — added the `MKGoldenExport` executable target only (+15 lines);
  no other target declaration touched.
- `MakhtootKit/Sources/MKGoldenExport/` (15 files, new):
  `main.swift`, `Support.swift`, `DeterminismManifest.swift`, `FixtureSceneLoader.swift`,
  `ShapingExport.swift`, `JoiningExport.swift`, `LigatureExport.swift`, `MarksExport.swift`,
  `ArrangeExport.swift`, `PathTextExport.swift`, `SceneCodecExport.swift`, `RenderExport.swift`,
  `ExportGoldens.swift`, `CanvasExport.swift`, `AssetsExport.swift`.
- `android/fixtures/{shaping,joining,ligature,marks,arrange,pathtext,scenecodec,render,export,
  canvas,assets}/**` and `android/fixtures/DETERMINISM_EXCLUSIONS.json` (new).
- This file, `android/docs/impl-log/BATCH-0.2.md`.

No file under `MakhtootKit/Sources/` outside the new `MKGoldenExport` target was modified. No file
under `MakhtootKit/Tests/**` was modified (read-only, per this agent's fence — the one place a
Tests-side fix would help, `Tests/Fixtures/*.makhtoot` regeneration, is called out above instead
of edited). `android/fixtures/resources/**` was never touched (Agent 0.4's).
