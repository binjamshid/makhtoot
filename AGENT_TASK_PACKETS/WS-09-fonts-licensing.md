# WS-09 — Fonts & Licensing (MKFonts)

Run-1 agent task packet · Makhtoot (مخطوط) · Target module: `MKFonts` (MakhtootKit) plus Settings→Support→Licensing data feed. Consumes FOUNDATION.md D-119, D-120, D-121, D-122, FD-04, FD-07.

---

## 1. Mission

Build `MKFonts`, the complete fonts subsystem of Makhtoot: a registry of bundled OFL starter fonts, a premium downloadable catalog, premium-only user font import, and the license-metadata layer that renders at Settings→Support→Licensing (الإعدادات ← الدعم ← التراخيص). Fonts are the raw material of the whole product — every Live Text object, Arranged Composition, and export path (WS-03/04/08) resolves fonts through this module — so the registry must be deterministic, offline-first, and fast (all bundled fonts registered and queryable before the first editor scene appears). The module also owns catalog UX data: categories (Naskh, Ruq'ah, Thuluth, Diwani, Kufi, Maghrebi, modern display, Qur'anic-style, handwriting, Arabic-Latin bilingual), favorites, tags, search, previews, and per-font character-coverage computation.

Equally important, this packet is a *legal* workstream: no font ships without a captured license file and a completed verification record produced by the per-font VERIFICATION PROTOCOL defined below. The market study verified Amiri, Noto Naskh Arabic, and the broader Noto Arabic family as OFL 1.1[^25][^26][^27][^28][^30]; every other D-120 candidate is *unverified until the protocol passes*. KFGQPC/Uthmani fonts are prohibited (non-commercial EULA)[^31][^32]. You must never invent, assume, or extrapolate a license. Fonts whose verification fails are dropped from the bundle, logged, and reported — not shipped.

## 2. Scope

**IN:**
- `MKFonts` library target: font registry, descriptors, registration (`CTFontManagerRegisterFontURLs(.process)`), catalog store integration with `MKPersistence` SwiftData metadata.
- Bundled OFL starter set acquisition + per-font verification protocol + verification records + license bundle resources.
- Premium catalog: static JSON manifest schema, entitlement-gated HTTPS download, checksum validation, bundle-fallback build mode (D-121/FD-04); foreground manifest fetch service with 24h staleness TTL, disk cache, and zero-manifest empty state (DF-7).
- User font import (premium-only, D-122): Files picker flow contract, sfnt validation, content-addressed copy, registration, `userImported` flagging.
- Favorites, tags, search, category taxonomy, preview-string rendering data, character-coverage computation.
- Expiry locking behavior (D-119 interaction): premium + imported fonts lock when entitlement lapses.
- License-record data model + query API consumed by WS-12's Settings→Support→Licensing screen.
- FD-07 hooks: catalog schema fields for future commercial foundry licensing (license class, embedding rights, per-export-format rights), inert in v1.

**OUT:**
- Shaping/glyph extraction (WS-03 `MKTextEngine`), export font embedding decisions (WS-08 — but this packet supplies the per-license embedding-rights bits it reads), paywall UI (WS-10), Settings screen rendering (WS-12), any Qur'anic *content* (prohibited by BRIEF), commercial foundry negotiation (FD-07, post-v1), On-Demand Resources (rejected in D-121).

## 3. Upstream dependencies, stubs, downstream consumers

**Upstream:**
- `MKFoundation` (WS-01): ids, logging, errors, `MKFeatureFlags`.
- `MKPersistence` (WS-02): SwiftData metadata store for catalog state, favorites, download state.
- `MKStore` (WS-10): entitlement queries. **Stub strategy:** until WS-10 lands, use the shared protocol `MKEntitlementProviding` (defined in `MKFoundation`) with the `AlwaysPremiumEntitlementStub` used by earlier packets. This packet codes only against the protocol; WS-10 replaces the stub. Expiry-locking tasks (T18–T19) must be testable by injecting a `free`/`expired` fake through the same protocol.
- Network: `URLSession` only; no third-party dependencies (D-101).

**Downstream consumers:** WS-03 (font handles for shaping), WS-04 (form resolution uses same registered fonts), WS-08 (embedding-rights bits per license record; locked-font export gating), WS-10 (locking triggers on entitlement change notifications), WS-12 (license records rendering), WS-13 (font picker panel in editor, onboarding preview fonts), WS-15 (license files must be present in the archived bundle — checklist item).

