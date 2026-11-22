# WS-02 — Scene Model & Persistence

Run-1 agent task packet for Makhtoot (مخطوط). Governed by FOUNDATION.md. Owns `MKModel`
and `MKPersistence`.

## 1. Mission

Implement the immutable value-type scene graph (`MKScene`, `MKNode` and the arranged
node family `GlyphNode` / `MarkNode` / `LigatureGroup` with full provenance), plus the
entire persistence stack decided in D-112: `.makhtoot` file-package documents
(`manifest.json` + `scene.json` + `assets/` + `backups/` + `thumbnail.png`), atomic
debounced autosave with a crash-recovery journal, an in-memory undo/redo command stack of
inverse operations, and the SwiftData metadata index that powers the project browser
(projects, folders, names, search text, export history, font-catalog state, analytics
counters, trial/consent records — metadata ONLY, never scene graphs). The scene graph is
the lingua franca of the whole app: WS-03..WS-08 all read or produce it, so Codable
stability, `Sendable` value semantics, and `schemaVersion` migration discipline are the
core of this packet.

The second mission is durability guarantees the founder locked: autosave ≤2 s after
mutation and immediately on background/memory-pressure, incremental autosave <100 ms off
the main thread (D-115), and no-loss recovery after process termination (BRIEF
"Performance"). You implement the mechanics; WS-07 triggers the memory-pressure ladder
that calls into your synchronous-save API. Undo must model gesture coalescing (a whole
drag = one command) because WS-06 will pump high-frequency transform updates through you.

## 2. Scope

**IN**
- `MKModel`: `MKScene`, `MKNode` enum (`group`, `liveText`, `pathText`, `arranged`,
  `shape`, `image`, `background`), node styles, text styles, transforms (reusing
  `MKTransform2D`), arranged node family + provenance types, `SourceTextBackup`,
  Codable schema with `schemaVersion = 1`, forward-migration hook.
- `.makhtoot` document package read/write, atomic write-temp+rename, content-addressed
  `assets/` store, `backups/` rescue snapshots, `thumbnail.png` slot (thumbnail rendering
  itself is WS-07's `SnapshotRenderer`; you store bytes handed to you).
- Autosave controller (debounce, immediate triggers, journal), crash recovery.
- Undo/redo command stack (`MKCommand` protocol, inverse ops, coalescing, memory budget).
- SwiftData metadata index + query API: project list, folders, rename, duplicate,
  search, export-history records, plus schema slots for font catalog/favorites/download
  state, analytics counters, trial/consent records (populated by WS-09/WS-12/WS-10).
- Document UTI declaration (`com.example.makhtoot.project`, placeholder-derived).

**OUT**
- CloudKit sync (WS-11 builds on your package format).
- Rendering thumbnails (WS-07), shaping (WS-03), arrangement logic (WS-04).
- Project-browser UI (WS-13) — you ship the query/data API only.
- Import decoding of SVG/PDF/raster content (WS-14); you provide the asset-store bytes
  API they call.

## 3. Dependencies

**Upstream:** WS-01 (`MKFoundation` ids/geometry/errors/logging; `MKDocumentStoring`
contract you now implement for real). Stubs you MAY rely on: `StubEntitlementResolver`
(always premium — persistence has no gating), `SystemFontStubProvider` for any font
reference resolution in tests.

**Downstream consumers:** WS-03 (text styles), WS-04 (arranged nodes + provenance +
SourceTextBackup), WS-05 (pathText node), WS-06 (mutation commands, selection acts on
node ids), WS-07 (immutable snapshots to render), WS-08 (export-history records,
scene snapshot input), WS-11 (package payloads for CKSyncEngine), WS-13 (metadata
queries), WS-14 (asset store).

## 4. Locked decisions binding this packet (quoted)

- **D-111**: "Immutable value-type tree (`MKScene` → `MKNode` enum cases: `group`,
  `liveText`, `pathText`, `arranged(text)`, `shape`, `image`, `background`). Node:
  `id: UUID`, transform (position/rotation/scale, decomposed, not raw matrix), z-order,
  opacity, style (fill: solid color v1; stroke; shadow), locked/hidden, name. Arranged
  children: glyph/mark/ligature nodes with provenance (codepoints, glyph id, font
  reference, joining form, cluster id). Single canvas per project in v1 (multi-page is an
  extension seam)."
