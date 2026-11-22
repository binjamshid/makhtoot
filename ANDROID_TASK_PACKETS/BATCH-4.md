# Batch 4 — Differentiator and render (6 agents)

Theme: `mk-arrange` (Arrange Mode, the product's differentiator) and `mk-pathtext` +
`mk-render`. Depends on **G3** (textengine/persistence/fonts core green — `mk-arrange` and
`mk-pathtext` both consume `MKShapingCaptureResult` from `:mk-textengine` and the
`MKCommand`/`MKReplaceNodesCommand` undo primitive from `:mk-persistence`; `mk-render`
consumes the scene graph from `:mk-model`). Dispatch the six assignments together so they run concurrently.
Gate: **G4**.

**The differentiator invariant (CLAUDE.md, D-106, R-6.3), binding on every agent in this
batch that touches `mk-arrange` (4.1, 4.2) or the arrange-consuming corners of `mk-pathtext`
(4.3, 4.4) and `mk-render` (4.5, 4.6):** entering Arrange Mode snapshots normally-shaped
Arabic text into a fully manipulable composition where every glyph, tashkeel mark and
ligature component is independently transformable — **without ever breaking Arabic shaping
rules unless the user explicitly asks to.** Arranged Compositions never auto-reflow (R-6.3);
the only re-shaping events are the explicit per-letter form realization (R-8.4/D-107) and
ligature decomposition (R-8.10/D-108), both scoped to only the affected nodes. A change that
silently reshapes, drops tashkeel, or breaks a ligature anywhere in this batch is never
acceptable, on either platform (CLAUDE.md "Never").

---

### Batch 4 · Agent 4.1 — `mk-arrange` derivation, invariants, level mapping

**Depends on:** G3 · **Parallel-safe with:** every other Batch 4 agent

**Mission.** Port the D-106 derivation pipeline that turns one `MKShapingCaptureResult`
(HarfBuzz-shaped, from `:mk-textengine`) plus the source string/style into an
`ArrangedComposition` — Glyph Nodes, Mark Nodes, Ligature Groups, each fully provenanced back
to a Source Text Backup — together with the module's error taxonomy, the glyph-level ↔
letter-level view mapping, the arrange-on-path seam protocol, and the `MKCommand`-based
mutation layer every other file in `:mk-arrange` builds on. When this agent is done,
`ArrangeDeriver.derive(...)` produces byte-for-byte-matching `ArrangedComposition` values
against the Batch 0 golden fixtures, and `ArrangeCommands`/`ArrangeStyleEditor` give 4.2 (and
later Batch 7's arrange toolbar) a working undo-integrated mutation surface.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKArrange/ArrangeDeriver.swift` | Port source — D-106 derivation pipeline, composition-local y-up coordinate convention |
| `MakhtootKit/Sources/MKArrange/ArrangeInvariants.swift` | Port source — `MKArrangeError` taxonomy, `MKArrangeNodeKind` |
| `MakhtootKit/Sources/MKArrange/LevelMapping.swift` | Port source — `ArrangedCompositionIndex`, glyph↔letter view |
| `MakhtootKit/Sources/MKArrange/DecomposeOptions.swift` | Port source — tiny options struct consumed by 4.2's `LigatureDecomposer` |
| `MakhtootKit/Sources/MKArrange/ArrangeCommands.swift` | Port source — `ArrangeCommands` + `ArrangeStyleEditor`, the `MKCommand`-based mutation layer |
| `MakhtootKit/Sources/MKArrange/PathPlacementProviding.swift` | Port source — `PathPlacementProviding` seam + `IdentityPlacement`, consumed for real by 4.3's `MKPathTextPlacementProvider` |
| `MakhtootKit/Tests/MKArrangeTests/ArrangeDeriverTests.swift`, `ArrangeInvariantsTests.swift`, `LevelMappingTests.swift`, `ArrangeCommandTests.swift`, `ArrangeStyleEditorTests.swift`, `DerivationFidelityTests.swift`, `MultiLineBidiTests.swift`, `ArrangeTestFixtures.swift`, `PixelDiff.swift`, `PerfTests.swift` | Tests to port |
| `MakhtootKit/Sources/MKModel/Arranged/*.swift` (`ArrangedComposition`, `MKArrangedTextNode`, `MKGlyphNode`, `MKMarkNode`, `MKLigatureGroup`, `SourceTextBackup`) | Target data model — already ported in Batch 2 (`:mk-model`); this agent derives INTO these Kotlin types, does not redefine them |
| `MakhtootKit/Sources/MKTextEngine/ShapingService.swift` (`MKShapingCaptureResult`) | Input type — already ported in Batch 3 (`:mk-textengine`) |
| `MakhtootKit/Sources/MKPersistence/Undo/MKCommand.swift`, `Commands.swift` (`MKReplaceNodesCommand`) | `ArrangeCommands` builds on this canonical "swap this node's full value" primitive — ported in Batch 3 (`:mk-persistence`) |
| `FOUNDATION.md` §3 (D-105, D-106, D-109, D-111) | Normative derivation/coordinate/provenance rules |
| `MakhtootKit/CONTRACTS.md` "D-220 arranged-geometry chain" section | The affine-chain contract `MKRender`'s `MKArrangedGeometry` (4.5) also implements independently — both must agree numerically |
| `android/PARITY_MATRIX.md`, `android/API_SURFACE.md`, `android/fixtures/arrange/**` | Batch 0 outputs — exact R-id coverage, public API surface to match, golden fixtures to consume |
| `android/mk-arrange/src/main/kotlin/**` (Batch 1 stubs) | `MkNotYetPorted` contract stubs this agent replaces with real bodies |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes the
identically-named Batch 1.3 contract stub at the same path (spine §3.3); delete/overwrite each
stub body as part of landing the real implementation (see Tasks, final item). All six of this
agent's Kotlin targets are 1:1 mechanical transforms of their Swift source (`Mk` + basename)
landing at exactly the path Batch 1 · Agent 1.3 already stubbed — no orphaned stub paths outside
this list.
- `android/mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkArrangeDeriver.kt`
- `android/mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkArrangeInvariants.kt`
- `android/mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkLevelMapping.kt`
- `android/mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkDecomposeOptions.kt`
- `android/mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkArrangeCommands.kt`
- `android/mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkPathPlacementProviding.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkArrangeDeriverTests.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkArrangeInvariantsTests.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkLevelMappingTests.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkArrangeCommandTests.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkArrangeStyleEditorTests.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkDerivationFidelityTests.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkMultiLineBidiTests.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkArrangeTestFixtures.kt` (shared fixture builder — 4.2's suites read this, do not edit it)
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkPixelDiff.kt` (shared pixel-diff helper — 4.2's suites read this, do not edit it)
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkPerfTests.kt` (the `arrange.derive` signpost timing twin)
- `android/docs/impl-log/BATCH-4.1.md`

**Never touch.** `MakhtootKit/**` (read-only, iOS source is the spec — this batch has no
named iOS-side agent), any other module under `android/**`, `android/mk-arrange/src/main/
kotlin/.../MkLigatureDecomposer.kt`, `MkJoinController.kt`, `MkFormSelectorModel.kt`,
`MkMarkAttachmentController.kt`, `MkRevertService.kt` (4.2's exclusive files).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `ArrangeDeriver.swift` | 572 | `MkArrangeDeriver.kt` | `Sendable` struct → Kotlin `object`/stateless class over `data class` inputs (D-302: pure, dispatcher-agnostic). Composition-local y-up coordinate convention is preserved verbatim — do not silently flip to Android's y-down canvas space here; that flip belongs to `:mk-render`'s drawing path only. |
| `ArrangeInvariants.swift` | 119 | `MkArrangeInvariants.kt` | `MKArrangeError: MKError` → a sealed class/exception hierarchy conforming to the shared `MkError` pattern from `:mk-foundation` (Batch 2). `MKArrangeNodeKind` → Kotlin `enum class`. |
| `LevelMapping.swift` | 143 | `MkLevelMapping.kt` | `ArrangedCompositionIndex` (flattens a `.decomposed` `MKLigatureGroup`'s components into the same id space as top-level children) → Kotlin `class`/`object` over `List`/`Map`. |
| `DecomposeOptions.swift` | 21 | `MkDecomposeOptions.kt` | Trivial `data class`. |
| `ArrangeCommands.swift` | 249 | `MkArrangeCommands.kt` | `ArrangeCommands` (node-kind swaps) + `ArrangeStyleEditor` (style/transform edits) both route through `MKReplaceNodesCommand` — the SAME single mechanism, not two, per the file's own documented resolution. Kotlin: both build `MkReplaceNodesCommand` instances for `:mk-persistence`'s undo stack. |
| `PathPlacementProviding.swift` | 60 | `MkPathPlacementProviding.kt` | `PathPlacementProviding` protocol + `MKPathGlyphPlacement` + `IdentityPlacement` → Kotlin `interface` + `data class` + object implementation. `nil` return ("no path override") → Kotlin nullable return (`null`). |

**Tasks.**
1. Port `MkArrangeInvariants.kt` first — every other file in this agent's scope (and 4.2's)
   throws through this taxonomy.
2. Port `MkLevelMapping.kt` (`ArrangedCompositionIndex`, `LevelMapping`) — shared lookup 4.2's
   `JoinController`/`LigatureDecomposer`/`MarkAttachmentController` also need; keep the API
   identical to the Swift signatures listed in `android/API_SURFACE.md` so 4.2 (running
   concurrently) can code against the documented shape without waiting on this agent.
3. Port `MkPathPlacementProviding.kt` (protocol + `IdentityPlacement`) — small, unblocks 4.3's
   real conformer.
4. Port `MkArrangeDeriver.kt` — the D-106 pipeline. Preserve exactly: Glyph Node fields (glyph
   id, font reference incl. variable-axis instance, outline path, position, advance, joining
   state, source codepoint range, cluster id, bidi level + visual index — R-6.2), Mark Node
   attachment (relative offset from shaped GPOS positions, follow-base default — R-6.2/R-7.3),
   Ligature Group detection (cluster with >1 codepoint and 1 glyph — R-6.2), and the embedded
   Source Text Backup (full source string + style state — R-6.2/D-106). Derivation must be
   synchronous and complete in <100 ms for ≤200 glyphs (D-115, R-4 flow FL-4 step 2).
5. Port `MkDecomposeOptions.kt`.
6. Port `MkArrangeCommands.kt` (`ArrangeCommands` + `ArrangeStyleEditor`).
7. Port all ten test files, adapting XCTest/Swift Testing syntax to JUnit5/kotlin.test.
   `MkArrangeTestFixtures.kt` and `MkPixelDiff.kt` are SHARED helpers 4.2's test suites also
   import — keep their public surface exactly matching the Swift originals so 4.2 (built
   concurrently, in the same module) does not need a follow-up edit here.
8. Consume `android/fixtures/arrange/**`'s golden `ArrangedComposition` JSON dumps
   (Batch 0 · Agent 0.2 output) in `ArrangeDeriverTests`/`DerivationFidelityTests`: derive
   from the same source `MKShapingCaptureResult` fixture and assert structural equality
   against the golden, not just "no crash."
9. Update `android/docs/CONTRACT_CHANGES.md` (append-only) if the exact Swift
   `ArrangeDeriver.derive(...)` signature cannot be expressed identically in Kotlin (e.g. a
   Swift `throws` becomes a Kotlin `Result<T>` or a checked exception) — do not silently
   diverge from `android/API_SURFACE.md` without recording why.
10. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.3 contract stubs at every path
    in this agent's Owns list above; name each superseded stub path in
    `android/docs/impl-log/BATCH-4.1.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-arrange:testDebugUnitTest` green
- `./gradlew :mk-arrange:lintDebug` green
- Requirements covered: `R-6.1`, `R-6.2`, `R-6.3`, `R-6.4`, `R-6.8`
- Tests ported: `T-AR-31` (glyph identity unchanged on entry, automated pixel-diff twin),
  T-ARR family numeric twins that exercise derivation-time provenance
- Fixtures consumed: `android/fixtures/arrange/**` (the Batch 0.2 arrange-derivation goldens covering the arrange-relevant fixture scenes from
  `TestFixtures/` — `FIX-ARABIC`'s vocalized «بسم الله الرحمن الرحيم» variant, «بحر»,
  «سلم», «سلام»/«الله»). Reproduce the exact scene set byte for byte.
- `ArrangedComposition` produced by `ArrangeDeriver.derive(...)` structurally equals the
  golden fixture for every scene (not merely "renders similarly")
- Stub count for `ArrangeDeriver`/`ArrangeInvariants`/`LevelMapping`/`DecomposeOptions`/
  `ArrangeCommands`/`PathPlacementProviding` reaches 0

**Impl log.** `android/docs/impl-log/BATCH-4.1.md`

---

### Batch 4 · Agent 4.2 — `mk-arrange` ligature decompose/recompose, join controller, form selector, mark attachment, revert

**Depends on:** G3 · **Parallel-safe with:** every other Batch 4 agent

**Mission.** Port the four D-107/D-108/D-220-governed mutation engines that make Arrange Mode
manipulable rather than merely inspectable — ligature decomposition/recomposition with the
D-221 affine-fit clamp, explicit join break/restore with ZWJ-harvested contextual forms, the
pure form-selector model the toolbar binds to, and mark detach/reattach/move-while-attached —
plus revert-to-text. Every operation here is a scoped re-shape of ONLY the affected node(s);
none may reflow the rest of the composition (R-6.3).

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKArrange/LigatureDecomposer.swift` | Port source — D-108, D-221 n-ary affine-fit placement, the single most intricate algorithm in the module |
| `MakhtootKit/Sources/MKArrange/JoinController.swift` | Port source — D-107 join break/restore |
| `MakhtootKit/Sources/MKArrange/FormSelectorModel.swift` | Port source — pure UI-free model, `MKFormOption` |
| `MakhtootKit/Sources/MKArrange/MarkAttachmentController.swift` | Port source — D-220 normative re-attach formula, implemented to the exact operator per the file's own header |
| `MakhtootKit/Sources/MKArrange/RevertService.swift` | Port source — D-106 §5.4 revert-to-text, confirmation preflight |
| `MakhtootKit/Tests/MKArrangeTests/LigatureDecomposerTests.swift`, `JoinControllerTests.swift`, `FormSelectorModelTests.swift`, `MarkAttachmentControllerTests.swift`, `RevertServiceTests.swift`, `PerFontArrangeFidelitySweepTests.swift`, `JournalRoundTripTests.swift` | Tests to port |
| `android/mk-arrange/src/test/kotlin/.../MkArrangeTestFixtures.kt`, `MkPixelDiff.kt` (4.1's owned files, same batch) | Shared fixture/diff helpers this agent's tests import — read only, do not edit (4.1 owns them) |
| `MakhtootKit/Sources/MKArrange/ArrangeInvariants.swift`, `LevelMapping.swift` (4.1's port targets) | This agent throws through `MKArrangeError` and reads through `ArrangedCompositionIndex`/`LevelMapping` — code against the documented shape in `android/API_SURFACE.md`, do not wait on 4.1 finishing |
| `FOUNDATION.md` §3 (D-107, D-108) | Normative ZWJ-harvest technique and decomposition-fidelity contract |
| `TEST_MATRIX.md` §7.9/§7.13 (T-AR-34…38, T-AR-60…63, T-ARR-1…3, T-ARR-LIG-STYLE, T-ARR-NOREFLOW-1) | Verify the real test ids and their exact numeric tolerances before writing Kotlin equivalents |
| `android/fixtures/arrange/**` (Batch 0) | Round-trip goldens for decompose/recompose |
| `android/mk-arrange/src/main/kotlin/**` (Batch 1 stubs) | Contract stubs this agent replaces |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes the
identically-named Batch 1.3 contract stub at the same path (spine §3.3); delete/overwrite each
stub body as part of landing the real implementation (see Tasks, final item). All five of this
agent's Kotlin targets are 1:1 mechanical transforms of their Swift source landing at exactly the
path Batch 1 · Agent 1.3 already stubbed — no orphaned stub paths outside this list.
- `android/mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkLigatureDecomposer.kt`
- `android/mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkJoinController.kt`
- `android/mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkFormSelectorModel.kt`
- `android/mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkMarkAttachmentController.kt`
- `android/mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkRevertService.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkLigatureDecomposerTests.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkJoinControllerTests.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkFormSelectorModelTests.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkMarkAttachmentControllerTests.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkRevertServiceTests.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkPerFontArrangeFidelitySweepTests.kt`
- `android/mk-arrange/src/test/kotlin/net/binjamshid/makhtoot/mk/arrange/MkJournalRoundTripTests.kt`
- `android/docs/impl-log/BATCH-4.2.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`,
`android/mk-arrange/src/main/kotlin/.../MkArrangeDeriver.kt`, `MkArrangeInvariants.kt`,
`MkLevelMapping.kt`, `MkDecomposeOptions.kt`, `MkArrangeCommands.kt`, `MkPathPlacementProviding.kt`
(4.1's exclusive files), `MkArrangeTestFixtures.kt`, `MkPixelDiff.kt`, `MkPerfTests.kt` (4.1's
exclusive test files).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `LigatureDecomposer.swift` | 361 | `MkLigatureDecomposer.kt` | D-108/D-221 n-ary affine-fit: reshape constituents with joining-preserving context (via `:mk-textengine`'s HarfBuzz bridge, same D-303 mechanism as the rest of shaping) then place via the normative single-affine fit (uniform scale + per-component offsets, first/last edge-aligned) within the **[0.85, 1.15] scale clamp** (R-8.10); outside the clamp, fidelity mode is refused and decomposition falls back to default-forms placement with the R-21.9 notice UX — port this refusal path exactly, it is P0. Recompose dirty-check compares FULL node state (transform AND style: fill/stroke/opacity/shadow — D-221(3)/T-ARR-LIG-STYLE), not just transform. |
| `JoinController.swift` | 149 | `MkJoinController.kt` | D-107 join break/restore. Restore mechanism note from the Swift header: `MKGlyphNode` has no `preBreakSnapshot` field, so restore recomputes via provenance, not a stored snapshot — replicate the same provenance-based restore in Kotlin, do not add a field to `:mk-model`'s ported `MkGlyphNode` to shortcut this (contract-first: a schema change goes through `android/docs/CONTRACT_CHANGES.md`, not this agent). |
| `FormSelectorModel.swift` | 121 | `MkFormSelectorModel.kt` | Pure model, zero UI — `MKFormOption` (per-form preview path + advance + `isValid` + current selection) → `data class`. Batch 7's arrange toolbar binds to this later; this agent ships the model only. |
| `MarkAttachmentController.swift` | 191 | `MkMarkAttachmentController.kt` | **D-220 formula, implemented to the exact operator — no "reasonable equivalent."** `relativeOffset = base.affine⁻¹(mark.worldPos) − base.affine⁻¹(base.worldPos)` computed in BASE-LOCAL space on re-attach (T-ARR-3's no-double-rotation guard). `:mk-render`'s independently-implemented `MkArrangedGeometry` (4.5) must agree with this numerically — the two modules never share code, so agreement is a REAL correctness check, not a shared-implementation tautology; do not import `:mk-render` from `:mk-arrange` to "simplify" this (violates the frozen dependency direction). |
| `RevertService.swift` | 92 | `MkRevertService.kt` | D-106 §5.4. Confirmation preflight string ported verbatim (Arabic, R-6.12/FL-13): "استعادة النص الأصلي سيلغي جميع التعديلات الحرة. متابعة؟". Revert is itself an undoable `MkCommand` (never applied silently) restoring the FULL arranged node on undo. |

**Tasks.**
1. Port `MkMarkAttachmentController.kt` first and validate it numerically against 4.5's
   `MkArrangedGeometry` port the moment both land (cross-module agreement check, not blocking
   this agent's own gate, but flag any divergence in the impl log immediately since it is the
   D-220 correctness backstop).
2. Port `MkJoinController.kt` — D-107's ZWJ-harvest technique now goes through `:mk-native`'s
   HarfBuzz JNI facade (D-303/D-304) instead of Core Text: reshape the single letter in a
   synthetic `U+200D` ZWJ context (e.g. ZWJ+ح+ZWJ for medial) through the SAME font via
   `hb_shape`, then harvest that glyph. Store as a `JoiningForm` enum + resolved glyph id,
   exactly as the Swift side does — never fall back to presentation-form codepoints (D-303's
   restated D-103 rule).
3. Port `MkFormSelectorModel.kt`.
4. Port `MkLigatureDecomposer.kt` — the module's hardest algorithm. Implement the D-221 clamp
   check and its refusal path before anything else in this file; a decomposition that silently
   proceeds outside [0.85, 1.15] instead of refusing is a shaping-correctness violation
   (CLAUDE.md "Never").
5. Port `MkRevertService.kt`.
6. Port all seven test files. `PerFontArrangeFidelitySweepTests` is the per-bundled-font
   fidelity gate (D-222/mirrors T-AR-58) — it must run against every font Batch 3 · Agent 3.7
   registered, not a hardcoded subset.
7. Register any legitimate HarfBuzz-vs-Core-Text form-selector or decomposition delta in
   `android/SHAPING_DELTAS.md` (D-325) with font, input, delta and reason — an unregistered
   delta fails the gate.
8. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.3 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-4.2.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-arrange:testDebugUnitTest` green
- `./gradlew :mk-arrange:lintDebug` green
- Requirements covered: `R-6.5`, `R-6.7`, `R-6.9`, `R-6.11`, `R-6.12`, `R-6.13`, `R-6.14`,
  `R-7.3`–`R-7.10`, `R-8.1`–`R-8.14`
- Tests ported: `T-AR-34`, `T-AR-35`, `T-AR-36`, `T-AR-37`, `T-AR-38`, `T-AR-39`, `T-AR-40`,
  `T-AR-41`, `T-AR-42`, `T-AR-43`, `T-AR-44`, `T-AR-45`, `T-AR-60`, `T-AR-61`, `T-AR-62`,
  `T-AR-63`, `T-ARR-1`, `T-ARR-2`, `T-ARR-3`, `T-ARR-LIG-STYLE`, `T-ARR-NOREFLOW-1` (verify
  each id against `TEST_MATRIX.md` §7.9/§7.13 before writing its Kotlin twin — the ids above
  are transcribed from that section, not invented)
- Fixtures consumed: `android/fixtures/arrange/**` — decompose/recompose round-trip
  goldens (the T-AR-36…38 round-trip class) plus the T-ARR-1…3 numeric mark-position fixtures
- `LigatureDecomposer` round-trip (decompose → recompose) is pixel-identical to the
  pre-decompose golden for every within-clamp fixture; the outside-clamp refusal path is
  exercised by at least one fixture
- Every legitimate HarfBuzz↔Core-Text delta touched by this agent is registered in
  `android/SHAPING_DELTAS.md`
- Stub count for `LigatureDecomposer`/`JoinController`/`FormSelectorModel`/
  `MarkAttachmentController`/`RevertService` reaches 0

**Impl log.** `android/docs/impl-log/BATCH-4.2.md`

---

### Batch 4 · Agent 4.3 — `mk-pathtext` arc-length LUT, layout engine, glyph placement

**Depends on:** G3 · **Parallel-safe with:** every other Batch 4 agent

**Mission.** Port the numeric core of Path Text (D-110): the adaptive arc-length LUT every
other path-text operation samples through, the layout engine that walks a shaped line in
logical reading order along that LUT, the persisted+engine-level layout options, the
runtime-only per-glyph placement output, the editable Bézier path model, and the real
`PathPlacementProviding` conformer 4.1 (Batch 4) already ported the seam for. This is where
`android.graphics.Path`/`PathMeasure` are explicitly NOT a substitute — the LUT's precision
control is the whole point.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKPathText/ArcLengthLUT.swift` | Port source — adaptive per-cubic-segment subdivision, cumulative arc-length table |
| `MakhtootKit/Sources/MKPathText/PathLayoutEngine.swift` | Port source — D-110 core algorithm, DF-6a logical-reading-order pen advance |
| `MakhtootKit/Sources/MKPathText/PathLayoutOptions.swift` | Port source — alignment/overflow/side/spacing engine options |
| `MakhtootKit/Sources/MKPathText/PathGlyphPlacement.swift` | Port source — runtime-only placement output, `PathClusterProvenanceKey` stable carry-over key |
| `MakhtootKit/Sources/MKPathText/PathPlacementProvider.swift` | Port source — `MKPathTextPlacementProvider`, the real conformer of 4.1's `PathPlacementProviding` seam |
| `MakhtootKit/Sources/MKPathText/BezierPathModel.swift` | Port source — editable anchor/handle view over `MKModel.MKBezierPathData` |
| `MakhtootKit/Tests/MKPathTextTests/ArcLengthLUTTests.swift`, `PathLayoutEngineTests.swift`, `PathLayoutEngineFixtureCoverageTests.swift`, `PathPlacementProviderTests.swift`, `BezierPathModelTests.swift`, `PerfTests.swift`, `Fixtures.swift` | Tests to port |
| `AUDIT_2026-07-28.md` | Check for any P4/P7-scoped path-text findings beyond what this packet already carries forward (none currently open per the audit index, but re-verify — do not assume) |
| `docs/impl-log/WS-05.md`, `docs/impl-log/WS-07.md` (the "Fix 2 — MKRender adopts WS-05's real path-text engine" section) | Design rationale, the DF-6a logical-reading-order correction, and the **known-open ArcLengthLUT precision item** (see Tasks 5) |
| `MakhtootKit/Sources/MKModel/MKBezierPathData.swift`, `MKNode.swift` (`MKPathLayoutOptions`, `MKPathTextNode`) | The persisted slice this module's richer engine-level options layer on top of — already ported in Batch 2 (`:mk-model`) |
| `FOUNDATION.md` §3 (D-110) | Normative arc-length parameterization contract |
| `android/fixtures/pathtext/**` (Batch 0) | Golden LUT samples + layout fixtures |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes the
identically-named Batch 1.3 contract stub at the same path (spine §3.3); delete/overwrite each
stub body as part of landing the real implementation (see Tasks, final item). All six of this
agent's Kotlin targets are 1:1 mechanical transforms of their Swift source landing at exactly the
path Batch 1 · Agent 1.3 already stubbed — no orphaned stub paths outside this list.
- `android/mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkArcLengthLUT.kt`
- `android/mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathLayoutEngine.kt`
- `android/mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathLayoutOptions.kt`
- `android/mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathGlyphPlacement.kt`
- `android/mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathPlacementProvider.kt`
- `android/mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkBezierPathModel.kt`
- `android/mk-pathtext/src/test/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkArcLengthLUTTests.kt`
- `android/mk-pathtext/src/test/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathLayoutEngineTests.kt`
- `android/mk-pathtext/src/test/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathLayoutEngineFixtureCoverageTests.kt`
- `android/mk-pathtext/src/test/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathPlacementProviderTests.kt`
- `android/mk-pathtext/src/test/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkBezierPathModelTests.kt`
- `android/mk-pathtext/src/test/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPerfTests.kt`
- `android/mk-pathtext/src/test/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkFixtures.kt` (shared fixture builder — 4.4's suites read this, do not edit it)
- `android/SHAPING_DELTAS.md` (append-only, shared file — add rows only, never remove/edit another agent's rows)
- `android/docs/impl-log/BATCH-4.3.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`,
`android/mk-pathtext/src/main/kotlin/.../MkPathEditModel.kt`, `MkPathTextCommands.kt`,
`MkPathHighlightRibbon.kt` (4.4's exclusive files).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `ArcLengthLUT.swift` | 218 | `MkArcLengthLUT.kt` | Adaptive per-cubic-segment subdivision (0.05 pt flatness tolerance, 16–512 samples/segment), cumulative arc-length table; `point`/`tangent`/`frame`/`nearestLength` do a binary search over the table then evaluate the EXACT analytic cubic at the interpolated `t` (not a linear blend of bracketing points). **`android.graphics.Path` + `PathMeasure` are NOT a substitute — port the LUT itself**, they lack the adaptive-subdivision precision control this module's whole purpose is. |
| `PathLayoutEngine.swift` | 462 | `MkPathLayoutEngine.kt` | D-110 core algorithm. Pen advance is **logical reading order**, not "visual order" (DF-6a corrected the ARCHITECTURE.md wording — each bidi run advances in its own internal order, chained run-by-run in the paragraph's logical sequence per the bidi map from `:mk-textengine`, T-TXT-3/T-PTH-2). Join-continuity mitigation, tracking, alignment/start-offset, baseline side/inside-out all port 1:1. |
| `PathLayoutOptions.swift` | 138 | `MkPathLayoutOptions.kt` | `PathAlignment`, `PathOverflowPolicy` → Kotlin `enum class`. Engine-level options superset of `MkPathLayoutOptions` (the persisted `:mk-model` slice) — most fields here are engine-only, not yet persisted, matching the Swift "known schema gap" note; do not silently add persistence for them without an `android/docs/CONTRACT_CHANGES.md` entry. |
| `PathGlyphPlacement.swift` | 160 | `MkPathGlyphPlacement.kt` | Deliberately NOT serializable (Codable-free in Swift) — keep the Kotlin type runtime-only too (no `@Serializable`). `PathClusterProvenanceKey` is the stable cross-relayout key (cluster ids are freshly minted UUIDs per shaping capture, not stable by themselves) — port this key exactly, it is what makes `PathGlyphUserOffset` carry-over correct across relayouts. |
| `PathPlacementProvider.swift` | 104 | `MkPathPlacementProvider.kt` | `MkPathTextPlacementProvider: PathPlacementProviding` — the real conformer of 4.1's seam. Wires into `:mk-arrange`'s `ArrangeDeriver` for arrange-on-path. |
| `BezierPathModel.swift` | 247 | `MkBezierPathModel.kt` | `PathAnchor`, `PathAnchorTag`, `BezierPathModel` — editable anchor+handle view over `MkBezierPathData`'s flat cubic-segment encoding (owned by `:mk-model`, ported Batch 2). Geometry-only, no gesture/UIKit code. |

**Tasks.**
1. Port `MkArcLengthLUT.kt` first — everything else in this agent (and 4.4, and the arrange-
   on-path seam) samples through it.
2. **Before writing a single line of `MkPathLayoutEngine.kt`, resolve the ArcLengthLUT precision
   status.** This repo's program state carries an OPEN, documented precision defect (not yet
   fixed on iOS): `bezierPathData()` emits degenerate control points (`c1 = a.handleOut ??
   a.point`) giving a smoothstep parametrization, and `adaptiveSampleCount` only checks
   SPATIAL flatness so it never subdivides further for this case — measured ~0.9 pt error at
   interior arc lengths, roughly 9× the module's own <0.1 pt budget (T-PTH-1's own tolerance).
   This affects glyph PLACEMENT, not just the highlight ribbon. Read `AUDIT_2026-07-28.md` and
   `docs/impl-log/WS-05.md`/`docs/impl-log/WS-07.md` for the current state before porting — do
   NOT port the imprecise `bezierPathData()` degenerate-control-point behavior unexamined into
   Kotlin. Two acceptable outcomes, either is fine, but the choice and its rationale MUST be
   recorded in the impl log: (a) port the Swift behavior byte-for-byte (matching iOS exactly,
   including its known error) and flag the same open item in `android/docs/impl-log/
   BATCH-4.3.md` with the measured Android-side error at the same interior arc lengths, or
   (b) fix it on the Android side (proper non-degenerate control-point handling and/or a
   flatness check that also considers parametric non-uniformity) and record the delta from iOS
   explicitly — Android would then be MORE precise than iOS at this specific corner, which is
   allowed but must be documented, not silent. Either way, do not ship an unexamined precision
   bug (spine's explicit instruction) — "unexamined" is the failure mode, not "matches iOS."
3. Also port `HitTester.pathProximity`'s stand-in note forward as a TODO comment only (that
   file is 4.6's, not this agent's) — `MKPolylineArcLength` in `MKRender/Drawers/
   PathTextDrawer.swift` still uses a separate stand-in sampler on iOS rather than
   `ArcLengthLUT.nearestLength`; this agent's `MkArcLengthLUT.kt` should expose `nearestLength`
   with the same signature so 4.6's `HitTester` port can adopt it directly instead of
   reintroducing a second Android-only stand-in.
4. Port `MkPathLayoutEngine.kt` (DF-6a logical-reading-order pen advance, join-continuity
   mitigation, tracking/alignment/overflow).
5. Port `MkPathLayoutOptions.kt`, `MkPathGlyphPlacement.kt`.
6. Port `MkPathPlacementProvider.kt` (real conformer for 4.1's arrange-on-path seam).
7. Port `MkBezierPathModel.kt`.
8. Port all seven test files, including the LUT's degenerate-near-zero-length-segment case
   (T-PTH-1's fallback-tangent requirement — no NaN/infinite tangents).
9. Register any HarfBuzz-vs-Core-Text delta this module's shaping-dependent layout surfaces
   (e.g. glyph advances feeding arc-length consumption) in `android/SHAPING_DELTAS.md`.
10. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.3 contract stubs at every path
    in this agent's Owns list above; name each superseded stub path in
    `android/docs/impl-log/BATCH-4.3.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-pathtext:testDebugUnitTest` green
- `./gradlew :mk-pathtext:lintDebug` green
- Requirements covered: `R-9.1`, `R-9.2`, `R-9.3`, `R-9.4`, `R-9.5`, `R-9.6`
- Tests ported: `T-PTH-1`, `T-PTH-2`, `T-PTH-3`, `T-PTH-5`
- Fixtures consumed: `android/fixtures/pathtext/**` — unit-circle and degenerate-segment
  LUT samples (T-PTH-1), the «سلام Hello ٤٥» / multi-switch / no-space-digit-adjacency
  layout fixtures (T-PTH-2)
- Position error <0.1 pt at 1000-pt scale on the unit-circle LUT fixture, OR the documented,
  measured delta from that budget if outcome (a) in Task 2 was chosen — never an unexamined
  gap
- Arc offsets strictly increase in logical reading order for every T-PTH-2 fixture; total
  consumed arc length equals the sum of advances + tracking
- Stub count for `ArcLengthLUT`/`PathLayoutEngine`/`PathLayoutOptions`/`PathGlyphPlacement`/
  `PathPlacementProvider`/`BezierPathModel` reaches 0

**Impl log.** `android/docs/impl-log/BATCH-4.3.md`

---

### Batch 4 · Agent 4.4 — `mk-pathtext` editing: path edit model, commands, highlight ribbon

**Depends on:** G3 · **Parallel-safe with:** every other Batch 4 agent

**Mission.** Port the pure geometry operations Batch 5's canvas gesture layer drives Path Text
editing from, the thin coalescable `MkCommand` builders the inspector/canvas bindings call,
and the shared highlight-ribbon geometry both the renderer and (later) the export path paint.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKPathText/PathEditModel.swift` | Port source — pure path-editing geometry, zero gesture/UIKit code |
| `MakhtootKit/Sources/MKPathText/PathTextCommands.swift` | Port source — `PathTextCommands`, `MKReplaceNodesCommand` builders over a `pathText` node |
| `MakhtootKit/Sources/MKPathText/PathHighlightRibbon.swift` | Port source — pure geometry, shared by render (4.5) and later export |
| `MakhtootKit/Tests/MKPathTextTests/PathEditModelTests.swift`, `PathTextCommandsTests.swift`, `PathHighlightRibbonTests.swift` | Tests to port |
| `android/mk-pathtext/src/main/kotlin/.../MkBezierPathModel.kt`, `MkArcLengthLUT.kt` (4.3's port targets, same batch) | This agent mutates/samples these — code against the documented Swift signatures in `android/API_SURFACE.md`, do not wait on 4.3 finishing |
| `android/mk-pathtext/src/test/kotlin/.../MkFixtures.kt` (4.3's owned file, same batch) | Shared fixture helper this agent's tests import — read only |
| `MakhtootKit/Sources/MKPersistence/Undo/Commands.swift` (`MKReplaceNodesCommand`) | The canonical command primitive this agent's builders produce — ported in Batch 3 |
| `android/fixtures/pathtext/**` (Batch 0) | Golden fixtures for edit-model structural-validity round trips |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes the
identically-named Batch 1.3 contract stub at the same path (spine §3.3); delete/overwrite each
stub body as part of landing the real implementation (see Tasks, final item). All three of this
agent's Kotlin targets are 1:1 mechanical transforms of their Swift source landing at exactly the
path Batch 1 · Agent 1.3 already stubbed — no orphaned stub paths outside this list.
- `android/mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathEditModel.kt`
- `android/mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathTextCommands.kt`
- `android/mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathHighlightRibbon.kt`
- `android/mk-pathtext/src/test/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathEditModelTests.kt`
- `android/mk-pathtext/src/test/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathTextCommandsTests.kt`
- `android/mk-pathtext/src/test/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathHighlightRibbonTests.kt`
- `android/docs/impl-log/BATCH-4.4.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`,
`android/mk-pathtext/src/main/kotlin/.../MkArcLengthLUT.kt`, `MkPathLayoutEngine.kt`,
`MkPathLayoutOptions.kt`, `MkPathGlyphPlacement.kt`, `MkPathPlacementProvider.kt`,
`MkBezierPathModel.kt` (4.3's exclusive files), `MkFixtures.kt` (4.3's exclusive test file).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `PathEditModel.swift` | 207 | `MkPathEditModel.kt` | Pure functions over `BezierPathModel` for Batch 5's `:mk-canvas` gesture layer to drive. ZERO gesture/UIKit/hit-testing-UI code — keep the Kotlin port equally free of Compose/View imports. Every operation keeps the path structurally valid or returns `null`/leaves it unchanged (never produces an invalid path). |
| `PathTextCommands.swift` | 169 | `MkPathTextCommands.kt` | Every builder produces exactly ONE `MkReplaceNodesCommand` — the canonical journal-codable "swap this node's full value" primitive, same pattern as 4.1's `ArrangeCommands`. |
| `PathHighlightRibbon.swift` | 240 | `MkPathHighlightRibbon.kt` | Pure geometry (no `CGContext`/`Canvas` drawing calls) — unit-testable directly, and SHARED by 4.5's `PathTextDrawer` port and (Batch 5's) export path highlight rendering, avoiding a silently-drifting duplicate implementation. Keep it drawing-API-free in Kotlin too. |

**Tasks.**
1. Port `MkPathHighlightRibbon.kt` first (pure geometry, no dependency on this agent's other two
   files) — 4.5 needs its exact shape to build `PathTextDrawer`'s highlight rendering against.
2. Port `MkPathEditModel.kt` — every editing operation (insert anchor, move handle, split, etc.)
   must leave `BezierPathModel` structurally valid; assert this in the ported tests exactly as
   the Swift accept criterion states.
3. Port `MkPathTextCommands.kt`.
4. Port all three test files.
5. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.3 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-4.4.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-pathtext:testDebugUnitTest` green
- `./gradlew :mk-pathtext:lintDebug` green
- Requirements covered: `R-9.3`, `R-9.4`, `R-9.9`
- Tests ported: `T-PTH-4`
- Fixtures consumed: `android/fixtures/pathtext/**` (path-edit structural-validity
  fixtures)
- `PathEditModel` operations never produce a structurally invalid `BezierPathModel` across the
  full ported test suite
- Stub count for `PathEditModel`/`PathTextCommands`/`PathHighlightRibbon` reaches 0

**Impl log.** `android/docs/impl-log/BATCH-4.4.md`

---

### Batch 4 · Agent 4.5 — `mk-render` drawers and geometry

**Depends on:** G3 · **Parallel-safe with:** every other Batch 4 agent

**Mission.** Port the single-render-path core (INV-2/INV-6): the scene renderer that
traverses the scene in z-order and dispatches to per-kind drawers, every one of those drawers
(arranged compositions, background, images, live text, path text, shapes, and the shared fill/
stroke/shadow painting they all use), the D-220 arranged-geometry affine chain, node-local
bounds math, and the `RenderNode`-backed layer tree WS-06/Batch 5's canvas host attaches to.
`CGContext` → `android.graphics.Canvas`. **This agent also owns `android/docs/RENDER_TOLERANCE.md`**
(spine `§6` G4, `§12`) — Skia and Core Graphics rasterise antialiased vector art differently, so
G4's "render goldens within tolerance" requirement needs a concrete, justified number, not an
unstated "pixel tolerance"; this agent produces the first real render goldens in the plan, so it
is the natural owner (4.6, which owns caches/memory/hit-testing rather than pixel output, is not).

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKRender/SceneRenderer.swift` | Port source — `MKSceneRenderer`, "the ONLY drawing entry point" (INV-2/INV-6) |
| `MakhtootKit/Sources/MKRender/Drawers/*.swift` (ArrangedDrawer, BackgroundDrawer, ImageDrawer, LiveTextDrawer, PathTextDrawer, ShapeDrawer, StylePainting) | Port source — per-node-kind drawing |
| `MakhtootKit/Sources/MKRender/Geometry/*.swift` (ArrangedGeometry, NodeLocalBounds) | Port source — D-220 affine chain, local/world bounds |
| `MakhtootKit/Sources/MKRender/LayerTreeBuilder.swift` | Port source — `MKLayerTreeController`, the real `RenderTreeProviding` conformer, D-114/D-305 layer-per-node model |
| `MakhtootKit/Sources/MKRender/RenderOptions.swift` | Port source — `MKRenderQuality`, `MKRenderReport`/`MKRenderSubstitution` |
| `MakhtootKit/Sources/MKRender/RenderTreeProviding.swift` | Port source — the layer-tree host protocol |
| `MakhtootKit/Sources/MKRender/AssetProviding.swift` | Port source — `MKAssetProviding` seam `ImageDrawer` uses |
| `MakhtootKit/Tests/MKRenderTests/ArrangedGeometryTests.swift`, `CommittedTransformSyncTests.swift`, `EvictOffscreenCoordinateSpaceTests.swift`, `FlipRenderingTests.swift`, `FontStubProviderTests.swift`, `ImageOrientationTests.swift`, `InvariantGateTests.swift`, `LiveTextHighlightAndDecorationTests.swift`, `PathTextHighlightTests.swift`, `RTLMultiLineAlignmentTests.swift`, `SceneRendererTests.swift`, `StrokeWidthCompensationTests.swift`, `TextBoundsClippingTests.swift`, `TestHelpers.swift` | Tests to port |
| `MakhtootKit/CONTRACTS.md` "WS-07 (`MKRender`) — renderer bring-up contract" section | The frozen public API this port must match: `MKSceneRenderer.render(...)`, `RenderTreeProviding`, `MKArrangedGeometry.worldTransform(ofChild:...)`/`worldTransform(ofMark:...)` |
| `AUDIT_2026-07-28.md` P-3 finding | `setVisibleRect` coordinate-space bug (scroll-view space vs. content-host-layer space) — port the FIXED version (`vc.scrollView.convert(...)`), not the original bug, and keep `EvictOffscreenCoordinateSpaceTests`'s zoom 0.5×/4× regression coverage |
| `docs/impl-log/WS-07.md` "Fix 2 — MKRender adopts WS-05's real path-text engine" | `PathTextDrawer` now uses the real `ArcLengthLUT`/`PathLayoutEngine` (4.3's port), not the old `MKPolylineArcLength` stand-in, for DRAWING — the stand-in survives only in `HitTester` (4.6's file, separate reason) |
| `android/mk-pathtext/src/main/kotlin/.../MkArcLengthLUT.kt`, `MkPathLayoutEngine.kt`, `MkPathHighlightRibbon.kt` (Batch 4's 4.3/4.4 outputs) | `MkPathTextDrawer.kt` depends on these — `:mk-render`'s `build.gradle.kts` dependency edge already includes `:mk-pathtext`, per the corrected dependency table in spine `§3.2` (an earlier, wrong table omitted this edge; the current one has it, so this assertion is now true). Agent 1.1 is the sole owner of every `build.gradle.kts` through Batch 8 (spine `§3.2`/`§17`) — this agent never edits a Gradle file itself; if a module edge this agent needs is missing, that is a `android/docs/CONTRACT_CHANGES.md` entry, not a direct edit |
| `android/fixtures/render/**` (Batch 0) | Pixel-tolerance render goldens |

**Owns (creates or edits — no other agent may touch these).** Every path below that has a Swift
port source supersedes the identically-named Batch 1.3 contract stub at the same path (spine
§3.3); delete/overwrite each such stub body as part of landing the real implementation (see
Tasks, final item). All fourteen of this agent's Kotlin targets are 1:1 mechanical transforms of
their Swift source landing at exactly the path Batch 1 · Agent 1.3 already stubbed — no orphaned
stub paths outside this list. (`android/docs/RENDER_TOLERANCE.md` is a new doc this agent
authors, not a stub supersession.)
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkSceneRenderer.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/drawers/MkArrangedDrawer.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/drawers/MkBackgroundDrawer.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/drawers/MkImageDrawer.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/drawers/MkLiveTextDrawer.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/drawers/MkPathTextDrawer.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/drawers/MkShapeDrawer.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/drawers/MkStylePainting.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/geometry/MkArrangedGeometry.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/geometry/MkNodeLocalBounds.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkLayerTreeBuilder.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkRenderOptions.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkRenderTreeProviding.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkAssetProviding.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkArrangedGeometryTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkCommittedTransformSyncTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkEvictOffscreenCoordinateSpaceTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkFlipRenderingTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkFontStubProviderTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkImageOrientationTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkInvariantGateTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkLiveTextHighlightAndDecorationTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkPathTextHighlightTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkRtlMultiLineAlignmentTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkSceneRendererTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkStrokeWidthCompensationTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkTextBoundsClippingTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkTestHelpers.kt` (shared test helper — 4.6's suites read this, do not edit it)
- `android/docs/RENDER_TOLERANCE.md`
- `android/docs/impl-log/BATCH-4.5.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`,
`android/mk-render/src/main/kotlin/.../MkBitmapCache.kt`, `MkContentHash.kt`,
`MkDegradationController.kt`, `MkMemoryPressureMonitor.kt`, `MkTileRenderer.kt`,
`MkSnapshotRenderer.kt`, `MkHitTester.kt`, `MkRenderSignposts.kt`, `MkStubRenderTree.kt` (4.6's
exclusive files).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `SceneRenderer.swift` | 125 | `MkSceneRenderer.kt` | `MKSceneRenderer.render(scene:region:into:scale:quality:)` — traverses z-order (background → nodes ascending), applies transform/opacity, dispatches per-kind. `CGContext` param → `android.graphics.Canvas`. Keep it the ONLY drawing entry point — INV-2/INV-6 must hold on Android: canvas preview and export call this exact function, never a view snapshot/`draw()`-to-bitmap shortcut. |
| `Drawers/ArrangedDrawer.swift` | 95 | `drawers/MkArrangedDrawer.kt` | Per child in `Index.paintOrder`, concat world affine per §5.3's D-220 chain via `MkArrangedGeometry.kt` (this agent, below), fill/stroke the stored outline path. Never consults the font at render time (INV-13) — a missing outline records `.missingOutline` in the render report, it never triggers a re-shape. |
| `Drawers/BackgroundDrawer.swift` | 56 | `drawers/MkBackgroundDrawer.kt` | Transform ignored, always canvas-filling — fills `canvasBounds`, never the node's own transform. |
| `Drawers/ImageDrawer.swift` | 114 | `drawers/MkImageDrawer.kt` | Raster (`Bitmap`) and vector-PDF asset placement via `MkAssetProviding.kt`'s seam. `MKImageOrientation`/`MKImageAspect` → `enum class`. |
| `Drawers/LiveTextDrawer.swift` | 278 | `drawers/MkLiveTextDrawer.kt` | Draws through `:mk-textengine`'s HarfBuzz shaping capture (D-104/D-303: committed rendering is always the shaping-capture→render path so canvas and export are pixel-identical) — never the cached overlay content from Batch 5's IME layer. |
| `Drawers/PathTextDrawer.swift` | 369 | `drawers/MkPathTextDrawer.kt` | Builds `BezierPathModel` → `ArcLengthLUT` (4.3's port) → `PathLayoutEngine.layout`/`.layoutClosed` (4.3's port, DF-6a-correct traversal) → draws each placement. Degenerate/zero-length path guard records `.missingAsset` and falls back to drawing as live text at origin, same as iOS. Mark placements (incl. the fused case where `markGlyph == nil` reuses the base's own address) draw too — harmless pixel-redundant duplicate draw, not a bug, port it as-is. |
| `Drawers/ShapeDrawer.swift` | 80 | `drawers/MkShapeDrawer.kt` | `Path` fill/stroke for every `MKShapeNode.geometry` case except `.asset` (handled by `ImageDrawer`). |
| `Drawers/StylePainting.swift` | 168 | `drawers/MkStylePainting.kt` | Shared fill/stroke/shadow every drawer uses. No double-darkening of overlapping mark/base shadows — each node gets its own transparency-layer/shadow state (`Canvas.saveLayer` region matching CG's `beginTransparencyLayer`), never accumulated. Degradation-ladder `.reduced` fidelity: flat offset fill at 30% alpha, no blur — wire this to 4.6's `MKDegradationController` port. |
| `Geometry/ArrangedGeometry.swift` | 163 | `geometry/MkArrangedGeometry.kt` | D-220 normative affine chain, implemented ONCE here so `ArrangedDrawer` (this agent) and `HitTester` (4.6) share exactly one geometry truth. `worldTransform(ofChild:...)` = `composition.affine ∘ child.affine`; `worldTransform(ofMark:...)` = `composition.affine ∘ base.affine ∘ translate(relativeOffset) ∘ mark.affine`. Must numerically agree with 4.2's `MarkAttachmentController` — the two modules never share code (no `:mk-render` → `:mk-arrange` dependency), so agreement is a real cross-module correctness check. |
| `Geometry/NodeLocalBounds.swift` | 71 | `geometry/MkNodeLocalBounds.kt` | `localBounds` (pre-transform) / `worldBounds` (post-transform) — same "unit square, size via transform.scale" convention `ShapeDrawer`/`ImageDrawer` use. |
| `LayerTreeBuilder.swift` | 481 | `MkLayerTreeBuilder.kt` | `MKLayerTreeController` → the real `RenderTreeProviding` conformer. D-305/FDA-07: one `RenderNode` per top-level node — **`RenderNode` (API 29+) is the only path; there is no API 26–28 `Picture` + bitmap-cache fallback to port, minSdk is 29** (transform-only changes are property updates, matching the CALayer model — zero re-raster on committed move/resize/rotate when content hash is unchanged, per the P4-exit fix this file already carries on iOS). `contentsScale = screenScale × zoomBucket` (mirrors iOS §11.3). Re-rasterizes only when 4.6's `ContentHash` changes. **Port the FIXED `setVisibleRect` coordinate space (AUDIT P-3): convert the caller's view/scroll-space rect into the content-host-layer's own unscaled space before intersecting for `evictOffscreen()`** — do not port the original bug, and keep the zoom 0.5×/4× regression test. |
| `RenderOptions.swift` | 93 | `MkRenderOptions.kt` | `MKRenderQuality`: `.editorPreview(stage:)` tracks 4.6's degradation stage; `.exportQuality` NEVER degrades (D-118) — this is a hard invariant Batch 5's export agents (5.6/5.7) also depend on. `MKRenderReport`/`MKRenderSubstitution` → `data class`. |
| `RenderTreeProviding.swift` | 49 | `MkRenderTreeProviding.kt` | The layer-tree host `interface`: `sync(to:)`, `applyTransientTransform`/`commitTransients` (60/120 Hz hot path — layer-property-only, zero draw work), `setVisibleRect`, `consumeRasterizationCount()` (test/HUD observability). |
| `AssetProviding.swift` | 54 | `MkAssetProviding.kt` | `MKAssetProviding` protocol + `MKEmptyAssetProvider` stub — `interface` + empty object. Real conformer lands with Batch 5's `:mk-assets`/`:mk-persistence` wiring at the composition root (Batch 7), not this agent. |

**Tasks.**
1. Port `geometry/MkArrangedGeometry.kt` and `geometry/MkNodeLocalBounds.kt` first — every drawer
   depends on them.
2. Port `MkRenderOptions.kt`, `MkRenderTreeProviding.kt`, `MkAssetProviding.kt` (small, unblocks the
   drawers and 4.6's caches which also reference `MKRenderQuality`/`RenderTreeProviding`).
3. Port `drawers/MkStylePainting.kt` (every other drawer depends on it).
4. Port `drawers/MkBackgroundDrawer.kt`, `MkShapeDrawer.kt`, `MkImageDrawer.kt` (simplest three).
5. Port `drawers/MkLiveTextDrawer.kt`.
6. Port `drawers/MkArrangedDrawer.kt` — validate its output against 4.2's `MarkAttachmentController`
   port numerically the moment both exist (cross-agent geometry agreement, the real D-220
   correctness check).
7. Port `drawers/MkPathTextDrawer.kt` — depends on 4.3's `ArcLengthLUT`/`PathLayoutEngine` and
   4.4's `PathHighlightRibbon`; if those land after this agent starts, code against the
   documented API in `android/API_SURFACE.md` rather than blocking.
8. Port `MkSceneRenderer.kt` (ties every drawer together).
9. Port `MkLayerTreeBuilder.kt` last — the largest file, and the one carrying the P-3 coordinate-
   space fix forward. Write `MkEvictOffscreenCoordinateSpaceTests.kt` to assert a centered layer
   at zoom 0.5× and 4× survives `evictOffscreen()` — this is the regression the AUDIT finding
   requires, not optional coverage.
10. Port all fourteen test files.
11. Register any HarfBuzz-vs-Core-Text delta visible at the drawing layer (e.g. glyph outline
    shape differences affecting `MkArrangedDrawer`) in `android/SHAPING_DELTAS.md`.
12. Write `android/docs/RENDER_TOLERANCE.md`: a per-channel (8-bit RGB) tolerance, a maximum
    fraction of differing pixels per compared raster, and a written justification for both
    numbers (Skia vs. Core Graphics antialiasing differences), starting from spine `§12`'s
    numbers (≤6 per channel, ≤1.0% differing pixels) and tightening or loosening them once this
    agent's own render goldens are in hand — validated, not merely asserted, at G4.
13. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.3 contract stubs at every path
    in this agent's Owns list above; name each superseded stub path in
    `android/docs/impl-log/BATCH-4.5.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-render:testDebugUnitTest` green
- `./gradlew :mk-render:lintDebug` green
- Requirements covered: `R-4.3`, `R-13.1` (single-render-path half of it — the export-side
  half is Batch 5 · Agent 5.6/5.7's)
- Tests ported: `T-CVS-6` (render-side crispness half), `T-EXP-1`'s render-path precondition
- Fixtures consumed: `android/fixtures/render/**` — pixel-tolerance render goldens for
  every drawer, the D-220 affine-chain numeric fixtures
- **INV-2/INV-6 explicit acceptance test**: canvas preview and export both call
  `MkSceneRenderer.render(...)` with no alternate code path (e.g. no `View.draw()`-to-bitmap
  capture anywhere in this module) — assert this by code inspection AND by a pixel-identical
  comparison test between a preview-path render and an export-path render of the same scene
  snapshot at the same dimensions
- `MkEvictOffscreenCoordinateSpaceTests` passes at zoom 0.5× and 4× (P-3 regression closed)
- `MkArrangedGeometry`'s Kotlin port numerically agrees with 4.2's `MkMarkAttachmentController`
  port on the T-ARR-1/T-ARR-2 fixture inputs (cross-module D-220 agreement, ≤0.05 pt / ≤0.05°
  tolerance, same as the Swift test)
- `android/docs/RENDER_TOLERANCE.md` exists with a justified per-channel tolerance and a
  justified max-differing-pixels fraction, both stated as numbers this agent validated against
  its own render goldens, not merely copied from spine `§12`'s starting values
- Stub count for every file in this agent's port map reaches 0

**Impl log.** `android/docs/impl-log/BATCH-4.5.md`

---

### Batch 4 · Agent 4.6 — `mk-render` caches, degradation, memory, hit testing

**Depends on:** G3 · **Parallel-safe with:** every other Batch 4 agent

**Mission.** Port the D-116/D-223 memory-pressure ladder (stage machine + sampling), the
bitmap cache and content-hash dirty-check it governs, huge-canvas tiling, snapshot/thumbnail
rendering, hit testing (consumed directly by Batch 5's canvas gesture/selection policy), perf
signposts, and the flat-color stub render tree. Two audit findings are explicitly in scope:
**P-1** (`ContentHash` re-serializes every node to JSON on every render sync) and the D-116/
D-223 ladder's mapping onto Android's `onTrimMemory` levels.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKRender/BitmapCache.swift` | Port source — LRU, byte-budgeted, `MKMemoryAccountable`-conforming |
| `MakhtootKit/Sources/MKRender/ContentHash.swift` | Port source — **carries forward AUDIT P-1**, see Tasks |
| `MakhtootKit/Sources/MKRender/DegradationController.swift` | Port source — D-116/D-223 stage machine + fidelity seam |
| `MakhtootKit/Sources/MKRender/MemoryPressureMonitor.swift` | Port source — D-116 sampling seam |
| `MakhtootKit/Sources/MKRender/TileRenderer.swift` | Port source — huge-canvas/huge-node tiling bounds math (direct-draw region rendering, ADR WS07-A2) |
| `MakhtootKit/Sources/MKRender/SnapshotRenderer.swift` | Port source — `MKSnapshotRenderer`, the pixel-out entry point every consumer (canvas bitmaps, thumbnails, export strips) uses |
| `MakhtootKit/Sources/MKRender/HitTester.swift` | Port source — point→node, point→arranged-child, path-proximity hit testing |
| `MakhtootKit/Sources/MKRender/RenderSignposts.swift` | Port source — perf instrumentation for every D-115 budget this module owns |
| `MakhtootKit/Sources/MKRender/StubRenderTree.swift` | Port source — flat-colored-rect `RenderTreeProviding` stub |
| `MakhtootKit/Tests/MKRenderTests/BitmapCacheTests.swift`, `ContentHashTests.swift`, `DegradationLadderTests.swift`, `HitTesterTests.swift`, `MarkSelectionTests.swift`, `MemoryGovernorIntegrationTests.swift`, `MemoryStressDriveTests.swift`, `PerfHarnessTests.swift`, `SnapshotRendererTests.swift` | Tests to port |
| `AUDIT_2026-07-28.md` P-1 finding (`MKContentHash.hash(of:scaleBucket:)`) | **Read before writing `MkContentHash.kt`** — see Tasks 2 |
| `MakhtootKit/CONTRACTS.md` "Memory-pressure ladder — hooks/seams only" section | `MKMemoryStage`, `MKRenderFidelity`, `MKAutosaveTriggering`, `MKDegradationController`, `MKMemoryPressureMonitor` public shapes |
| `FOUNDATION.md` §5 (D-116) | The verbatim stage-2 banner text and the three-stage semantics |
| `android/mk-render/src/main/kotlin/.../MkRenderOptions.kt`, `MkRenderTreeProviding.kt` (4.5's port targets, same batch) | This agent references `MkRenderQuality`/`RenderTreeProviding` — code against the documented Swift API, do not wait on 4.5 |
| `android/mk-render/src/test/kotlin/.../MkTestHelpers.kt` (4.5's owned file, same batch) | Shared test helper this agent's suites import — read only |
| `android/fixtures/render/**` (Batch 0) | Hit-test and memory-ladder fixtures |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes the
identically-named Batch 1.3 contract stub at the same path (spine §3.3); delete/overwrite each
stub body as part of landing the real implementation (see Tasks, final item). All nine of this
agent's Kotlin targets are 1:1 mechanical transforms of their Swift source landing at exactly the
path Batch 1 · Agent 1.3 already stubbed — no orphaned stub paths outside this list.
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkBitmapCache.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkContentHash.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkDegradationController.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkMemoryPressureMonitor.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkTileRenderer.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkSnapshotRenderer.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkHitTester.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkRenderSignposts.kt`
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkStubRenderTree.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkBitmapCacheTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkContentHashTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkDegradationLadderTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkHitTesterTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkMarkSelectionTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkMemoryGovernorIntegrationTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkMemoryStressDriveTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkPerfHarnessTests.kt`
- `android/mk-render/src/test/kotlin/net/binjamshid/makhtoot/mk/render/MkSnapshotRendererTests.kt`
- `android/docs/impl-log/BATCH-4.6.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`,
`android/mk-render/src/main/kotlin/.../MkSceneRenderer.kt`, `drawers/**`, `geometry/**`,
`MkLayerTreeBuilder.kt`, `MkRenderOptions.kt`, `MkRenderTreeProviding.kt`, `MkAssetProviding.kt`
(4.5's exclusive files), `MkTestHelpers.kt` (4.5's exclusive test file).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `BitmapCache.swift` | 139 | `MkBitmapCache.kt` | LRU keyed `(nodeContentHash, scaleBucket)`, byte-budgeted, offscreen-first eviction. `actor` → a Kotlin class synchronized via a `Mutex`/single-threaded dispatcher context (D-302: UI on `Dispatchers.Main.immediate`). Conforms to the shared memory-accountable contract so a future cross-module governor can register it, same as iOS's `MKMemoryAccountable`. |
| `ContentHash.swift` | 152 | `MkContentHash.kt` | **Carries forward AUDIT P-1 — do not port the JSON round-trip.** iOS's `MKContentHash` JSON-encodes the entire node content (worst case: an ENTIRE arranged composition, every glyph/mark/outline path) on every call, allocating a fresh `JSONEncoder` each time — this is flagged as a real, unfixed performance defect on iOS, worst on Arrange Mode (the product's differentiator). **Implement the Android port as the audit's recommended fix, not the current iOS behavior**: a structural FNV-1a accumulator fed directly from typed fields (position, style, outline point arrays, glyph ids, …) with NO JSON/`Data`/`String` round-trip anywhere in the hot path. Keep `MKScaleBucket`'s bucketing logic identical. |
| `DegradationController.swift` | 248 | `MkDegradationController.kt` | `MKMemoryStage` (`normal`/`stage1`/`stage2`/`critical`) → `enum class`, `Comparable`. `MKAutosaveTriggering`/`MKUndoCapReclaiming` → `interface`s. Stage-2 banner text ported VERBATIM: `"الذاكرة شبه ممتلئة — تم الحفظ تلقائيًا"`. `transition(to:)` must preserve the save-before-degrade ordering (INV-17/D-223): the autosave flush COMPLETES before cache eviction/fidelity degradation begins, not merely "both eventually happen" — this is instrumentation-verified on iOS (T-MEM-1/T-MEM-2) and must be equally verifiable on Android via signpost-equivalent timestamps. |
| `MemoryPressureMonitor.swift` | 148 | `MkMemoryPressureMonitor.kt` | `actor` → Kotlin coroutine-based sampler. **Dual mechanism, mirroring the iOS `DispatchSource.makeMemoryPressureSource` + periodic `os_proc_available_memory()` sampling**: event-driven via `ComponentCallbacks2.onTrimMemory(level)` registered on the Application, PLUS periodic polling via `ActivityManager.getMemoryInfo(MemoryInfo)`/`Debug.getMemoryInfo(Debug.MemoryInfo)` mapped through the same `MKMemoryThresholds` 70%/85%-of-available percentage logic. Map `TRIM_MEMORY_RUNNING_LOW`/`TRIM_MEMORY_RUNNING_CRITICAL` (foreground pressure) to stage1/stage2, and `TRIM_MEMORY_COMPLETE`/`TRIM_MEMORY_BACKGROUND` (about to be killed / already backgrounded) to the critical/journal-only path (D-223) — record the exact mapping table in the impl log, this is new Android-specific design not a 1:1 API substitution. Injectable sampler/clock preserved for the same 0→1→2→3-and-back unit-test seam iOS has (task 10's accept criterion). |
| `TileRenderer.swift` | 58 | `MkTileRenderer.kt` | Direct-draw region rendering (ADR WS07-A2, no `CATiledLayer`-equivalent mosaic sublayers) — `SnapshotRenderer.render(scene:region:scale:quality:)` already renders an arbitrary sub-rect; this file is purely the bounds-splitting math. Consumed by Batch 5's `TiledRasterExporter` port (5.6). |
| `SnapshotRenderer.swift` | 97 | `MkSnapshotRenderer.kt` | `MKSnapshotRenderer.render(...)` → `Bitmap?`/`CGImage?` substitute; `renderThumbnail(longEdge:)`; `makeFlippedBitmapContext` → the canonical flipped (top-left origin, y-down) `Canvas`-backed `Bitmap` factory every destination (canvas layer bitmap, thumbnail, export strip) goes through. Keep this the SAME factory 5.6's tiled export strips call, matching the Swift design note. |
| `HitTester.swift` | 337 | `MkHitTester.kt` | Point→node (z-ordered, topmost first), `allHits` (full candidate stack for Batch 5's §10.3 tap-cycling, locked nodes INCLUDED per the founder's R-4.6 ruling — locked-skip is a canvas-side POLICY filter, not a `HitTester` exclusion), `worldGeometry`/`containsPrecise` (OBB + precise point-in-node test), `arrangedChild` hit (glyph/mark/ligature granularity), `pathProximity`. **`pathProximity` still uses a `MKPolylineArcLength`-equivalent stand-in on iOS rather than 4.3's `ArcLengthLUT.nearestLength`** — since this is a NEW Android port with no legacy stand-in to preserve, use `ArcLengthLUT.nearestLength` (4.3's port) directly here instead of reintroducing the iOS stand-in; this is a documented, allowed improvement over the iOS source, not a deviation requiring `CONTRACT_CHANGES.md` (no public API changes, purely an internal implementation swap for an already-open iOS TODO). |
| `RenderSignposts.swift` | 138 | `MkRenderSignposts.kt` | `os_signpost` → Android's `android.os.Trace`/`androidx.tracing.Trace` (`beginSection`/`endSection`/`trace {}`), or a lightweight custom perf-log wrapper if Trace sections don't cover the needed nested-interval shape — cover the same categories (`renderTile`, `layerSync`, `pathRelayout`) and the same cross-module signpost names from `TEST_MATRIX.md` §1.5 (`frame.manipulate`, `arrange.derive`, etc.) so Batch 8's performance agent can rely on identical instrumentation names across platforms. |
| `StubRenderTree.swift` | 90 | `MkStubRenderTree.kt` | Flat solid-color rect per node, zero real drawing — unblocks Batch 5's canvas host development against `RenderTreeProviding` before `LayerTreeBuilder` (4.5) is needed at runtime. |

**Tasks.**
1. **Read `AUDIT_2026-07-28.md`'s P-1 and P-2 entries before writing anything in this
   agent's scope** (spine's explicit instruction).
2. Port `MkContentHash.kt` implementing the audit's recommended fix (structural FNV hash, no
   JSON round-trip) — this is a hard requirement, not optional polish, because Arrange Mode
   (the product's differentiator) is the worst-case caller (every glyph/mark/outline path in
   a composition, on every render sync).
3. Port `MkDegradationController.kt` and `MkMemoryPressureMonitor.kt` together — write the
   `onTrimMemory`-level-to-`MKMemoryStage` mapping table explicitly in the impl log (D-116/
   D-223 carried onto Android's memory model is new design, not a lookup).
4. Port `MkBitmapCache.kt`.
5. Port `MkTileRenderer.kt`, `MkSnapshotRenderer.kt`.
6. Port `MkHitTester.kt` — adopt 4.3's `ArcLengthLUT.nearestLength` for `pathProximity`
   directly (see port-map note).
7. Port `MkRenderSignposts.kt`, `MkStubRenderTree.kt`.
8. Port all nine test files. `DegradationLadderTests`/`MemoryGovernorIntegrationTests`/
   `MemoryStressDriveTests` must prove the save-before-degrade/save-before-evict ORDERING
   (timestamp evidence), matching T-MEM-1/T-MEM-2's "not merely both eventually happen"
   requirement — do not weaken this to a looser assertion on Android.
9. Carry the P-2 finding's shape forward as a design note only (P-2 itself — four concurrent
   100 ms/150 ms/1 s/2 s polling loops replaceable with `withObservationTracking`/scroll
   callbacks — is an app-shell (`EditorViewModel`) finding, out of this module's fence; but
   `MemoryPressureMonitor`'s own 2 s sampling loop IS in scope here): honor the same fix intent
   locally — the 2 s sampling loop should suspend when the app is backgrounded/stopped
   (`ProcessLifecycleOwner`/`onStop`), not run unconditionally forever, matching P-2's "gate on
   scenePhase"/lifecycle recommendation even though this agent does not touch the app-shell
   polling loops themselves (those port in Batch 7).
10. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.3 contract stubs at every path
    in this agent's Owns list above; name each superseded stub path in
    `android/docs/impl-log/BATCH-4.6.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-render:testDebugUnitTest` green
- `./gradlew :mk-render:lintDebug` green
- Requirements covered: `R-6.9` (hit-testing half), `R-4.6` (locked-nodes-included-in-hit-
  stack policy substrate)
- Tests ported: `T-MEM-1`, `T-MEM-2`, `T-MEM-3`
- Fixtures consumed: `android/fixtures/render/**` — hit-test candidate-stack fixtures,
  memory-ladder stage-transition fixtures
- `MkContentHash.kt` contains no `JSONEncoder`/`kotlinx.serialization` round-trip in its hash
  path — verified by code inspection as an explicit acceptance item (P-1 closed, not merely
  "ported")
- `DegradationLadderTests`/`MemoryGovernorIntegrationTests` prove autosave-completes-before-
  eviction/degrade ordering with timestamp evidence, not assertion-order-only
- `MemoryPressureMonitor`'s sampling loop suspends when the process is backgrounded (P-2
  intent honored locally)
- Stub count for every file in this agent's port map reaches 0

**Impl log.** `android/docs/impl-log/BATCH-4.6.md`

---

## Appendix — file-ownership matrix (collision proof)

| Path prefix | 4.1 | 4.2 | 4.3 | 4.4 | 4.5 | 4.6 |
|---|---|---|---|---|---|---|
| `android/mk-arrange/src/main/kotlin/.../MkArrangeDeriver.kt` | ✅ | | | | | |
| `android/mk-arrange/src/main/kotlin/.../MkArrangeInvariants.kt` | ✅ | | | | | |
| `android/mk-arrange/src/main/kotlin/.../MkLevelMapping.kt` | ✅ | | | | | |
| `android/mk-arrange/src/main/kotlin/.../MkDecomposeOptions.kt` | ✅ | | | | | |
| `android/mk-arrange/src/main/kotlin/.../MkArrangeCommands.kt` | ✅ | | | | | |
| `android/mk-arrange/src/main/kotlin/.../MkPathPlacementProviding.kt` | ✅ | | | | | |
| `android/mk-arrange/src/test/kotlin/.../{MkArrangeDeriver,MkArrangeInvariants,MkLevelMapping,MkArrangeCommand,MkArrangeStyleEditor,MkDerivationFidelity,MkMultiLineBidi}Tests.kt` | ✅ | | | | | |
| `android/mk-arrange/src/test/kotlin/.../{MkArrangeTestFixtures,MkPixelDiff,MkPerfTests}.kt` | ✅ | | | | | |
| `android/mk-arrange/src/main/kotlin/.../MkLigatureDecomposer.kt` | | ✅ | | | | |
| `android/mk-arrange/src/main/kotlin/.../MkJoinController.kt` | | ✅ | | | | |
| `android/mk-arrange/src/main/kotlin/.../MkFormSelectorModel.kt` | | ✅ | | | | |
| `android/mk-arrange/src/main/kotlin/.../MkMarkAttachmentController.kt` | | ✅ | | | | |
| `android/mk-arrange/src/main/kotlin/.../MkRevertService.kt` | | ✅ | | | | |
| `android/mk-arrange/src/test/kotlin/.../{MkLigatureDecomposer,MkJoinController,MkFormSelectorModel,MkMarkAttachmentController,MkRevertService,MkPerFontArrangeFidelitySweep,MkJournalRoundTrip}Tests.kt` | | ✅ | | | | |
| `android/mk-pathtext/src/main/kotlin/.../MkArcLengthLUT.kt` | | | ✅ | | | |
| `android/mk-pathtext/src/main/kotlin/.../MkPathLayoutEngine.kt` | | | ✅ | | | |
| `android/mk-pathtext/src/main/kotlin/.../MkPathLayoutOptions.kt` | | | ✅ | | | |
| `android/mk-pathtext/src/main/kotlin/.../MkPathGlyphPlacement.kt` | | | ✅ | | | |
| `android/mk-pathtext/src/main/kotlin/.../MkPathPlacementProvider.kt` | | | ✅ | | | |
| `android/mk-pathtext/src/main/kotlin/.../MkBezierPathModel.kt` | | | ✅ | | | |
| `android/mk-pathtext/src/test/kotlin/.../{MkArcLengthLUT,MkPathLayoutEngine,MkPathLayoutEngineFixtureCoverage,MkPathPlacementProvider,MkBezierPathModel,MkPerfTests,MkFixtures}.kt` | | | ✅ | | | |
| `android/mk-pathtext/src/main/kotlin/.../MkPathEditModel.kt` | | | | ✅ | | |
| `android/mk-pathtext/src/main/kotlin/.../MkPathTextCommands.kt` | | | | ✅ | | |
| `android/mk-pathtext/src/main/kotlin/.../MkPathHighlightRibbon.kt` | | | | ✅ | | |
| `android/mk-pathtext/src/test/kotlin/.../{MkPathEditModel,MkPathTextCommands,MkPathHighlightRibbon}Tests.kt` | | | | ✅ | | |
| `android/mk-render/src/main/kotlin/.../MkSceneRenderer.kt` | | | | | ✅ | |
| `android/mk-render/src/main/kotlin/.../drawers/**` | | | | | ✅ | |
| `android/mk-render/src/main/kotlin/.../geometry/**` | | | | | ✅ | |
| `android/mk-render/src/main/kotlin/.../MkLayerTreeBuilder.kt` | | | | | ✅ | |
| `android/mk-render/src/main/kotlin/.../MkRenderOptions.kt` | | | | | ✅ | |
| `android/mk-render/src/main/kotlin/.../MkRenderTreeProviding.kt` | | | | | ✅ | |
| `android/mk-render/src/main/kotlin/.../MkAssetProviding.kt` | | | | | ✅ | |
| `android/mk-render/src/test/kotlin/.../{MkArrangedGeometry,MkCommittedTransformSync,MkEvictOffscreenCoordinateSpace,MkFlipRendering,MkFontStubProvider,MkImageOrientation,MkInvariantGate,MkLiveTextHighlightAndDecoration,MkPathTextHighlight,MkRtlMultiLineAlignment,MkSceneRenderer,MkStrokeWidthCompensation,MkTextBoundsClipping}Tests.kt` + `MkTestHelpers.kt` | | | | | ✅ | |
| `android/mk-render/src/main/kotlin/.../MkBitmapCache.kt` | | | | | | ✅ |
| `android/mk-render/src/main/kotlin/.../MkContentHash.kt` | | | | | | ✅ |
| `android/mk-render/src/main/kotlin/.../MkDegradationController.kt` | | | | | | ✅ |
| `android/mk-render/src/main/kotlin/.../MkMemoryPressureMonitor.kt` | | | | | | ✅ |
| `android/mk-render/src/main/kotlin/.../MkTileRenderer.kt` | | | | | | ✅ |
| `android/mk-render/src/main/kotlin/.../MkSnapshotRenderer.kt` | | | | | | ✅ |
| `android/mk-render/src/main/kotlin/.../MkHitTester.kt` | | | | | | ✅ |
| `android/mk-render/src/main/kotlin/.../MkRenderSignposts.kt` | | | | | | ✅ |
| `android/mk-render/src/main/kotlin/.../MkStubRenderTree.kt` | | | | | | ✅ |
| `android/mk-render/src/test/kotlin/.../{MkBitmapCache,MkContentHash,MkDegradationLadder,MkHitTester,MkMarkSelection,MkMemoryGovernorIntegration,MkMemoryStressDrive,MkPerfHarness,MkSnapshotRenderer}Tests.kt` | | | | | | ✅ |
| `android/SHAPING_DELTAS.md` (append-only, shared) | | | ✅ | | ✅ | |
| `android/docs/impl-log/BATCH-4.{1..6}.md` | ✅ (4.1) | ✅ (4.2) | ✅ (4.3) | ✅ (4.4) | ✅ (4.5) | ✅ (4.6) |

No two agents in this batch write the same path. `android/SHAPING_DELTAS.md` is the one
shared, append-only exception (ground rule 5's contract-first spirit applied to a log file
rather than a public API) — agents append rows only, never edit or remove another agent's row.

> **Writer note:** the spine names the exact Swift symbols and files each agent owns but does
> not itemize test-file-to-agent assignment at the granularity of individual `Tests/
> MK*Tests/*.swift` files. This packet assigns them by tracing each test file to the source
> file(s) it exercises (verified against the actual Swift `Tests/` directory listings), so
> that between two sibling agents in the same batch every test file has exactly one owner and
> the two owned sets are exhaustive and disjoint — cross-checked against the real `wc -l`
> totals for `MKArrange` (2,078), `MKPathText` (1,945), and `MKRender` (3,603): each batch's
> per-agent LOC splits sum to the module total with no gap or overlap.