## 4. Locked decisions binding this packet

- **D-120**: "Bundled starter set: OFL-verified only; initial candidates (each requires the WS-09 verification protocol before inclusion): Amiri, Amiri Quran, Noto Naskh Arabic, Noto Kufi Arabic, Noto Sans Arabic, Scheherazade New, Lateef, Harmattan, Reem Kufi, Aref Ruqaa, Mada, Tajawal, Almarai, El Messiri, Markazi Text, Rakkas, Katibeh, Jomhuria, Mirza, Qahiri. No font ships without a captured license file + verification record. KFGQPC/Uthmani fonts are prohibited (non-commercial EULA)."
- **D-121**: "fonts are data, not code → direct HTTPS download after entitlement confirmation is App-Store-compliant; v1 premium catalog is hosted as a static JSON manifest + font files on founder-controlled storage (FD-04 hosting decision); fallback documented: bundle premium fonts in-app behind entitlement if hosting is not ready at submission. On-Demand Resources rejected."
- **D-122**: "all non-system fonts register per-process via `CTFontManagerRegisterFontURLs(.process)` (spelling per D-219) at launch/on-demand. User import (premium): Files picker → sfnt table validation (accept ttf/otf/ttc/variable; reject woff/woff2/bitmap-only/corrupt with specific Arabic error messages) → content-addressed copy into container → register → catalog entry flagged `userImported` (locks on expiry)."
- **D-119** (expiry): "Expired premium: fonts lock (render with last cached shaping for display + lock badge, re-shape blocked), photo backgrounds locked, export limited to free matrix."
- **FD-04** (open): premium hosting location. **FD-07** (open): commercial foundry budget/process — v1 = OFL only; build schema hooks, not features.
- BRIEF: license/attribution/foundry/commercial-status/character-coverage/source links live at Settings→Support→Licensing, not in the primary catalog (Q66).

## 5. Task breakdown (ordered)

**T1 — Types & registry skeleton.** Create `Sources/MKFonts/`: `MKFontID` (stable string id, e.g. `"amiri-regular"`), `MKFontFace` (PostScript name, family, style, weight, isVariable, formats), `MKFontOrigin` enum (`bundled`, `premiumDownloaded`, `userImported`), `MKFontCategory` enum with exactly: `naskh, ruqah, thuluth, diwani, kufi, maghrebi, modernDisplay, quranicStyle, handwriting, bilingual` (Arabic display names, e.g. `نسخ، رقعة، ثلث، ديواني، كوفي، مغربي…`). `MKFontRegistry` actor exposing `faces()`, `face(for:)`, `ctFont(for:size:)`. **AC:** compiles in Swift 6 strict concurrency; registry is `Sendable`; unit test constructs registry with a fixture font.

**T2 — License record model.** `MKLicenseRecord`: `fontID, familyName, licenseType` (enum: `ofl11`, `apacheV2Reserved`, `commercial(FD07)`, `prohibited`), `copyrightNotice: String`, `reservedFontNames: [String]`, `sourceRepoURL: URL`, `licenseFileBundlePath: String`, `verificationDate: Date`, `verifiedBy: String` (agent/run id), `redistributionConfirmed: Bool`, `embeddingRights: MKEmbeddingRights` (bitset: `pdfSubsetEmbed`, `svgFontFaceEmbed`, `rasterOnly`) — WS-08 reads this. This exact shape is now the CANONICAL `MKLicenseRecord` app-wide per D-227(1): ARCHITECTURE §17.3 has been rewritten to match it, and WS-08's §16.5/§16.6 `embedPDF`/`embedSVG` consumers are accessors over `embeddingRights` — do not diverge from this field set. Codable; stored as JSON resource `LicenseRecords/records.json` in the MKFonts bundle plus mirrored into SwiftData for query. **AC:** decoding round-trip test; a record with `redistributionConfirmed == false` causes registry to refuse to load that font (test asserts).

