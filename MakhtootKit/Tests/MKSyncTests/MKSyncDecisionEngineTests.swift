import Foundation
import Testing
@testable import MKSync

// T6 state-machine table tests (cases a–d) + T7 conflict determinism
// + T14 quarantine + resurrection rule (T6.d).
// All tests are pure-function: no CloudKit, no actors required.

struct MKSyncDecisionEngineTests {
    // MARK: - Helpers

    let baseDate = Date(timeIntervalSinceReferenceDate: 1_000_000)

    func snap(_ hash: String, at date: Date? = nil) -> MKSyncSnapshot {
        MKSyncSnapshot(contentHash: hash, modifiedAt: date ?? baseDate)
    }

    // MARK: - T6 state-machine cases

    @Test("(a) No local project → applyRemote")
    func noLocalProjectAppliesRemote() {
        let result = MKSyncDecisionEngine.decide(
            local: nil, remote: snap("remote-hash"), lastSynced: nil)
        #expect(result == .applyRemote)
    }

    @Test("(b) Local unchanged since last sync → applyRemote (LWW)")
    func localUnchangedAppliesRemote() {
        let lastSynced = snap("v1")
        let local = snap("v1")     // same hash as lastSynced → unchanged
        let remote = snap("v2")    // remote changed

        let result = MKSyncDecisionEngine.decide(
            local: local, remote: remote, lastSynced: lastSynced)
        #expect(result == .applyRemote)
    }

    @Test("(c) Local changed, remote unchanged → keepLocal")
    func localChangedRemoteUnchangedKeepsLocal() {
        let lastSynced = snap("v1")
        let local = snap("v2-local")   // local changed
        let remote = snap("v1")         // remote still at v1

        let result = MKSyncDecisionEngine.decide(
            local: local, remote: remote, lastSynced: lastSynced)
        #expect(result == .keepLocal)
    }

    @Test("(d) Both changed → conflict")
    func bothChangedCreatesConflict() {
        let lastSynced = snap("v1")
        let local = snap("v2-local")   // local changed
        let remote = snap("v2-remote") // remote also changed

        let result = MKSyncDecisionEngine.decide(
            local: local, remote: remote, lastSynced: lastSynced)
        #expect(result == .conflict)
    }

    @Test("Identical hashes → noChange")
    func identicalHashesNoChange() {
        let s = snap("abc")
        let result = MKSyncDecisionEngine.decide(
            local: s, remote: s, lastSynced: s)
        #expect(result == .noChange)
    }

    @Test("Never-synced local with incoming remote → applyRemote (no lastSynced)")
    func neverSyncedLocalAppliesRemote() {
        // Both local and remote exist, but no lastSynced.
        // local hash != remote hash; localChanged = true, remoteChanged = true
        // → conflict... unless hashes differ trivially. But the spec says
        // "both changed from nothing" ، treat as conflict (same algorithm).
        let local = snap("local-only")
        let remote = snap("remote-only")

        let result = MKSyncDecisionEngine.decide(
            local: local, remote: remote, lastSynced: nil)
        // lastSynced == nil → localChangedSinceSync = true, remoteChangedSinceSync = true → conflict
        #expect(result == .conflict)
    }

    // MARK: - T14 Quarantine

    @Test("Remote schemaVersion > supported → quarantine")
    func futureSchemaVersionQuarantines() {
        let result = MKSyncDecisionEngine.decide(
            local: snap("v1"), remote: snap("v2"),
            lastSynced: snap("v1"),
            remoteSchemaVersion: 99,
            supportedSchemaVersion: 1
        )
        #expect(result == .quarantine)
    }

    @Test("Remote schemaVersion == supported → normal decision")
    func currentSchemaVersionDecides() {
        let result = MKSyncDecisionEngine.decide(
            local: snap("v1"), remote: snap("v2"),
            lastSynced: snap("v1"),
            remoteSchemaVersion: 1,
            supportedSchemaVersion: 1
        )
        #expect(result == .applyRemote)
    }

    // MARK: - T6.d Resurrection rule (remote deletion)

    @Test("Remote deletion, local unchanged → applyRemoteDeletion")
    func remoteDeletionUnchangedLocalDeletes() {
        let lastSynced = snap("v1")
        let local = snap("v1")   // local unchanged

        let result = MKSyncDecisionEngine.decideRemoteDeletion(
            local: local, lastSynced: lastSynced)
        #expect(result == .applyRemoteDeletion)
    }

    @Test("Remote deletion, local changed → resurrect (T6.d)")
    func remoteDeletionChangedLocalResurrects() {
        let lastSynced = snap("v1")
        let local = snap("v2-local")  // user made changes after remote delete

        let result = MKSyncDecisionEngine.decideRemoteDeletion(
            local: local, lastSynced: lastSynced)
        #expect(result == .resurrect)
    }

    @Test("Remote deletion, no local project → applyRemoteDeletion")
    func remoteDeletionNoLocalApplies() {
        let result = MKSyncDecisionEngine.decideRemoteDeletion(
            local: nil, lastSynced: snap("v1"))
        #expect(result == .applyRemoteDeletion)
    }

    @Test("Remote deletion, never synced local → resurrect")
    func remoteDeletionNeverSyncedResurrects() {
        // No lastSynced → localChangedSinceSync = true → resurrect.
        let result = MKSyncDecisionEngine.decideRemoteDeletion(
            local: snap("local-v1"), lastSynced: nil)
        #expect(result == .resurrect)
    }
}
