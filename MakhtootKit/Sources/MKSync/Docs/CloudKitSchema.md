# CloudKit Schema — MakhtootKit / MKSync

WS-11 deliverable (T1). This document is the authoritative field reference
for the `MKSync` CloudKit private-database schema. Swift constants live in
`Sources/MKSync/Schema/MKSyncSchema.swift`.

---

## Container

| Item | Value |
|---|---|
| Container ID | `iCloud.net.binjamshid.makhtoot` (FD-01 confirmed) |
| Database | Private (user's own iCloud account) |
| Zone | `MakhtootProjects` |
| Zone owner | `CKCurrentUserDefaultName` (default owner, no custom sharing) |

**Rationale:** A single custom zone enables per-zone change tokens, which
minimise re-fetch bandwidth and allow `CKSyncEngine` to resume from a
checkpoint after a restart (T3). The private database is mandated by D-112
and avoids any "data collection" classification in the App Privacy
questionnaire (T15, `SyncPrivacy.md`).

---

## Record type: `MKProject`

One record per `.makhtoot` project. Record name = project UUID string.

| Field | Type | Description |
|---|---|---|
| `name` | String | Project display title. Mirrors `MKManifest.title`. |
| `folderPath` | String | Folder UUID string, or empty string for the root "no folder" state. Parsed by the receiving device to look up or recreate the folder via `MetadataStore`. |
| `schemaVersion` | Int64 | `MKManifest.schemaVersion`. Forward-compat gate (T14): if `schemaVersion > MKSyncTunables.supportedSchemaVersion` on the receiving device, the record is quarantined — not applied, not overwritten. Currently: `1`. |
| `modifiedAt` | Date | Last content-change timestamp. Used by the LWW algorithm (T6/T7) as the secondary disambiguation key (SHA-256 hash is primary). |
| `contentHash` | String | SHA-256 hex digest of `scene.json` at the time of upload. Primary LWW comparison key; determines whether local and remote have diverged from the last-synced baseline. |
| `manifest` | CKAsset | Encrypted-payload file: serialised `manifest.json` bytes. |
| `scene` | CKAsset | Encrypted-payload file: serialised `scene.json` bytes. |
| `thumbnail` | CKAsset | `thumbnail.png`, optional (absent if no render has been produced). |
| `assetIndex` | CKAsset | JSON array of SHA-256 hashes — one entry per file in `assets/`. Allows the receiver to fetch only the `MKProjectAsset` child records it actually needs without scanning the entire zone. |

**Encryption note:** CloudKit private-database assets are protected by
iCloud end-to-end encryption (Advanced Data Protection, where enabled).
The app itself adds no additional encryption layer (D-112: "encrypted-asset
payloads" refers to CloudKit's own encryption, not app-level crypto).

---

## Record type: `MKProjectAsset`

Child record per content-addressed project asset. Record name =
`"<projectUUID>_<hash>"`.

| Field | Type | Description |
|---|---|---|
| `projectRef` | Reference | Back-reference to the parent `MKProject` record with `.deleteSelf` action — deleting the project cascades to its assets. |
| `hash` | String | SHA-256 hex hash of the asset payload (content-addressed). Matches the hash in `MKProject.assetIndex`. |
| `payload` | CKAsset | Raw asset bytes. |

**Deduplication:** Because asset records are keyed by content hash, two
projects that share the same asset (e.g. the same Arabic ornament SVG)
upload it only once. The receiving device fetches by record name; if the
record already exists locally (same hash, same zone), CloudKit skips the
download.

**Incremental upload:** `MKProjectRecordCoder.pack` creates one
`MKProjectAsset` record per file in `assets/`. Assets not referenced in
`assetIndex` are not fetched on a receiving device, so removed assets are
garbage-collected naturally at the zone level.

---

## LWW (Last-Writer-Wins) algorithm (T6/T7)

Implemented in `MKSyncDecisionEngine` (pure functions, no CloudKit).

```
Inputs:
  local       = MKSyncSnapshot? (contentHash, modifiedAt) of local project
  remote      = MKSyncSnapshot  (from CKRecord fields)
  lastSynced  = MKSyncSnapshot? (stored per-project after each successful sync)
  remoteSchemaVersion  = Int64 (from CKRecord.schemaVersion)

Algorithm:
  if remoteSchemaVersion > supportedSchemaVersion:
    → quarantine (T14)
  if local == nil:
    → (a) applyRemote
  if local.hash == remote.hash:
    → noChange
  localChanged  = (lastSynced == nil) || (local.hash != lastSynced.hash)
  remoteChanged = (lastSynced == nil) || (remote.hash != lastSynced.hash)
  match (localChanged, remoteChanged):
    (false, true)  → (b) applyRemote
    (true, false)  → (c) keepLocal (re-upload)
    (true, true)   → (d) conflict → createConflictCopy; applyRemote over original
    (false, false) → noChange
```

**Conflict copy name:** `"<originalName> (نسخة متعارضة)"`, with Arabic-Indic
numeral suffix (`٢`, `٣`, …) if the base name already exists in the
folder (T7, `MKConflictNaming`).

**Resurrection rule (T6.d):** If a remote DELETE arrives but the local
project has changed since last sync, the local version is re-uploaded as a
new record (user data wins over a deletion). The tombstone for the original
ID is cleared.

---

## Schema versioning (T14)

- Current `supportedSchemaVersion` = `1` (constant in `MKSyncTunables`).
- Future app versions that change the record schema increment this value
  in `MKSyncTunables.supportedSchemaVersion`.
- A device with an older app (lower `supportedSchemaVersion`) receiving a
  record from a newer app quarantines it: `MKSyncProjectState.needsAppUpdate`
  is published for that project.
- The older device never overwrites the remote record with its older-schema
  data (the upload is skipped for quarantined projects).

---

## Privacy audit (T15)

See `Docs/SyncPrivacy.md`. Summary: no analytics fields, no device
identifiers, no third-party SDK. All fields are user-created project data
stored in the user's own private CloudKit database.