**T3 — VERIFICATION PROTOCOL (document + executable checklist).** Write `Sources/MKFonts/Resources/VERIFICATION_PROTOCOL.md` codifying, per candidate font, these mandatory steps:
1. Locate the authoritative upstream repository (Google Fonts GitHub org, `notofonts/arabic`[^27], `aliftype/*`[^28][^30][^37], SIL for Scheherazade New/Lateef/Harmattan). Font-aggregator mirror sites are NOT authoritative[^35].
2. Capture the exact `OFL.txt`/`LICENSE` file from that repo at a pinned commit hash; store verbatim at `Resources/Licenses/<fontID>/OFL.txt`.
3. Record the copyright line and all Reserved Font Names from the license header into the `MKLicenseRecord`.
4. Confirm the redistribution clause: OFL 1.1 permits bundling/embedding/redistribution with software provided copyright + license text accompany the font and Reserved Font Names are not reused for modified derivatives[^26][^28][^30]. Quote the clause reference in the record notes.
5. Confirm the binary being bundled is byte-identical to (or built unmodified from) the upstream release; record release tag + SHA-256 of each font file.
6. Write the completed `MKLicenseRecord`; append a verification-evidence entry (see §10).
7. **Fidelity gate (D-222)** — a license-clean font still cannot ship until it ALSO
   passes the WS-04 arrange-fidelity test block run specifically against THIS font:
   `T-AR-31/32/33` plus the decompose/recompose round-trip `T-AR-36..38` (not merely the
   reduced cross-font sweep `T-AR-58`). A font that fails this gate is EXCLUDED exactly
   like a license failure — log it in `EXCLUDED_FONTS.md` with the failing test ids, not
   just the license reason.
8. **GPOS cursive-attachment audit (D-222)** — inspect the font's GPOS table for lookup
   type 3 (cursive attachment) applied to base glyphs; record present/absent in the
   verification record. If ANY shipped font uses GPOS type 3, WS-02's D-105 capture
   layer needs a cursive-pair structure before that font can ship — this is a
   VERIFY-per-font blocking condition (do not assume support exists; check and record).
Failure at any step ⇒ font is EXCLUDED, logged in `EXCLUDED_FONTS.md` with reason. KFGQPC/Uthmani anything is auto-fail (prohibited)[^31][^32]. **AC:** protocol file exists; registry loader enforces "no record → no registration"; a font passing steps 1–6 but failing step 7 or flagged unresolved at step 8 is excluded, not shipped provisionally.

**T4 — Execute protocol for the D-120 candidate list.** Run T3 for all 20 candidates: Amiri, Amiri Quran, Noto Naskh Arabic, Noto Kufi Arabic, Noto Sans Arabic, Scheherazade New, Lateef, Harmattan, Reem Kufi, Aref Ruqaa, Mada, Tajawal, Almarai, El Messiri, Markazi Text, Rakkas, Katibeh, Jomhuria, Mirza, Qahiri. Amiri + Noto Arabic family are pre-verified OFL 1.1 by the market study[^25][^26][^27][^28][^30] but still need license files captured + records written; all others are candidates only — do the full protocol, mark anything unresolvable `VERIFY-AT-SUBMISSION` and exclude from the build until resolved. **AC:** every shipped font has `Resources/Licenses/<fontID>/` + record; `EXCLUDED_FONTS.md` lists any dropouts; zero fonts without records in the bundle (script check in T20); every shipped font's record also carries a passing D-222 fidelity-gate result (T-AR-31/32/33 + T-AR-36..38) and a GPOS cursive-attachment audit finding.

**T5 — Bundled registration at launch.** `MKFontRegistrar` registers all bundled font URLs with `CTFontManagerRegisterFontURLs([url] as CFArray, .process, true, nil)` during app bootstrap, off the main actor, before the project browser renders font previews; idempotent (already-registered errors tolerated). **AC:** cold-launch instrument shows registration <150 ms for 20 families on A15; `ctFont(for:)` returns non-nil for every record; duplicate-launch registration produces no user-visible error.

**T6 — Catalog metadata & SwiftData integration.** Define `MKFontCatalogEntry` (SwiftData model in MKPersistence, written via protocol `MKFontCatalogStore`): fontID, origin, categories, tags, isFavorite, downloadState (`notDownloaded`, `downloading(progress)`, `downloaded`, `failed(errorCode)`), isLocked, importDate. Registry publishes catalog snapshots via `AsyncStream`. **AC:** favorites toggle persists across relaunch (test via in-memory store); search index (T8) reads from the same snapshot.

