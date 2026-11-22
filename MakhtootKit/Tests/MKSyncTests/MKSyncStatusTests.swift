import Foundation
import Testing
@testable import MKSync

// T11 ، Sync status contract: state transitions, Arabic strings,
// per-project badge labels, progress is record-count based.

@MainActor
struct MKSyncStatusTests {
    // MARK: - Initial state

    @Test("MKSyncStatusPublisher starts in .disabled")
    func initialStateIsDisabled() {
        let publisher = MKSyncStatusPublisher()
        #expect(publisher.globalState == .disabled)
    }

    @Test("Per-project state defaults to .localOnly for unknown projects")
    func defaultProjectStateIsLocalOnly() {
        let publisher = MKSyncStatusPublisher()
        #expect(publisher.projectState(for: UUID()) == .localOnly)
    }

    // MARK: - State transitions

    @Test("update(globalState:) transitions correctly")
    func globalStateUpdates() {
        let publisher = MKSyncStatusPublisher()

        publisher.update(globalState: .pausedEntitlement)
        #expect(publisher.globalState == .pausedEntitlement)

        publisher.update(globalState: .idle(lastSyncDate: nil))
        #expect(publisher.globalState == .idle(lastSyncDate: nil))

        let date = Date(timeIntervalSinceReferenceDate: 1_000_000)
        publisher.update(globalState: .idle(lastSyncDate: date))
        #expect(publisher.globalState == .idle(lastSyncDate: date))

        publisher.update(globalState: .syncing(uploaded: 2, total: 10))
        #expect(publisher.globalState == .syncing(uploaded: 2, total: 10))

        publisher.update(globalState: .error(.networkUnavailable))
        if case .error(let e) = publisher.globalState {
            #expect(e == .networkUnavailable)
        } else {
            Issue.record("Expected .error")
        }
    }

    @Test("update(projectID:state:) sets per-project state")
    func projectStateUpdates() {
        let publisher = MKSyncStatusPublisher()
        let id = UUID()

        publisher.update(projectID: id, state: .pendingUpload)
        #expect(publisher.projectState(for: id) == .pendingUpload)

        publisher.update(projectID: id, state: .syncing)
        #expect(publisher.projectState(for: id) == .syncing)

        publisher.update(projectID: id, state: .synced)
        #expect(publisher.projectState(for: id) == .synced)
    }

    // MARK: - Conflict copy recording (T7)

    @Test("recordConflictCopy sets copy state to .conflictCopy")
    func conflictCopyRecorded() {
        let publisher = MKSyncStatusPublisher()
        let original = UUID()
        let copy = UUID()

        publisher.recordConflictCopy(original: original, copy: copy)

        #expect(publisher.projectState(for: copy) == .conflictCopy)
        #expect(publisher.recentConflictCopies.count == 1)
        #expect(publisher.recentConflictCopies[0].original == original)
        #expect(publisher.recentConflictCopies[0].copy == copy)
    }

    // MARK: - Arabic badge labels

    @Test("pendingUpload badge is non-empty Arabic")
    func pendingUploadBadge() {
        #expect(MKSyncProjectState.pendingUpload.badgeLabel != nil)
        #expect(!MKSyncProjectState.pendingUpload.badgeLabel!.isEmpty)
    }

    @Test("synced has nil badge (no badge shown when synced)")
    func syncedHasNoBadge() {
        #expect(MKSyncProjectState.synced.badgeLabel == nil)
    }

    @Test("localOnly has nil badge")
    func localOnlyHasNoBadge() {
        #expect(MKSyncProjectState.localOnly.badgeLabel == nil)
    }

    @Test("conflictCopy badge is 'نسخة متعارضة'")
    func conflictCopyBadge() {
        #expect(MKSyncProjectState.conflictCopy.badgeLabel == "نسخة متعارضة")
    }

    @Test("needsAppUpdate has non-empty Arabic badge")
    func needsAppUpdateBadge() {
        #expect(MKSyncProjectState.needsAppUpdate.badgeLabel != nil)
        #expect(!MKSyncProjectState.needsAppUpdate.badgeLabel!.isEmpty)
    }

    // MARK: - Progress is record-count based (T11 ، no fake percentages)

    @Test("Syncing progress values are exact counts, not percentages")
    func syncingProgressValues() {
        let state = MKSyncGlobalState.syncing(uploaded: 3, total: 7)
        if case .syncing(let uploaded, let total) = state {
            #expect(uploaded == 3)
            #expect(total == 7)
            // Must NOT transform to a percentage internally.
            #expect(uploaded <= total)
        } else {
            Issue.record("Not .syncing")
        }
    }

    // MARK: - Pause entitlement message

    @Test("pausedEntitlement message contains 'اشترك'")
    func pausedEntitlementContainsSubscribePrompt() {
        let msg = MKSyncGlobalState.pausedEntitlement.localizedMessage
        #expect(msg.contains("اشترك"))
    }

    // MARK: - Global state messages all non-empty

    @Test("All global state cases have non-empty Arabic messages")
    func allGlobalMessagesNonEmpty() {
        let states: [MKSyncGlobalState] = [
            .disabled,
            .pausedEntitlement,
            .pausedAccount(reason: .noAccount),
            .pausedAccount(reason: .restricted),
            .pausedAccount(reason: .temporarilyUnavailable),
            .idle(lastSyncDate: nil),
            .idle(lastSyncDate: Date()),
            .syncing(uploaded: 1, total: 5),
            .error(.networkUnavailable),
        ]
        for state in states {
            #expect(!state.localizedMessage.isEmpty, "Empty message for \(state)")
        }
    }
}