- **D-112**: "File-package documents + JSON scene + SwiftData metadata index. … Project =
  `.makhtoot` file package: `manifest.json` (ids, schemaVersion, canvas size, thumbnail
  refs), `scene.json` (Codable scene graph), `assets/` (imported raster/SVG/PDF,
  content-addressed), `backups/` … `thumbnail.png`. Atomic writes: write-temp + rename;
  debounced autosave (≤2 s after mutation, plus immediate on background/memory-pressure);
  crash-recovery journal of the last un-flushed command batch. Undo/redo: in-memory
  command stack of inverse operations on the value-type scene (unbounded within memory
  budget, coalesced gestures = single command). SwiftData store (app support dir) holds
  ONLY metadata… Never the scene graph."
- **D-102**: engines `Sendable`; "renderer works on immutable scene snapshots (value-type
  scene graph) so export/preview never race the editor."
- **D-106** (model shape only): Arranged Composition contents "Glyph Nodes (glyph id,
  font ref, path, position, advance, joining state, source codepoints), Mark Nodes
  (attached, relative offset, follow-base default), Ligature Groups (member glyph node +
  constituent codepoints + decomposable flag). Source string + full style state stored as
  Source Text Backup."
- **D-115**: "incremental autosave <100 ms off main thread; open typical project
  (≤100 nodes) <1 s, heavy (5 000 nodes) <3 s."
- **D-223** (amends D-116; adjusts D-210 claim): critical-path (stage-3/memory-pressure-
  critical) autosave is journal-only — synchronous, append-only flush of `journal.mkj`,
  no scene re-encode, no new large allocations. Full-scene `flushNow()` runs only at
  stages 1–2 and on the normal debounced path. Journal artifact is canonically
  `journal.mkj` at the `.makhtoot` package root (not under `backups/`, which holds
  rescue snapshots only). Stage tests must assert save-completes-before-evict ordering
  at every stage.
- §0 table: extension `.makhtoot`, UTI `com.example.makhtoot.project` (placeholder-
  derived), `schemaVersion` integer starting at 1.

## 5. Task breakdown (ordered)

1. **`MKNodeStyle.swift`**: `MKFill` (solid color v1 — sRGB components + optional named
   swatch per D-117), `MKStroke` (width, color, join/cap), `MKShadow` (offset, blur,
   color, opacity), all `Codable`, `Sendable`, `Equatable`. *Accept:* JSON round-trip
   test; unknown-key tolerance (decode ignores unknown fields).
2. **`MKTextStyle.swift`**: font reference (`MKFontRef`: postScript name, size, catalog
   id, `userImported` flag slot), kerning, tracking, baseline shift, line height,
   ligature setting (`standard`/`discretionaryOn`/`off`), paragraph base direction
   (default RTL per D-109). *Accept:* Codable round-trip; defaults documented.
3. **`MKNode.swift` + `MKScene.swift`**: `MKNode` enum with the seven D-111 cases; shared
   `MKNodeCore` struct (`id: MKNodeID`, `name: String`, `transform: MKTransform2D`,
   `zOrder`, `opacity`, `style`, `isLocked`, `isHidden`). `MKScene`: canvas size,
   background node, ordered children, `schemaVersion`. Tree operations as pure functions
   returning new scenes: insert, remove, reorder(z), reparent into `group`, update-node
   by id, find-by-id (indexed). *Accept:* value-semantics test (mutating a copy leaves
   original intact); 5 000-node find-by-id < 1 ms via internal id index.
4. **Arranged node family** in `MKModel/Arranged/`: `GlyphNode` (glyph id `CGGlyph`,
   `MKFontRef`, path stored as `MKBezierPathData` (codable path commands), position,
   advance, `JoiningForm` enum (`isolated/initial/medial/final`), `sourceCodepoints:
   [UnicodeScalarValue]`, `clusterID`, `bidiLevel`, `visualIndex`, per-node transform +
   style); `MarkNode` (same core + `attachedTo: MKNodeID?`, `relativeOffset: CGPoint`,
   `followsBase: Bool` default true, mark codepoint); `LigatureGroup` (member glyph node,
   `constituentCodepoints`, `decomposable: Bool`, stored original glyph id for
   recomposition per D-108); `ArrangedComposition` (nodes in visual order,
   `sourceBackup: SourceTextBackup`, origin frame). *Accept:* Codable round-trip of a
   hand-built composition for "لا"; provenance fields all non-optional where D-106
   requires.
