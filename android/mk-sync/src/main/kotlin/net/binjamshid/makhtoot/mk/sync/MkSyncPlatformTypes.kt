package net.binjamshid.makhtoot.mk.sync

// Work item 1.4-repair2. Not one of the 10 Swift source files in the
// MKSync port map — new supporting infrastructure, same category as
// `mk-render/src/main/kotlin/.../MkRenderPlatformTypes.kt`'s
// `MkDrawingSurface`/`MkPlatformImage` placeholders.
//
// MKSync's Swift source is written directly against CloudKit
// (`CKRecord`, `CKRecord.ID`, `CKRecordZone.ID`, `CKAccountStatus`), but
// D-310 replaces CloudKit with Google Drive `appDataFolder` (Drive v3
// REST) on Android entirely — there is no CloudKit SDK on Android and no
// plan to add one (D-304's carve-out is explicit that Drive REST/OkHttp
// is the substitute, not a CloudKit-compatible shim). `:mk-sync`'s
// dependency edges (`ANDROID_SPINE.md` §3.2) are only `:mk-persistence`
// and `:mk-foundation` — no Drive client library is wired into this
// module at Batch 1, so these stay small placeholder classes here,
// following the `mk-render`/`mk-assets` precedent, rather than typed
// against a real Drive REST model class. Batch 6.3a (spine's Drive
// transport agent) owns replacing these with the real Drive-backed types
// (`MKSyncDecisionEngine`'s conflict policy/naming/engine, D-310, is kept
// unchanged — only the transport layer changes).

/**
 * Placeholder for the CloudKit `CKRecord` a project or asset is packed
 * into/unpacked from on iOS. Android's real type (D-310, arriving with
 * Batch 6.3a's `:mk-sync` Drive transport implementation) is expected to
 * wrap a Google Drive v3 REST `File` resource (metadata + `appProperties`).
 */
class MkPlatformSyncRecord internal constructor()

/**
 * Placeholder for the CloudKit `CKRecord.ID` a project/asset record is
 * addressed by on iOS. Android's real type is expected to wrap a Drive
 * file ID string (D-310).
 */
class MkPlatformSyncRecordId internal constructor()

/**
 * Placeholder for the CloudKit `CKRecordZone.ID` `MKSyncSchema`/
 * `MKProjectRecordCoder` address records within on iOS. Drive's
 * `appDataFolder` (D-310) has no per-zone concept the way CloudKit's
 * private database does — Batch 6.3a resolves how (or whether) this
 * placeholder still carries meaning once the real Drive transport lands.
 */
class MkPlatformSyncZoneId internal constructor()

/**
 * Placeholder for `CKAccountStatus`, the CloudKit account-availability
 * enum `MKSyncAccountState.from(_:)` maps on iOS. Android's real type
 * (D-310) is expected to be derived from Credential Manager's identity
 * state plus the GIS `AuthorizationClient`'s `drive.appdata` grant state,
 * not a single SDK enum the way CloudKit provides one.
 */
class MkPlatformSyncAccountStatus internal constructor()
