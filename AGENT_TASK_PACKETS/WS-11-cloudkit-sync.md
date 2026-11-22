# WS-11 — CloudKit Sync (MKSync)

Run-1 agent task packet · Makhtoot (مخطوط) · Target module: `MKSync` (MakhtootKit). Consumes FOUNDATION.md D-112 (sync clause), D-113/D-119 (gating), module map §2.

---

## 1. Mission

Build `MKSync`, the premium-only iCloud project sync layer using `CKSyncEngine` against the user's own iCloud account (container `iCloud.com.example.makhtoot` — placeholder-derived from FD-01). Sync moves whole `.makhtoot` file-package projects (manifest + scene JSON as encrypted-asset payloads, imported assets as CKAssets) between the user's devices with a last-writer-wins-per-project policy and a conflict-copy fallback named with the suffix "(نسخة متعارضة)". There is no custom account system, no Sign in with Apple, and no server: CloudKit is implicitly authenticated by the user's Apple ID, which keeps App Review Guideline 4.8 entirely out of scope (market study §8/§9 recommendation[^56][^57]) and matches the BRIEF's offline-first mandate — the app must remain fully useful with sync off, unavailable, or entitlement-lapsed.

The engineering emphasis is robustness at the edges: account state changes (signed out, iCloud restricted, account switched), quota exhaustion, oversized assets, partial failures, schema evolution, and the interaction between local autosave (WS-02's atomic file-package writes) and engine-driven fetches. `MKSync` must never corrupt a local project: every remote application happens via the same atomic write-temp-and-rename discipline as autosave, and every destructive-looking decision (overwrite vs conflict copy) is deterministic and logged. A small, honest sync-status UI contract (per-project + global states) is exposed for WS-12/WS-13 to render — no fake progress, no silent failures.

## 2. Scope

**IN:**
- `MKSync` target: `MKSyncEngineController` (CKSyncEngine lifecycle, delegate), record mapping for `.makhtoot` packages, change tracking (local mutation journal → pending record zone changes), remote-change application, conflict policy incl. "(نسخة متعارضة)" copies, premium gating (start/stop on entitlement change), account-state observation, quota/error taxonomy with Arabic user messages, sync-status publisher contract, tombstone handling for deletions, backoff/retry policy.
- CloudKit schema definition (record types, fields) + schema-version field and forward-compat rules.
- Migration/first-enable flow: initial upload of existing local projects; initial download on a second device; duplicate-id reconciliation.

**OUT:**
- Rendering of sync status (WS-12 settings toggle + WS-13 browser badges render the published states), StoreKit entitlement logic (WS-10 via `MKEntitlementProviding`), the document format itself (WS-02 owns `.makhtoot`), analytics upload (WS-12 uses CloudKit *public* DB, entirely separate — D-125), share/collaboration (v2 seam), Qur'anic anything (n/a), SIWA (explicitly not used — BRIEF Q77).

## 3. Upstream dependencies, stubs, downstream consumers

**Upstream:**
- `MKPersistence` (WS-02): project store API — enumerate projects, read/write package contents atomically, project metadata (id, name, folder, modifiedAt, contentHash), local mutation notifications (`AsyncStream<MKProjectChange>`), tombstone registry for local deletes. If WS-02's tombstone registry does not yet exist, add it THERE (small PR-sized addition, coordinate via packet note) — do not build a parallel store in MKSync.
- `MKStore` (WS-10) via `MKEntitlementProviding`. **Stub strategy:** develop against `AlwaysPremiumEntitlementStub`; once WS-10 lands (its T16), MKSync automatically gates through the real resolver — this packet must test with `free`, `trial`, `expired` fakes: sync engine stops, uploads cease, downloaded data remains readable (projects are never deleted on downgrade).
- `MKFoundation`: logging, errors, feature flags.
- Entitlements/capabilities: app target needs CloudKit capability + container id (placeholder) — coordinate with WS-13/WS-15.

**Downstream consumers:** WS-12 (Settings: sync toggle, status row, quota error surfacing), WS-13 (project browser per-project badges: `synced`, `syncing`, `pendingUpload`, `conflictCopyCreated`, `error`), WS-15 (submission checklist: CloudKit container provisioning under founder team — FD-01 blocker).

## 4. Locked decisions binding this packet

- **D-112 (sync clause)**: "CloudKit sync (premium): CKSyncEngine; one record per project (manifest+scene as encrypted-asset payloads, assets as CKAssets); last-writer-wins per project with conflict copy fallback ('(نسخة متعارضة)')."
- **D-112 (document model)**: project = `.makhtoot` file package with `manifest.json`, `scene.json`, `assets/` content-addressed, `thumbnail.png` — the sync payload mirrors this structure.
- **D-113/D-119**: premium gating — sync is a premium feature; entitlement lapse stops sync but never destroys local data (BRIEF Q27: projects stay viewable/editable after expiry).
- **D-101**: no third-party dependencies; no Fastlane/CI.
- **D-102**: engines are `Sendable` services on structured concurrency; sync never touches live editor state — it works through MKPersistence's atomic APIs on immutable snapshots.
- FOUNDATION §0: container `iCloud.com.example.makhtoot` (placeholder-derived); glossary conflict-copy naming.
- BRIEF: "Premium/lifetime: iCloud project sync (CloudKit, user's own iCloud, NOT SIWA)"; offline-first; network allowed for premium sync only among the three sanctioned uses.

## 5. Task breakdown (ordered)

**T1 — Schema & record mapping.** Define CloudKit schema doc `Docs/CloudKitSchema.md` + Swift constants: record type `MKProject` in a custom zone `MakhtootProjects` (single zone; per-zone change tokens are how CKSyncEngine scopes work): fields — `name: String`, `folderPath: String`, `schemaVersion: Int64`, `modifiedAt: Date`, `contentHash: String`, `manifest: CKAsset` (encrypted-payload file), `scene: CKAsset`, `thumbnail: CKAsset`, `assetIndex: CKAsset` (JSON list of content-addressed asset hashes), plus `asset_<hash>: CKAsset` fields are NOT used — instead child record type `MKProjectAsset` (`projectRef: CKRecord.Reference`, `hash`, `payload: CKAsset`) so large assets upload/download incrementally and dedupe by hash. Record name = project UUID; asset record name = `"\(projectID)_\(hash)"`. **AC:** schema doc complete with field table + rationale; constants file compiles; mapping covers every element of the D-112 package structure.

**T2 — Serialization to/from record.** `MKProjectRecordCoder`: local package → temp staged files (manifest.json, scene.json copied at a consistent snapshot via MKPersistence read-lock API) → CKAssets; reverse: record + asset records → staged temp package → atomic swap into place. Never partially apply: a fetched project materializes fully in temp before rename. **AC:** round-trip test — package in, record out, package back, byte-identical scene.json + assets; interrupted-apply test (kill mid-stage) leaves original untouched.

**T3 — Engine controller lifecycle.** `MKSyncEngineController` actor: create `CKSyncEngine` with saved state serialization (`CKSyncEngine.State.Serialization` persisted in Application Support), implement delegate (`handleEvent`, `nextRecordZoneChangeBatch`); start only when (a) feature enabled by user toggle, (b) entitlement `isPremium`, (c) account status `.available`. Stop + retain state on any condition failing. **AC:** unit-testable via protocol seam around the engine; start/stop idempotent; state serialization survives relaunch (no re-upload storm).

**T4 — Local change tracking.** Subscribe to MKPersistence `MKProjectChange` stream (created/modified/renamed/moved/deleted). Maintain a durable pending-changes queue (SwiftData table via MKPersistence) mapping projectID → `needsUpload | needsDelete`; debounce rapid autosaves (coalesce to latest, min 5 s quiet period) so typing doesn't thrash uploads. Feed queue into `nextRecordZoneChangeBatch`. **AC:** 10 rapid saves produce 1 upload; queue survives relaunch; delete produces zone record deletion + local tombstone retained until server-confirmed.

**T5 — Upload path.** Build records from coder (T2); attach `contentHash` + `modifiedAt` for LWW; chunk asset child-records in batches respecting CloudKit per-operation limits; on success clear pending flag + store server record metadata (system fields archived per record for future saves). **AC:** new project uploads project record + N asset records; unchanged assets (same hash) are skipped on subsequent uploads (dedupe test).

**T6 — Remote change application.** On fetched changes: compare remote `contentHash`/`modifiedAt` vs local. Cases: (a) no local project → materialize new; (b) local unchanged since last sync (local hash == lastSyncedHash) → apply remote (LWW); (c) local changed AND remote changed (divergence) → conflict path (T7); (d) remote deletion → local delete only if local unchanged since last sync, else keep local and re-upload as new record (resurrection rule — user data wins over deletion). All applies atomic (T2). If the project is currently open in the editor, defer apply and flag `pendingRemoteUpdate` — the editor scene (WS-13) prompts reload on close; never hot-swap under the user. **AC:** state-machine table test covering a/b/c/d; open-project deferral test.

**T7 — Conflict policy + "(نسخة متعارضة)".** Divergence resolution: remote wins the original record (server truth), local divergent copy is preserved as a NEW project: name = `"\(originalName) (نسخة متعارضة)"` (append counter " ٢", " ٣" with Arabic-Indic numerals if the name exists), new UUID, same folder, queued for upload. Deterministic pseudocode:
```
if local.hash != lastSynced.hash && remote.hash != lastSynced.hash && local.hash != remote.hash {
  copy = duplicateLocal(newName: conflictName(local.name))
  queueUpload(copy)
  applyRemote(over: original)      // atomic
  publish(.conflictCopyCreated(original: id, copy: copy.id))
}
```
CKRecord save conflicts (`serverRecordChanged`) resolve by re-fetch + same algorithm. **AC:** two-device simulation test (two engine controllers, mock server or CloudKit dev env) yields exactly one conflict copy, correctly named in Arabic, both projects intact; naming collision appends numerals.

**T8 — Premium gating behavior.** Entitlement stream drives: premium→free: engine stops, pending queue frozen (not cleared), UI state `syncPausedEntitlement` with message "المزامنة عبر iCloud ميزة مميزة — اشترك لاستئنافها"; free→premium: engine restarts, queue drains. Never delete local or remote data on downgrade. **AC:** integration test with entitlement fakes; queue survives a downgrade/upgrade cycle.

**T9 — Account state handling.** Observe `CKContainer.accountStatus()` + `.CKAccountChanged` notification. States: `available` (run), `noAccount` (stop; UI "سجّل الدخول إلى iCloud من الإعدادات لتفعيل المزامنة"), `restricted`/`temporarilyUnavailable` (stop, retry on change). Account *switch* detection: store `userRecordID` hash; if changed, stop, keep local projects (they are the device owner's files), reset sync state serialization + lastSynced hashes, require explicit re-enable (prevents cross-account bleed). **AC:** simulated account switch resets state without data loss; each state maps to a distinct published status.

**T10 — Quota & error taxonomy.** `MKSyncError` with Arabic messages + recovery actions: `quotaExceeded` ("مساحة iCloud ممتلئة — أفرغ مساحة أو عطّل مزامنة المشاريع الكبيرة") mapped from `CKError.quotaExceeded`; `networkUnavailable` (silent retry, passive status); `assetTooLarge` (project exceeds practical asset limits — surface with project name); `zoneNotFound`/`userDeletedZone` (recreate zone, full re-upload path); `serverRejected`, `permissionFailure`, `accountUnavailable`, `throttled(retryAfter)` honoring `CKErrorRetryAfterKey`. Backoff: exponential + jitter, capped 1 h, reset on foreground/network-change. **AC:** each CKError.Code in the mapping table has a test; retryAfter honored; no error loops hot.

**T11 — Sync status UI contract.** `MKSyncStatusPublisher`: global state enum (`disabled, pausedEntitlement, pausedAccount(reason), idle(lastSyncDate), syncing(progress: uploaded/total), error(MKSyncError)`) + per-project states (`localOnly, pendingUpload, syncing, synced, conflictCopy, error`). Exposed as `@Observable` model + `AsyncStream`. No invented percentages: progress = record-count based. **AC:** contract documented for WS-12/WS-13; states transition correctly in an end-to-end fake run; strings reviewed for RTL rendering.

**T12 — First-enable & second-device flows.** Enable: full scan of local projects → queue all → drain with progress; Second device: initial fetch materializes all remote projects into the local store with folders preserved (`folderPath` recreated via MKPersistence folder API). Duplicate UUID both sides (same project pre-sync via e.g. AirDropped package): treat as divergence (T7). **AC:** fresh-install fake-server test materializes N projects with correct folders and thumbnails; re-enable after disable does not duplicate projects.

**T13 — Large-project handling.** Assets over a soft threshold (default 50 MB single asset) sync but publish advisory status; total-project soft cap advisory at 200 MB. Thresholds in `MKSyncTunables` (constants, documented, not feature caps — BRIEF forbids artificial premium caps; these are advisory statuses only, sync still attempts). **AC:** oversized fixture publishes advisory, still uploads; tunables documented.

**T14 — Schema-version forward compatibility.** Records carry `schemaVersion`. If remote `schemaVersion` > local app's supported version: do NOT apply; publish per-project state `needsAppUpdate` ("يتطلب هذا المشروع تحديث التطبيق"); never overwrite the remote with older-schema data (skip upload for that project too). **AC:** fixture with future version is quarantined both directions.

**T15 — Privacy & payload audit.** Verify payloads: private database, user's own container only; no analytics, no identifiers beyond CloudKit's own infrastructure; document in `Docs/SyncPrivacy.md` (feeds APP_STORE_CHECKLIST privacy-nutrition answers: iCloud sync of user content in *private* DB, not "data collection" by the developer — cross-ref market study §9[^56]). **AC:** doc exists; no field in the schema contains device identifiers or analytics.

**T16 — Manual test script.** `Docs/SyncManualTests.md` enumerating the TEST_MATRIX `T-sync-*` device procedures (two physical devices or device+simulator with same Apple ID): create/edit/rename/move/delete propagation, conflict generation recipe (airplane mode both, edit both, reconnect), account sign-out mid-sync, quota simulation guidance, expiry lock behavior. **AC:** script complete and executable by a manual tester without code knowledge.

## 6. Compliance & licensing notes

- No custom account, no third-party login ⇒ Guideline 4.8 (Sign in with Apple) not triggered — market study §8 [^56][^57][^58][^59]; keep it that way: any future login feature re-opens this analysis.
- CloudKit private-DB sync of user content keyed to the user's Apple ID is the compliance-simplest architecture (market study §9 [^56]); privacy nutrition label: user content synced to user's own iCloud — **VERIFY-AT-SUBMISSION** exact App Privacy questionnaire mapping in APP_STORE_CHECKLIST.
- Premium gating of sync is a feature gate, not a data ransom: local data always accessible after expiry (BRIEF Q27) — verified by T8.
- Container id derives from FD-01 bundle id — placeholder until founder supplies; provisioning is a WS-15/FOUNDER step.
- No third-party SDKs (D-101) ⇒ no ATT/tracking implications from this module.

## 7. Packet acceptance criteria (gates)

1. **Build gate:** module + tests green in Swift 6 strict concurrency; no dependency beyond MKPersistence/MKFoundation/CloudKit.
2. **Unit/integration gate:** T2 round-trip, T6 state table, T7 conflict determinism, T9 account switch, T10 error mapping, T14 quarantine — all automated green.
3. **Device gate (TEST_MATRIX `T-sync-*`):** T-sync-01 two-device create/edit propagation <2 min; T-sync-02 conflict recipe yields exactly one "(نسخة متعارضة)" copy, Arabic name renders correctly RTL in browser; T-sync-03 sign-out/sign-in cycle; T-sync-04 entitlement expiry pause + resume; T-sync-05 delete propagation + resurrection rule; T-sync-06 second-device initial download with folders/thumbnails.
4. **Robustness gate:** kill -9 during apply leaves no corrupt package (T2 interrupted-apply evidence).
5. **StoreKit sandbox tie-in:** T8 verified against real WS-10 resolver states once integrated.

## 8. Deliverables

- `MakhtootKit/Sources/MKSync/**` (engine controller, record coder, change tracker, conflict resolver, status publisher, errors, tunables).
- `Docs/CloudKitSchema.md`, `Docs/SyncPrivacy.md`, `Docs/SyncManualTests.md`.
- Automated test suite incl. fake-server harness; two-device manual script.
- MKPersistence tombstone-registry addition (coordinated) if absent.
- Capability/entitlement notes for app target (placeholder container id) for WS-13/WS-15.

## 9. References

- FOUNDATION.md §4 D-112 (sync clause + package format), §8 D-113, §2 module map, §0 container id.
- ARCHITECTURE.md: §20 CloudKit Sync; §13 Persistence & Documents; §14 Undo/Redo & Autosave (interaction rules); §23 Security & Privacy; §24 Extension Seams (sharing/collaboration = v2).
- PRD.md: §17 iCloud Sync; §3 Project Browser & Documents (badges); §15 Trial/Subscription/Lifetime States (gating); §19 Offline Behavior; §21 Edge-Case Compendium.
- APP_STORE_CHECKLIST.md: iCloud capability/provisioning section; App Privacy questionnaire section.
- Market study §8–9, footnotes [^56]–[^59].
- TEST_MATRIX.md `T-sync-*`.

## 10. Codebase-memory MCP duties

- `manage_adr`: "WS-11-A1: single-zone + child asset records design vs per-asset zones"; "WS-11-A2: LWW + conflict-copy algorithm (deterministic rules incl. resurrection)"; "WS-11-A3: account-switch state reset policy"; "WS-11-A4: advisory size thresholds are not feature caps (BRIEF compliance)".
- Implementation logs per task with test names/paths.
- Verification evidence: two-device T-sync-01..06 run notes (device models, iOS versions, timings, screenshots of the Arabic conflict-copy name), error-mapping test output, interrupted-apply proof.

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| Premium/lifetime: iCloud project sync (CloudKit, user's own iCloud, NOT SIWA) | §1 Mission; T1–T16 (whole packet) |
| Fully useful offline; network allowed only for premium iCloud sync (one of three sanctioned uses) | §1 Mission; T8, T9 |
| No mandatory account; SIWA optional only for a future backend, unrelated to iCloud sync (Q77) | §6 compliance notes; T9 |
| Premium/lifetime gating; after expiry projects stay viewable/editable (Q27 pattern applied to sync) | T8 |
| Persistence choice evaluated against CloudKit sync (Q50) | T1, T2 (record mapping mirrors D-112 package) |
| Canvas & projects: `.makhtoot` file-package document model (manifest/scene/assets/thumbnail) | T1, T2 |
| Autosave, no-loss recovery interplay with sync writes | T2 (shared atomic write-temp-rename discipline), T6 (open-project deferral) |
| No artificial premium caps on canvas/project size | T13 (advisory-only large-project thresholds, not caps) |
| Gates (Q59): manual Arabic-script verification checklist | Gate 3, T-sync-02 (Arabic conflict-copy name renders RTL) |
| Codebase-memory MCP conventions: durable ADRs, implementation logs, verification evidence per phase (Q58) | §10 |
| Never invent licenses/facts (extended here to privacy/compliance claims) | §6 compliance notes; T15 |