5. **`SourceTextBackup.swift`**: source string, full `MKTextStyle`, path data if derived
   from pathText, creation date. Embedded in the `arranged` node per D-112 ("Source Text
   Backups are embedded in scene nodes"). *Accept:* backup survives scene JSON round-trip
   byte-identically for the string "الله".
6. **Schema + migration**: `scene.json` codec with envelope
   `{schemaVersion: 1, scene: …}`; `MKSceneMigrator` protocol + registry (v1 has no
   migrations; register identity and unit-test the dispatch path). Decoding a NEWER
   version throws `MKError.schemaTooNew` with Arabic message "هذا المشروع أُنشئ بإصدار
   أحدث من مخطوط" (project created with a newer Makhtoot). *Accept:* tests for v1
   decode, unknown-newer rejection, migrator dispatch.
7. **`DocumentPackage.swift`**: create/read/write the `.makhtoot` `FileWrapper`-free
   direct-FS package: `manifest.json` (project id, schemaVersion, canvas size, created/
   modified dates, thumbnail ref, asset index digest), `scene.json`, `assets/`,
   `backups/`, `thumbnail.png`. All writes: serialize to `pkg.tmp-<uuid>` sibling then
   `FileManager.replaceItemAt` (atomic rename). *Accept:* kill-during-write test —
   simulate crash between temp write and rename; reopening yields the previous intact
   version.
8. **Asset store**: content-addressed storage `assets/<sha256>.<ext>`; API
   `storeAsset(data:kind:) -> MKAssetRef`, `assetData(for:)`, refcount sweep on save
   (drop unreferenced assets into `backups/orphans/` for one save cycle before delete).
   *Accept:* same bytes stored twice dedupe to one file; orphan sweep test.
9. **`MakhtootDocument.swift`** (`@MainActor`): open/close lifecycle, current `MKScene`
   value, `apply(_ command: MKCommand)` entry point, publishes scene snapshots
   (`AsyncStream<MKScene>`) for renderer, implements `MKDocumentStoring` replacing WS-01's
   `InMemoryDocumentStore`. *Accept:* open of a 100-node fixture < 1 s, 5 000-node
   fixture < 3 s (D-115) measured with signposts `documentOpen`.
10. **`MKCommand.swift`**: protocol `{ id, name (Arabic label for Undo menu), apply(to:)
    -> MKScene, inverse(against:) -> MKCommand, coalescingKey: String? }`. Concrete
    commands: insert/remove node, update transform, update style, reorder z, group/
    ungroup, lock/hide, rename, canvas-size change, plus opaque `replaceNode` used by
    WS-04/WS-05 for arrange/revert. *Accept:* property test — for random command
    sequences, applying then applying inverses in reverse restores the original scene
    (Equatable compare).
11. **`UndoStack.swift`**: bounded-by-memory undo/redo of `MKCommand`s; coalescing —
    consecutive commands with equal `coalescingKey` within one gesture transaction merge
    (keep first inverse, last apply); explicit `beginGesture()/endGesture()` API for
    WS-06. Redo cleared on new command. *Accept:* 60 Hz simulated drag of 120 transform
    updates yields exactly 1 undo entry; undo restores pre-drag transform.
12. **`AutosaveController.swift`** (actor): debounce 2 s after last mutation; immediate
    `saveNow(reason:)` for background/memory-pressure/critical (called by app lifecycle +
    WS-07 ladder); incremental strategy — write `scene.json` + manifest only when scene
    changed, assets only when asset set changed; all IO off main. Per D-223, a
    stage-3/critical trigger routes to the journal-only synchronous flush (task 13), never
    to a full `scene.json` re-encode; full-scene `flushNow()` is reserved for background
    and stage-1–2 triggers on the normal debounced path. *Accept:* signpost
    measurement shows incremental autosave of the 100-node fixture < 100 ms off-main
    (D-115); mutation storm (100 edits in 1 s) produces ≤ 2 writes; stage-3 trigger test
    asserts only the journal is written (no scene.json/manifest write, no new large
    allocation).
13. **`CommandJournal.swift`**: append-only journal `journal.mkj` at the `.makhtoot`
    package root (D-223 — critical-path autosave is journal-only; `backups/` is reserved
    for rescue snapshots only, never the live journal) of serialized commands since last
    flushed save; truncated after successful save; on open, if journal non-empty → replay
    onto last saved scene, then offer the result as the recovered state and write a
    rescue snapshot `backups/rescue-<date>.json`. *Accept:* crash-recovery test — apply
    10 commands, simulate termination before autosave flush, reopen, all 10 mutations
    present; stage-3 critical-flush test confirms `journal.mkj` at package root is
    written synchronously with no scene re-encode.
14. **SwiftData metadata models** in `MKPersistence/Metadata/`: `ProjectRecord`
    (id, name, folder id, package URL bookmark, canvas size, modified date, thumbnail
    path, search text blob, `premiumContentPresent: Bool` slot for D-119),
    `FolderRecord` (id, name, order), `ExportRecord` (project id, date, format, pixel
    size, preset name, success flag — consumed/written by WS-08), `FontCatalogRecord` +
    `FontFavoriteRecord` slots (WS-09), `AnalyticsCounterRecord`, `ConsentRecord`,
    `TrialRecord` slots (WS-10/WS-12). Store lives in Application Support; never contains
    scene JSON. *Accept:* schema instantiates; CRUD tests; assert no property holds scene
    data.
15. **`MetadataStore.swift` query API**: list projects (sorted, by folder), search
    (name + search-text blob, Arabic-normalized: strip tashkeel U+064B–0652 and unify
    ا/أ/إ/آ, ه/ة, ي/ى before matching), create/rename/delete folder, duplicate project
    (deep-copies package with new ids, name suffix "نسخة" (copy)), record/list export
    history. *Accept:* search test — query "مخطوط" matches record named "مَخْطُوطٌ";
    query "علي" matches "على".
16. **Search-text extraction**: on save, collect project title + every node's layer
    name (recursing into groups) → normalized blob into `ProjectRecord.searchText`.
    Indexes project titles + layer names ONLY — never `liveText`/`pathText` source
    strings or `SourceTextBackup` strings of arranged nodes (D-112 as amended /
    INV-14: no scene text content in the SwiftData index; on-demand content search
    over open packages is a separate, non-indexed feature owned by WS-13). *Accept:*
    project titled "بسم الله" (or containing a layer so named) is findable by "بسم";
    a scene's live-text/arranged source-string content is asserted ABSENT from the
    extracted blob. (corrected during Run 3 per D-112 as amended; see
    docs/impl-log/WS-02.md ADR WS02-A6)
17. **Reconciliation on launch**: scan Documents dir for `.makhtoot` packages, reconcile
    with SwiftData index (add missing, mark orphaned records), so the index is a cache,
    not the source of truth. *Accept:* deleting the SwiftData store and relaunching
    rebuilds the full project list.
18. **UTI + document type declaration** in the app target Info.plist: exported UTI
    `com.example.makhtoot.project` (placeholder-derived, marked FD-01), conforms to
    `com.apple.package`; document type entry so Files shows packages as single documents.
    *Accept:* package appears as one file in the Files app on simulator.
19. **Fixture library** `MakhtootKit/Tests/Fixtures/`: hand-authored scenes —
    `fixture-100-nodes.makhtoot`, `fixture-5000-nodes.makhtoot` (generated by a test
    utility), `fixture-arabic-basic.makhtoot` (live text "بسم الله الرحمن الرحيم"),
    `fixture-arranged-la.makhtoot`. These are reused by WS-06/07/08 tests. *Accept:*
    fixtures decode; generator script checked in.
20. **Concurrency audit**: `MKModel` is entirely `Sendable` value types; `MKPersistence`
    actors (`AutosaveController`, asset store) + `@MainActor` document; zero
    `@unchecked Sendable` except a documented `FileHandle` wrapper if required.
    *Accept:* builds under Swift 6 strict concurrency with no warnings.

## 6. Arabic-correctness notes

- Normalization for search (task 15) must NOT alter stored content — normalize only the
  derived search blob. Fixtures: "مَخْطُوطٌ"→match "مخطوط"; "أحمد"→match "احمد";
  "مصطفى"→match "مصطفي".
- `SourceTextBackup` must preserve the exact codepoint sequence including tashkeel,
  ZWJ/ZWNJ if user-typed, and Arabic-Indic digits — byte-identical round-trip fixtures:
  "شَدَّةٌ وفَتْحَةٌ", "لا", "الله", "عام ٢٠٢٦ / 2026".
- Undo command names are Arabic (e.g., "تحريك" move, "تدوير" rotate, "تجميع" group)
  with Latin gloss comments.
- Duplicate suffix and conflict copy naming use Arabic ("نسخة") consistent with D-112's
  sync conflict label "(نسخة متعارضة)" reserved for WS-11.
- File/folder names typed by users may be Arabic — ensure package paths and bookmarks
  handle Arabic filenames + NFC/NFD variance (APFS): test project named "مشروعي الأول".

## 7. Packet acceptance criteria (gates)

- **Build gate**: `xcodebuild test` green for `MKModelTests`, `MKPersistenceTests`
  (TEST_MATRIX `T-MODEL-*`, `T-PERSIST-*`).
- **D-115 perf gates** (signpost-measured, simulator numbers recorded, device verify in
  WS-07 hardening): open ≤100-node <1 s, 5 000-node <3 s; incremental autosave <100 ms
  off-main (`T-PERF-OPEN-*`, `T-PERF-SAVE-*`).
- **Durability gate**: crash-during-write and journal-replay tests pass 20/20 iterations
  (`T-PERSIST-RECOVER-*`).
- **Manual Arabic checks**: search normalization and Arabic-filename tests from §6
  (`T-ARABIC-M-PERSIST-*`).
- **Contract gate**: WS-01 `InMemoryDocumentStore` fully replaced; CONTRACTS.md updated.

## 8. Deliverables

- `MakhtootKit/Sources/MKModel/MKScene.swift`, `MKNode.swift`, `MKNodeStyle.swift`,
  `MKTextStyle.swift`, `MKFontRef.swift`, `MKBezierPathData.swift`,
  `Arranged/ArrangedComposition.swift`, `Arranged/GlyphNode.swift`,
  `Arranged/MarkNode.swift`, `Arranged/LigatureGroup.swift`,
  `Arranged/SourceTextBackup.swift`, `Arranged/JoiningForm.swift`,
  `Schema/SceneCodec.swift`, `Schema/MKSceneMigrator.swift`
- `MakhtootKit/Sources/MKPersistence/MakhtootDocument.swift`, `DocumentPackage.swift`,
  `AssetStore.swift`, `AutosaveController.swift`, `CommandJournal.swift`,
  `CrashRecovery.swift`, `Undo/MKCommand.swift`, `Undo/Commands.swift`,
  `Undo/UndoStack.swift`, `Metadata/MetadataModels.swift`, `Metadata/MetadataStore.swift`,
  `Metadata/SearchNormalizer.swift`, `Metadata/LaunchReconciler.swift`
- `MakhtootKit/Tests/MKModelTests/*`, `MakhtootKit/Tests/MKPersistenceTests/*`,
  `MakhtootKit/Tests/Fixtures/*`
- Info.plist UTI/document-type additions in the app target.

## 9. References

- ARCHITECTURE.md: §3 Scene Graph & Data Model, §13 Persistence & Documents, §14
  Undo/Redo & Autosave, §12 Performance & Memory (autosave interplay), §20 CloudKit Sync
  (package format contract).
- PRD.md: §3 Project Browser & Documents, §21 Edge-Case Compendium (recovery cases),
  §22 Non-Functional Requirements.
- BRIEF.md: "Canvas & projects" (autosave, folders, search, export history), "Performance"
  (no-loss recovery), "Engineering" (persistence decision Q50).
- Market study: §12 (local-first store guidance)[^61]; §4 provenance requirements
  underpinning arranged node fields[^23].

## 10. Codebase-memory MCP duties

- `manage_adr`: "WS02-A1: scene JSON envelope + migration policy", "WS02-A2: journal
  format & recovery semantics", "WS02-A3: content-addressed asset store with orphan
  grace cycle", each referencing D-111/D-112.
- Implementation log after tasks 6, 13, 17 with test evidence (pass counts, signpost
  numbers for the two open budgets and autosave).
- Store verification evidence: crash-recovery test transcript, perf signpost table,
  Arabic search-normalization test output.
- Re-run `index_repository`; record the fixture library location for WS-06/07/08 agents.

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| Canvas & projects — full undo/redo | T10–T11 |
| Canvas & projects — local autosave (all users) | T12 |
| Canvas & projects — project folders, search, duplicate, export history (all users) | T14–T16 |
| Canvas & projects — premium iCloud project sync (CloudKit) | T7 (package format foundation; sync engine: WS-11) |
| Canvas & projects — v1 imports raster/SVG/PDF as placeable assets | T8 (asset store API; decode: WS-14) |
| Arabic engine — Arrange Mode creates separate arranged-composition structure, retained source backup, revert w/ confirmation | T4–T5 (model only; derivation/revert logic: WS-04) |
| Arabic engine — both levels: store codepoint sequences + resolved glyph/shaping-form references | T4 (`GlyphNode` provenance fields) |
| Arabic engine — tashkeel attach to base by default, follow it, individually selectable/detachable/movable | T4 (`MarkNode` fields; manipulation: WS-04/WS-06) |
| Arabic engine — ligatures: combined selectable object AND decomposable components | T4 (`LigatureGroup`; decompose/recompose logic: WS-04) |
| Arabic engine — per-object kerning/tracking/baseline shift/line height/scale/rotation/opacity/outline/shadow/fill | T1–T2 |
| Performance — no-loss recovery after process termination | T13 |
| Performance — incremental autosave <100 ms off-main, open-time budgets (D-115) | T9, T12 |
| Engineering — persistence decision (Q50) evaluated against arranged-object scale, undo/redo, autosave, imports, CloudKit sync | T3, T7, T11, T12, T14 (whole packet) |
