# Sync Privacy Audit — MakhtootKit / MKSync

WS-11 deliverable (T15). This document describes what data MKSync transfers,
where it goes, and how it is governed.

---

## What is synced

MKSync uses Apple CloudKit to synchronise `.makhtoot` document packages
between a user's own devices. The following data is uploaded to the user's
**private CloudKit database** only — it is never shared with other users and
is never sent to Albayyan servers.

| Item | Purpose |
|---|---|
| Project title (`name`) | Identifying the project in the project list on secondary devices. |
| Folder path (`folderPath`) | Restoring the project to its correct folder on secondary devices. |
| Project content files (`manifest`, `scene`, `thumbnail`) | Reproducing the complete project document on secondary devices. |
| Asset files (`payload` per `MKProjectAsset`) | Reproducing embedded images and SVG files used in a project. |
| Asset index (`assetIndex`) | Incremental sync: the receiving device fetches only changed assets. |
| Schema version (`schemaVersion`) | Forward-compatibility gate: older app versions quarantine records from newer schema versions rather than silently corrupting data. |
| Content hash (`contentHash`) | Last-Writer-Wins conflict detection: SHA-256 of `scene.json`, used locally — never a fingerprint of the user or device. |
| Modification timestamp (`modifiedAt`) | LWW secondary disambiguation key. |

**What is NOT synced:**

- No device identifiers, IDFA, IDFV, or IP addresses.
- No usage analytics or event logs.
- No authentication tokens or credentials (CloudKit handles identity entirely).
- No cross-user data (private database, no shared zones, no public database).
- No third-party SDK analytics (D-101: no third-party dependencies).

---

## Where the data goes

All sync data is stored in the user's **private CloudKit database** within
the `MakhtootProjects` custom zone. The private database is governed by
Apple's iCloud Terms of Service and is accessible only to the account owner.

When the user enables Apple's **Advanced Data Protection**, CloudKit encrypts
the private database end-to-end on Apple's servers. MKSync does not add a
second encryption layer on top of CloudKit.

Container: `iCloud.net.binjamshid.makhtoot` (FD-01 confirmed; no update needed —
submission).

---

## Premium entitlement gate (T8)

Sync is a Premium feature (`.cloudSync` capability via `MKEntitlementProviding`).
Users who are not subscribed have sync disabled at the
`MKSyncEngineController` level — no CloudKit traffic occurs regardless of
iCloud account status.

---

## Account-switch handling (T9)

When a different iCloud account is detected on relaunch, MKSync:
1. Stops the engine and clears the pending queue.
2. Resets all per-project sync states to `.localOnly` in the SwiftData store.
3. Clears the persisted `CKSyncEngine.State.Serialization` and the stored
   account identity.

This ensures that data from the previous account is never uploaded under the
new account.

---

## Deletion / tombstone lifecycle

Deleted projects are tracked by `MKTombstoneRecord` (SwiftData) until the
server confirms the deletion via a `sentDatabaseChanges` event. Tombstones
contain only the project UUID and a deletion timestamp — no project content.
Tombstones are cleared once the server acknowledges deletion or when a remote
deletion overtakes a local one.

---

## App Privacy questionnaire classification

Based on the above analysis:

| Category | Status |
|---|---|
| Contact Info | Not collected |
| Health & Fitness | Not collected |
| Financial Info | Not collected |
| Location | Not collected |
| Sensitive Info | Not collected |
| Contacts | Not collected |
| User Content | Collected — User-created documents, stored only in user's own iCloud (private database). **Not linked to identity; not used for tracking.** |
| Browsing History | Not collected |
| Search History | Not collected |
| Identifiers | Not collected |
| Purchases | Not collected (entitlement state handled by StoreKit in MKStore, not MKSync) |
| Usage Data | Not collected |
| Diagnostics | Not collected |
| Other Data | Not collected |

**Data linked to identity:** None — all data goes into the user's own
private iCloud database and is not accessible to Albayyan.

**Tracking:** None — no data is used to track users across apps or websites.