**T7 — Category & tag assignment.** Assign each verified bundled font its categories and tags (e.g., Amiri → naskh + quranicStyle tag `كلاسيكي`; Aref Ruqaa → ruqah; Reem Kufi/Noto Kufi → kufi; Rakkas/Jomhuria/Katibeh → modernDisplay; Mirza → handwriting-adjacent nastaliq-flavored — tag but categorize `handwriting`; Tajawal/Almarai/Mada → bilingual + modernDisplay). Category data lives in `catalog-seed.json`, not code. **AC:** every bundled font has ≥1 category; every one of the 10 categories has ≥0 fonts and the catalog UI contract exposes empty-category handling; no category invented beyond the locked list.

**T8 — Search & filtering.** Arabic-aware search across family name (Arabic + Latin), tags, categories: normalize (strip tashkeel U+064B–065F from query, unify alef forms أ/إ/آ→ا, ة→ه optional fold), case-insensitive Latin. `MKFontSearchIndex` returns ranked matches (prefix > substring; favorites boosted). **AC:** query "نسخ" returns all naskh-category fonts; query "amiri"/"أميري" both return Amiri; empty query returns full catalog ordered by category then name.

**T9 — Preview provisioning.** Per-font preview data: default preview string `"بسم الحرف العربي وجماله"` (no religious text — user-neutral sample; do NOT use Qur'anic verses per BRIEF Q67–68) + numerals sample `"١٢٣ 123"` + user-overridable preview text. Registry exposes `previewAttributedString(for:size:)` used by catalog UI (WS-13) — rendering itself is the consumer's job. **AC:** preview API returns styled attributed string with correct font; preview never triggers a download for undownloaded premium fonts (uses catalog thumbnail metadata instead).

**T10 — Character-coverage computation.** `MKCoverageAnalyzer`: from `CTFontCopyCharacterSet`, compute coverage of defined ranges: Arabic (U+0600–06FF), Arabic Supplement (0750–077F), Arabic Extended-A (08A0–08FF), Presentation Forms A/B (informational only — never used for rendering per D-103), tashkeel subset (064B–065F, 0670), Qur'anic annotation marks (06D6–06ED), Arabic-Indic digits (0660–0669), extended digits (06F0–06F9), Basic Latin. Output `MKCoverageReport` (per-range percentage + booleans `supportsTashkeel`, `supportsQuranicMarks`, `supportsLatin`). Computed once, cached in catalog entry. **AC:** Amiri reports `supportsQuranicMarks == true`; a Latin-only fixture font reports Arabic coverage 0%; report renders in Licensing screen data (T16).

**T11 — Premium catalog manifest schema.** Define `catalog-manifest-v1.json` schema: `{ schemaVersion: 1, generatedAt, fonts: [ { fontID, family, faces: [...], categories, tags, fileURL (HTTPS), fileSHA256, fileSizeBytes, licenseRecord: {inline MKLicenseRecord}, minAppVersion, previewImageURL? } ] }`. Manifest is static JSON on founder-controlled storage (FD-04 placeholder base URL `https://fonts.example-makhtoot.invalid/ MARKED PLACEHOLDER`). Parsing is tolerant of unknown keys (forward compatibility) and hard-fails on missing license records. FD-07 hook: `licenseRecord.licenseType` may be `commercial` with `embeddingRights` narrowed — schema supports it now; v1 manifests must contain only `ofl11`. **AC:** schema documented in packet deliverable `PremiumCatalog.md` section within module docs; decoding tests for valid/malformed/unknown-key manifests; a manifest entry lacking `licenseRecord` is rejected with logged error.

**T12 — Entitlement-gated download pipeline.** `MKFontDownloader` actor: check `MKEntitlementProviding.isPremium` → refuse with `MKFontError.premiumRequired` if not → `URLSession` download task → verify SHA-256 against manifest → move into `ApplicationSupport/Fonts/Premium/<fontID>/` (content-addressed filename = hash) → register `.process` → update catalog entry. Resumable via `URLSessionDownloadTask` resume data; progress via `AsyncStream<Double>`. Pseudocode for the gate:
```
func download(_ id: MKFontID) async throws {
  guard await entitlements.isPremium else { throw .premiumRequired }
  guard let entry = manifest.entry(id) else { throw .unknownFont }
  let tmp = try await session.download(entry.fileURL)
  guard sha256(tmp) == entry.fileSHA256 else { throw .checksumMismatch }
  let dest = store.premiumURL(id, hash: entry.fileSHA256)
  try fm.atomicMove(tmp, dest)
  try registrar.register(dest)          // .process scope
  try await catalog.markDownloaded(id, licenseRecord: entry.licenseRecord)
}
```
**AC:** checksum mismatch deletes temp file and surfaces Arabic error "فشل التحقق من سلامة الخط"; offline attempt surfaces "لا يتوفر اتصال بالإنترنت — الخطوط المميزة تتطلب اتصالًا للتنزيل"; free-tier attempt routes to paywall trigger (callback protocol, UI in WS-10/13).

**T13 — Bundle-fallback build mode (D-121).** Compile-time switch `MKFonts.PremiumDelivery` = `.hosted(manifestURL)` | `.bundledFallback`. In fallback mode premium fonts live in the app bundle under `Resources/PremiumFonts/`, still entitlement-gated at *registration/unlock* time (files present but not registered/usable until premium). Selection is a build setting documented for WS-15. **AC:** both modes compile from same source; fallback mode requires zero network; catalog UI state is identical in both modes except download progress is skipped.

**T14 — User font import (D-122, premium-only).** `MKFontImporter`: input security-scoped URL from Files picker (UI in WS-13). Pipeline: entitlement gate → sfnt validation → content-addressed copy (`Imported/<sha256>.<ext>`) → register → catalog entry `userImported`. sfnt validation (no third-party libs): read first 4 bytes for sfnt version tags `0x00010000` (TrueType), `OTTO` (CFF), `ttcf` (collection); walk table directory; require `cmap`, `glyf` or `CFF `, `name`, `head`; parse `fvar` presence ⇒ isVariable; explicitly reject `wOFF`/`wOF2` magic and files lacking outline tables (bitmap-only). Extract family/PostScript names from `name` table for catalog display. **AC:** fixture tests — valid ttf/otf/ttc/variable accepted; woff/woff2 rejected with error `"صيغة WOFF غير مدعومة — استخدم TTF أو OTF"`; truncated file rejected `"ملف الخط تالف أو غير مكتمل"`; duplicate import (same hash) is idempotent (no duplicate entry).

**T15 — Import legal note + no license fabrication.** Imported fonts get `MKLicenseRecord` with `licenseType = .userProvided` (add enum case), `redistributionConfirmed = false`, and the Licensing screen displays "خط مستورد من المستخدم — التزام الترخيص مسؤولية المستخدم" (user-imported — licensing compliance is the user's responsibility). WS-08 must treat `userProvided` as outline-on-export (no embedding). **AC:** record auto-generated on import; embedding rights bits all false except `rasterOnly`.

**T16 — Licensing data API for Settings→Support→Licensing.** `MKLicensingDataSource`: returns display-ready sections per font — family, foundry/author (from copyright line), license type + full license text (loaded lazily from bundle path), reserved font names, source repo link, commercial-use status, coverage summary (T10), origin badge. Sorted: bundled → premium → imported. This is data only; WS-12 renders it. **AC:** every registered font appears exactly once; license *full text* is byte-identical to captured file; API is synchronous-safe for SwiftUI (async load with placeholder).

**T17 — Expiry locking (D-119).** On entitlement transition to `free`/expired (observed via `MKEntitlementProviding` async sequence): mark all `premiumDownloaded` + `userImported` entries `isLocked = true`; do NOT unregister (existing projects must still *display* via cached shaping per D-119 — re-shaping requests for locked fonts throw `MKFontError.fontLocked`, which WS-03 maps to lock-badge rendering); font picker hides/badges locked fonts; downloads refused. Re-subscribe reverses instantly. **AC:** injected entitlement flip locks/unlocks within one runloop of the notification; locked font cannot be applied to new text (error surfaced); previously placed text still renders (integration test with MKTextEngine cache stub).

**T18 — Deletion & storage management.** Users can delete downloaded premium fonts and imported fonts (frees disk, keeps catalog entry with `notDownloaded`/removed state); imported-font deletion warns if any known project references it (query via MKPersistence project metadata — best-effort, projects are files). **AC:** delete removes file + unregisters; re-download works; warning string in Arabic.

**T19 — Error taxonomy & Arabic messages.** `MKFontError` enum with LocalizedError conformance, every case has an Arabic message: `premiumRequired, unknownFont, checksumMismatch, offline, unsupportedFormat(detected:), corruptFile, fontLocked, registrationFailed(underlying:), licenseRecordMissing`. **AC:** exhaustive switch test; no English-only messages.

**T20 — License-completeness build check.** A small Swift script/test target `FontLicenseAudit` that fails the test suite if: any bundled font file lacks a license dir; any record has `redistributionConfirmed == false` for `bundled` origin; any Reserved Font Name collides with a modified-file name; any file's SHA-256 differs from its verification record. Wire into TEST_MATRIX gate. **AC:** audit passes on clean tree; deliberately corrupting a record fails the audit test.

**T21 — Module docs + FD-07 seam note.** `Sources/MKFonts/MKFonts.docc` or README documenting: architecture, protocol, manifest schema, FD-04 placeholder, FD-07 commercial hooks (fields exist, workflows deferred), and the D-121 fallback election procedure for WS-15. **AC:** doc builds; cross-references ARCHITECTURE.md §17.

**T22 — `MKCatalogManifestFetchService`** (new task, DF-7 — offline/staleness hardening for the T11 premium catalog manifest). Fetches `catalog-manifest-v1.json` in the FOREGROUND only (app active — catalog screen appearance or explicit user-triggered refresh; never a silent background fetch) with a 24-hour staleness TTL: a cached manifest younger than 24h is served with no network round-trip; older than 24h (or absent) triggers a foreground fetch that refreshes the disk cache on success. Disk cache persists across relaunch (e.g. `ApplicationSupport/Fonts/manifest-cache.json`). If the fetch fails while a stale cache exists, serve the stale cache (documented degrade — not the empty state). Zero-manifest-ever empty state: no cache AND fetch fails/offline ⇒ catalog UI receives an explicit empty-catalog state with Arabic copy "لا يمكن تحميل قائمة الخطوط دون اتصال" (the font catalog cannot be loaded without an internet connection) plus a retry affordance — never a blank-looking or crashing catalog screen. **AC:** fresh-cache path makes no network call (instrumented); stale-cache-plus-failed-refetch path serves the stale cache; zero-manifest-ever fixture (clean install + offline) returns the explicit empty state with the exact Arabic copy string; retry re-attempts the fetch and recovers when connectivity returns.

## 6. Compliance & licensing notes

- OFL 1.1 permits bundling/embedding/redistribution with commercial software with attribution + license text preserved and Reserved Font Names respected — market study [^26][^28][^30]; verified so far only for Amiri and Noto Arabic family [^25][^26][^27]; Alif Type repos are candidates pending per-repo verification [^37].
- KFGQPC Uthmanic Script HAFS and similar: proprietary freeware non-commercial EULA; bundling in a paid app is prohibited [^31][^32]. Auto-fail in the protocol.
- Aggregator/mirror font sites are not authoritative license sources [^35].
- Premium delivery: fonts are data, not executable code — direct HTTPS post-entitlement download is the D-121 position; **VERIFY-AT-SUBMISSION** against current App Review Guidelines (no market-study citation exists for a specific clause blessing font downloads; the fallback bundling mode exists precisely for this risk).
- SIL fonts (Scheherazade New, Lateef, Harmattan): expected OFL but **VERIFY-AT-SUBMISSION** via the protocol — no market-study citation covers them.
- No Qur'anic content: preview strings must not include verses (BRIEF Q67–68 override of market study §6).

## 7. Packet acceptance criteria (gates)

1. **Build gate:** `swift build`/`xcodebuild` green in Swift 6 strict mode; zero third-party deps.
2. **License gate:** T20 audit green; `EXCLUDED_FONTS.md` accounts for every D-120 candidate not shipped; spot-check: Amiri OFL.txt byte-identical to `aliftype/amiri` upstream [^28].
3. **Fidelity gate (D-222):** every shipped font's verification record shows a passing T-AR-31/32/33 + T-AR-36..38 result and a recorded GPOS cursive-attachment (type 3) audit finding; a font missing either is not shipped.
4. **Manual Arabic checks (TEST_MATRIX `T-fonts-*`):** T-fonts-01 catalog lists all bundled fonts with Arabic names/categories; T-fonts-02 search behaviors of T8; T-fonts-03 import valid/invalid matrix of T14 on device via Files; T-fonts-04 premium download happy-path + airplane-mode + checksum-tamper; T-fonts-05 expiry lock flow (flip sandbox entitlement, verify lock badges + render-not-reshape); T-fonts-06 Licensing screen shows full OFL text for every bundled font; T-fonts-07 coverage report sanity for Amiri vs Latin-only fixture.
5. **Offline catalog gate (DF-7):** T22 fresh/stale/zero-manifest cache paths all pass, including the exact Arabic empty-state copy.
6. **StoreKit sandbox tie-in:** entitlement-gated download verified against WS-10 sandbox states once merged (blocked-on note allowed at packet close).
7. **Performance:** registration <150 ms (T5); search <5 ms for 200-entry catalog.

## 8. Deliverables

- `MakhtootKit/Sources/MKFonts/**` (registry, downloader, importer, coverage, licensing data source, errors, `MKCatalogManifestFetchService.swift`).
- `Resources/Licenses/<fontID>/…` captured license files + `LicenseRecords/records.json`.
- `Resources/VERIFICATION_PROTOCOL.md`, `EXCLUDED_FONTS.md`, `catalog-seed.json`, `catalog-manifest-v1.json` sample + schema doc.
- `FontLicenseAudit` test target + unit/integration tests for T1–T22.
- Module README/docc incl. FD-04/FD-07 notes.

## 9. References

- FOUNDATION.md §7 (D-120/121/122), §6 D-119, §10 FD-04/FD-07, §2 module map.
- ARCHITECTURE.md: §17 Fonts Subsystem; §16 Export Pipelines (embedding-rights consumer); §23 Security & Privacy.
- PRD.md: §12 Fonts & Catalog; §14 Free/Premium Gating & Paywall; §20 Settings & Licensing; §19 Offline Behavior.
- APP_STORE_CHECKLIST.md: font-license substantiation section; download-vs-bundle election.
- Market study §5 (font licensing matrix), footnotes [^25]–[^37].
- TEST_MATRIX.md `T-fonts-*`.

## 10. Codebase-memory MCP duties

- `manage_adr`: record ADRs — "WS-09-A1: sfnt validation implemented natively (no third-party parser)"; "WS-09-A2: premium delivery mode election (hosted vs bundledFallback) and rationale"; "WS-09-A3: per-font verification outcomes referencing captured commit hashes"; any deviation from the D-120 candidate list.
- Implementation logs: one entry per task T1–T22 with file paths + test names.
- Verification evidence: attach the per-font verification records (repo URL, commit, SHA-256, license quote location) and the T-fonts-01…07 manual check results as evidence entries; log FD-04/FD-07 blockers explicitly.

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| Curated bundled open-license starter fonts (free + premium users) | T1, T3–T5, T7 |
| Downloadable premium catalog, verified redistribution rights, entitlement-gated download, bundle fallback | T11–T13 |
| User font import via Files picker — premium-only (Q64) | T14 |
| Data-model/catalog hooks for future commercial foundry licensing | T2, T11 (FD-07 hook), T21 |
| Formats .ttf/.otf/.ttc/variable; reject unsafe/unsupported with clear errors | T14, T19 |
| Catalog: previews, styles, tags, favorites, search, categories | T6–T9 |
| License/attribution/foundry/commercial-status/character-coverage/source links at Settings → Support → Licensing (Q66) | T10, T16 |
| After premium expiry: premium + imported fonts lock; export falls back | T17 (rest: WS-08 T5) |
| Concrete acquisition/verification process for redistributable fonts; never invent licenses | T3, T4, T20 |
| Market study verified fonts (Amiri/Noto OFL 1.1); KFGQPC prohibited; Alif Type pending verification | T4, §6 |
| Known research gap: per-font OFL verification beyond Amiri/Noto | T3, T4 |
| Offline behavior: font catalog manifest staleness handling + zero-manifest empty state (DF-7) | T22 |
| Per-font Arabic arrange-fidelity gate before a font ships (D-222) | T3 (steps 7–8), T4 |
| No preloaded Qur'anic content (preview strings user-neutral) | T9 |
