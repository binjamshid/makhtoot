import CloudKit
import Foundation
import MKFoundation
import MKPersistence
import os

// T3/T5/T6/T7/T8/T9/T10/T11/T12/T14 ، Central sync controller.
// Manages CKSyncEngine lifecycle, upload/download, conflict resolution,
// entitlement gating, and account observation.
//
// ARCHITECTURE NOTE ، Retain cycle prevention:
// CKSyncEngine holds a strong reference to its delegate (AnyObject). The
// controller holds a strong reference to the engine. To break the resulting
// retain cycle, `MKSyncDelegate` (below) holds a WEAK reference to the
// controller; the engine holds a strong reference to MKSyncDelegate only.
//
//   AppContainer ──strong──► MKSyncEngineController
//   MKSyncEngineController ──strong──► CKSyncEngine
//   MKSyncEngineController ──strong──► MKSyncDelegate
//   CKSyncEngine ──strong──► MKSyncDelegate
//   MKSyncDelegate ──weak──► MKSyncEngineController   ← breaks cycle

// MARK: - Delegate shim

/// Breaks the `CKSyncEngine → delegate → engine` retain cycle.
/// `@unchecked Sendable`: the only mutable state is a `weak var` to an actor,
/// which ARC makes safe to access from any thread.
private final class MKSyncDelegate: CKSyncEngineDelegate, @unchecked Sendable {
    weak var controller: MKSyncEngineController?

    init(controller: MKSyncEngineController) {
        self.controller = controller
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await controller?.handleEvent(event, syncEngine: syncEngine)
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        await controller?.nextBatch(syncEngine: syncEngine)
    }
}

// MARK: - Controller

/// Actor-isolated sync controller. Owns the `CKSyncEngine` lifecycle.
///
/// Start conditions (all must hold):
/// 1. The device's persisted project-sync preference is enabled.
/// 2. `entitlementProvider.isEntitled(.cloudSync) == true` (T8)
/// 3. `accountState == .available` (T9)
///
/// Stopping on any lapse retains the engine's state serialization so the
/// next start does not trigger a full re-upload (T3).
public actor MKSyncEngineController {
    // MARK: - Dependencies

    let metadataStore: MetadataStore
    let documentsRootURL: URL
    private let entitlementProvider: any MKEntitlementProviding
    private let preference: MKSyncPreference
    private let accountStatus: @Sendable () async -> MKSyncAccountState
    private let accountIdentity: @Sendable () async -> MKSyncAccountIdentity?
    public let statusPublisher: MKSyncStatusPublisher

    // MARK: - Engine

    private var engine: CKSyncEngine?
    private var engineCancellation: Task<Void, Never>?
    private var activeConsent: UUID?
    private var boundIdentity: MKSyncAccountIdentity?
    private var accountCheckID: UUID?

    public var isEnabled: Bool { preference.isEnabled }

    private var authorizedConsent: UUID? {
        guard entitlementProvider.isEntitled(.cloudSync) else { return nil }
        return preference.enabledRevision
    }

    private func isCurrentEngine(_ candidate: CKSyncEngine) -> Bool {
        guard let activeConsent, authorizedConsent == activeConsent else { return false }
        return engine === candidate
    }

    // MARK: - Queue and coder

    let pendingQueue: MKSyncPendingQueue
    let coder: MKProjectRecordCoder

    // MARK: - Batch temp dirs (S-3)

    /// Tracks each in-flight upload batch's temp directory ، created in
    /// `nextBatch(syncEngine:)`, which packs a full plaintext copy of every
    /// uploaded project's package (scene + assets) into
    /// `tmp/MKSyncBatch-<UUID>/` ، so it can be removed once
    /// `processSentChanges(_:)` confirms CloudKit has consumed the batch.
    /// Keyed by the batch's project-ID set (mirrors `nextBatch`'s own
    /// `entries.map(\.projectID)`) rather than any CKSyncEngine batch
    /// identifier ، `CKSyncEngine` exposes none, and
    /// `CKSyncEngine.SendChangesContext`/`Event.SentRecordZoneChanges` have
    /// no public initializer to synthesize one. `nextRecordZoneChangeBatch`
    /// is invoked serially by CKSyncEngine in practice (one in-flight batch
    /// at a time), but keying by content rather than assuming exactly one
    /// in-flight batch keeps lookups correct even if that assumption ever
    /// changes.
    private var batchTempDirs: [Set<UUID>: URL] = [:]

    // MARK: - Last error (UX-5)

    /// Most recent `MKSyncError` observed by this controller, from either
    /// the global zone-reset path (`.fetchedDatabaseChanges`'s deleted-zone
    /// branch, the only case that reached ANY persisted error surface before
    /// this fix) or a per-project failure (`materialise`, `handleConflict`,
    /// `processSentChanges`'s `failedRecordSaves` loop). Unlike
    /// `statusPublisher.globalState`, which the engine's own event flow
    /// routinely reverts to `.idle`/`.syncing` moments later (CKSyncEngine
    /// fires `.didFetchChanges`/`.didSendChanges` regardless of whether a
    /// per-record failure occurred in the same cycle), this is only ever
    /// SET, never cleared by a subsequent non-error status publish ، so
    /// Settings' "last error" row and the project browser's tappable badge
    /// can both show the specific most-recent failure even after the engine
    /// has otherwise settled back to idle.
    public private(set) var lastError: MKSyncError?

    /// Records `error` as the most recent one this controller has observed.
    /// Not `private`: `CKSyncEngine.SendChangesContext`/
    /// `Event.SentRecordZoneChanges` (and friends) have no public
    /// initializer anywhere in this codebase (mirrors `trackBatchTempDir`/
    /// `cleanupBatchTempDir`'s own precedent below), so the real call sites
    /// that feed this (inside `publishStatus`/`publishProjectStatus`) can't
    /// be exercised end-to-end from a test ، `MKSyncErrorSurfacingTests`
    /// drives this directly instead.
    func recordLastError(_ error: MKSyncError) {
        lastError = error
    }

    // MARK: - Background tasks

    private var changeObserverTask: Task<Void, Never>?
    private var accountObserverTask: Task<Void, Never>?

    // MARK: - Persistence URLs

    private let statePersistenceURL: URL
    private let identityPersistenceURL: URL

    private let logger = MKLog.logger(for: "MKSync")

    // MARK: - Init

    public init(
        metadataStore: MetadataStore,
        documentsRootURL: URL,
        entitlementProvider: any MKEntitlementProviding,
        statusPublisher: MKSyncStatusPublisher,
        applicationSupportURL: URL,
        preference: MKSyncPreference = MKSyncPreference()
    ) {
        self.init(
            metadataStore: metadataStore,
            documentsRootURL: documentsRootURL,
            entitlementProvider: entitlementProvider,
            statusPublisher: statusPublisher,
            applicationSupportURL: applicationSupportURL,
            preference: preference,
            accountStatus: {
                let container = CKContainer(identifier: MKSyncSchema.containerIdentifier)
                guard let status = try? await container.accountStatus() else {
                    return .temporarilyUnavailable
                }
                return MKSyncAccountState.from(status)
            },
            accountIdentity: {
                let container = CKContainer(identifier: MKSyncSchema.containerIdentifier)
                return await Self.fetchCurrentIdentity(container: container)
            }
        )
    }

    init(
        metadataStore: MetadataStore,
        documentsRootURL: URL,
        entitlementProvider: any MKEntitlementProviding,
        statusPublisher: MKSyncStatusPublisher,
        applicationSupportURL: URL,
        preference: MKSyncPreference,
        accountStatus: @escaping @Sendable () async -> MKSyncAccountState,
        accountIdentity: @escaping @Sendable () async -> MKSyncAccountIdentity?
    ) {
        self.metadataStore = metadataStore
        self.documentsRootURL = documentsRootURL
        self.entitlementProvider = entitlementProvider
        self.preference = preference
        self.accountStatus = accountStatus
        self.accountIdentity = accountIdentity
        self.statusPublisher = statusPublisher
        self.pendingQueue = MKSyncPendingQueue()
        self.coder = MKProjectRecordCoder()
        self.statePersistenceURL = applicationSupportURL
            .appendingPathComponent("MKSyncEngineState.json")
        self.identityPersistenceURL = applicationSupportURL
            .appendingPathComponent("MKSyncIdentity.json")
        Self.sweepStaleBatchTempDirs()
    }

    /// S-3 launch-time sweep: `nextBatch(syncEngine:)` writes a full plaintext
    /// copy of every uploaded project's package into
    /// `tmp/MKSyncBatch-<UUID>/`; `trackBatchTempDir(_:for:)`/
    /// `cleanupBatchTempDir(for:)` remove it once `processSentChanges(_:)`
    /// confirms the batch was consumed, but a kill between those two points
    /// leaves a directory behind that iOS only purges `tmp/` opportunistically.
    /// Runs once per controller construction (i.e. once per app launch ،
    /// exactly one `MKSyncEngineController` is constructed per process) and
    /// is `nonisolated`/`static`: it only touches the shared filesystem
    /// `tmp/` directory, never this instance's own in-memory
    /// `batchTempDirs` tracking, which always starts empty for a fresh
    /// process regardless. Any `MKSyncBatch-*` entry found here predates
    /// this call, since it runs before `nextBatch(syncEngine:)` could ever be
    /// invoked in this process ، so an unconditional sweep by name prefix,
    /// with no age check, is safe.
    private static func sweepStaleBatchTempDirs() {
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory
        guard let entries = try? fm.contentsOfDirectory(atPath: tmpDir.path) else { return }
        for name in entries where name.hasPrefix("MKSyncBatch-") {
            try? fm.removeItem(at: tmpDir.appendingPathComponent(name, isDirectory: true))
        }
    }

    // MARK: - Consent, entitlement, and account lifecycle

    /// Reconcile the current values after startup or a preference/entitlement
    /// change. Read the preference here so delayed UI tasks cannot apply a
    /// previous toggle value.
    public func refreshAvailability() async {
        guard let consent = authorizedConsent else {
            stopSync()
            await MainActor.run { [preference, entitlementProvider, statusPublisher] in
                if !preference.isEnabled {
                    statusPublisher.update(globalState: .disabled)
                } else if !entitlementProvider.isEntitled(.cloudSync) {
                    statusPublisher.update(globalState: .pausedEntitlement)
                }
            }
            return
        }
        guard activeConsent != consent else { return }

        stopSync()
        activeConsent = consent
        startObservingAccountChanges(consent: consent)
        await refreshAccountStatus(consent: consent)
    }

    private func stopSync() {
        activeConsent = nil
        accountCheckID = nil
        accountObserverTask?.cancel()
        accountObserverTask = nil
        stopEngine()
    }

    private func stopEngine() {
        changeObserverTask?.cancel()
        changeObserverTask = nil
        guard let engine else { return }

        self.engine = nil
        boundIdentity = nil
        let tempDirectories = Array(batchTempDirs.values)
        batchTempDirs.removeAll()
        // Issue cancellation off the delegate callback. A replacement
        // engine waits for the cancellation request before it starts.
        engineCancellation = Task {
            await engine.cancelOperations()
            for directory in tempDirectories {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        logger.info("MKSync: engine stopped")
    }

    private func refreshAccountStatus(consent: UUID) async {
        guard activeConsent == consent, authorizedConsent == consent, !Task.isCancelled else { return }
        stopEngine()
        let checkID = UUID()
        accountCheckID = checkID

        if let engineCancellation {
            await engineCancellation.value
            guard isCurrentAccountCheck(checkID, consent: consent) else { return }
            self.engineCancellation = nil
        }

        let accountState = await accountStatus()
        guard isCurrentAccountCheck(checkID, consent: consent) else { return }
        guard accountState.allowsSync else {
            publishStatus(.pausedAccount(reason: accountState.pauseReason ?? .temporarilyUnavailable))
            return
        }

        let identity = await accountIdentity()
        guard isCurrentAccountCheck(checkID, consent: consent) else { return }
        guard let identity else {
            publishStatus(.pausedAccount(reason: .temporarilyUnavailable))
            return
        }

        let previousIdentity = loadLastKnownIdentity()
        let unboundCheckpoint = previousIdentity == nil
            && FileManager.default.fileExists(atPath: statePersistenceURL.path)
        do {
            if identity.accountChanged(from: previousIdentity) || unboundCheckpoint {
                await pendingQueue.removeAll()
                guard isCurrentAccountCheck(checkID, consent: consent) else { return }
                try await metadataStore.resetCloudSyncMetadata()
                guard isCurrentAccountCheck(checkID, consent: consent) else { return }
                if FileManager.default.fileExists(atPath: statePersistenceURL.path) {
                    try FileManager.default.removeItem(at: statePersistenceURL)
                }
            }
            try persistIdentity(identity)
        } catch {
            guard isCurrentAccountCheck(checkID, consent: consent) else { return }
            publishStatus(.error(MKSyncErrorMapper.map(error)))
            return
        }

        let container = CKContainer(identifier: MKSyncSchema.containerIdentifier)
        let config = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: loadStateSerialization(),
            delegate: MKSyncDelegate(controller: self)
        )
        guard isCurrentAccountCheck(checkID, consent: consent) else { return }
        let engine = CKSyncEngine(config)
        self.engine = engine
        boundIdentity = identity
        logger.info("MKSync: engine started")
        publishStatus(.idle(lastSyncDate: nil))

        startObservingChanges(syncEngine: engine)
        await enqueueAllPendingFromStore(syncEngine: engine)
    }

    private func isCurrentAccountCheck(_ checkID: UUID, consent: UUID) -> Bool {
        accountCheckID == checkID && activeConsent == consent
            && authorizedConsent == consent && !Task.isCancelled
    }

    // MARK: - CKSyncEngine event handling (T3/T5/T6)

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard isCurrentEngine(syncEngine) else { return }
        switch event {
        case .stateUpdate(let stateUpdate):
            // Persist state on every update so we resume from a checkpoint on relaunch.
            persistStateSerialization(stateUpdate.stateSerialization)

        case .fetchedRecordZoneChanges(let changes):
            await applyFetchedChanges(changes, syncEngine: syncEngine)

        case .sentRecordZoneChanges(let result):
            await processSentChanges(result, syncEngine: syncEngine)

        case .accountChange(let change):
            handleAccountChange(change)

        case .willFetchChanges(_):
            publishStatus(.syncing(uploaded: 0, total: 0))

        case .willFetchRecordZoneChanges(_):
            break  // No action; covered by willFetchChanges above.

        case .didFetchRecordZoneChanges(_):
            break  // Per-zone completion; no action needed.

        case .didFetchChanges(_):
            publishStatus(.idle(lastSyncDate: Date()))
            logger.info("MKSync: fetch completed")

        case .willSendChanges(_):
            let pending = await pendingQueue.count
            guard isCurrentEngine(syncEngine) else { return }
            publishStatus(.syncing(uploaded: 0, total: pending))

        case .didSendChanges(_):
            publishStatus(.idle(lastSyncDate: Date()))
            logger.info("MKSync: send completed")

        case .fetchedDatabaseChanges(let changes):
            // Zone was deleted server-side (e.g. "Reset iCloud") ، re-upload everything.
            for deletion in changes.deletions where deletion.zoneID == MKSyncSchema.zoneID {
                logger.warning("MKSync: sync zone deleted server-side ، re-uploading")
                publishStatus(.error(.zoneNotFound))
                await enqueueAllPendingFromStore(syncEngine: syncEngine)
            }

        case .sentDatabaseChanges(_):
            break  // Zone creation/deletion; no action needed here.

        @unknown default:
            break
        }
    }

    // MARK: - nextRecordZoneChangeBatch (T5 upload path)

    func nextBatch(syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard isCurrentEngine(syncEngine) else { return nil }
        let entries = await pendingQueue.nextBatch()
        guard isCurrentEngine(syncEngine), !entries.isEmpty else { return nil }

        let pending: [CKSyncEngine.PendingRecordZoneChange] = entries.map { entry in
            let recordID = MKSyncSchema.projectRecordID(for: entry.projectID)
            switch entry.kind {
            case .upload: return .saveRecord(recordID)
            case .delete: return .deleteRecord(recordID)
            }
        }

        let batchTempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MKSyncBatch-\(UUID().uuidString)", isDirectory: true)
        trackBatchTempDir(batchTempDir, for: Set(entries.map(\.projectID)))

        let batch = await CKSyncEngine.RecordZoneChangeBatch(
            pendingChanges: pending
        ) { [weak self] recordID in
            await self?.packRecord(recordID, into: batchTempDir, syncEngine: syncEngine)
        }
        guard isCurrentEngine(syncEngine) else { return nil }
        return batch
    }

    private func packRecord(
        _ recordID: CKRecord.ID, into batchTempDir: URL, syncEngine: CKSyncEngine
    ) async -> CKRecord? {
        guard isCurrentEngine(syncEngine), let projectID = UUID(uuidString: recordID.recordName) else {
            return nil
        }
        guard let summary = try? await metadataStore.project(id: projectID),
              isCurrentEngine(syncEngine) else { return nil }
        let packageURL = documentsRootURL
            .appendingPathComponent(summary.packageRelativePath, isDirectory: true)
        let package = DocumentPackage(rootURL: packageURL)
        guard package.exists else {
            logger.warning("MKSync: package missing for \(projectID.uuidString) ، skipping")
            return nil
        }
        let projectTempDir = batchTempDir.appendingPathComponent(projectID.uuidString)
        guard let result = try? coder.pack(
            package: package, projectID: projectID, summary: summary,
            tempDir: projectTempDir),
              isCurrentEngine(syncEngine) else { return nil }
        return result.projectRecord
    }

    // MARK: - Remote change application (T6)

    private func applyFetchedChanges(
        _ changes: CKSyncEngine.Event.FetchedRecordZoneChanges, syncEngine: CKSyncEngine
    ) async {
        for modification in changes.modifications {
            await applyRemoteRecord(modification.record, syncEngine: syncEngine)
        }
        for deletion in changes.deletions {
            await applyRemoteDeletion(recordID: deletion.recordID, syncEngine: syncEngine)
        }
    }

    private func applyRemoteRecord(_ record: CKRecord, syncEngine: CKSyncEngine) async {
        guard isCurrentEngine(syncEngine),
              record.recordType == MKSyncSchema.projectRecordType else { return }
        guard let projectID = UUID(uuidString: record.recordID.recordName) else {
            logger.warning("MKSync: non-UUID record name \(record.recordID.recordName)")
            return
        }

        // T14: Quarantine.
        let remoteSchemaVersion = coder.schemaVersion(from: record)
        if remoteSchemaVersion > MKSyncTunables.supportedSchemaVersion {
            logger.warning("MKSync: quarantining \(projectID.uuidString) ، remoteSchema \(remoteSchemaVersion)")
            publishProjectStatus(projectID, .needsAppUpdate)
            return
        }

        guard let remoteSnapshot = coder.snapshot(from: record) else {
            logger.error("MKSync: record \(projectID.uuidString) missing hash/date")
            return
        }

        let localSummary = try? await metadataStore.project(id: projectID)
        guard isCurrentEngine(syncEngine) else { return }
        let local = localSummary.flatMap { s -> MKSyncSnapshot? in
            guard let tag = s.lastSyncedChangeTag else { return nil }
            return MKSyncSnapshot(contentHash: tag, modifiedAt: s.modifiedAt)
        }
        let lastSynced = local  // same snapshot; local hash IS the last-synced hash

        let decision = MKSyncDecisionEngine.decide(
            local: local, remote: remoteSnapshot, lastSynced: lastSynced,
            remoteSchemaVersion: remoteSchemaVersion
        )

        switch decision {
        case .applyRemote:
            await materialise(record: record, projectID: projectID, syncEngine: syncEngine)
        case .keepLocal:
            await pendingQueue.scheduleUpload(for: projectID)
            publishProjectStatus(projectID, .pendingUpload)
        case .conflict:
            await handleConflict(
                record: record, projectID: projectID, localSummary: localSummary, syncEngine: syncEngine)
        case .noChange:
            publishProjectStatus(projectID, .synced)
        case .quarantine:
            publishProjectStatus(projectID, .needsAppUpdate)
        case .applyRemoteDeletion, .resurrect:
            break  // Only from decideRemoteDeletion; shouldn't reach here.
        }
    }

    private func applyRemoteDeletion(recordID: CKRecord.ID, syncEngine: CKSyncEngine) async {
        guard isCurrentEngine(syncEngine), let projectID = UUID(uuidString: recordID.recordName) else { return }

        let localSummary = try? await metadataStore.project(id: projectID)
        guard isCurrentEngine(syncEngine) else { return }
        let local = localSummary.flatMap { s -> MKSyncSnapshot? in
            guard let tag = s.lastSyncedChangeTag else { return nil }
            return MKSyncSnapshot(contentHash: tag, modifiedAt: s.modifiedAt)
        }
        let lastSynced = local

        let decision = MKSyncDecisionEngine.decideRemoteDeletion(
            local: local, lastSynced: lastSynced)

        switch decision {
        case .applyRemoteDeletion:
            do {
                try await metadataStore.deleteProject(id: projectID)
                // Clear tombstone ، deletion came from server, no upstream delete needed.
                try await metadataStore.clearTombstone(id: projectID)
            } catch {
                logger.error("MKSync: local delete failed for \(projectID.uuidString): \(error)")
            }
        case .resurrect:
            // T6.d resurrection rule: user's local changes win.
            await pendingQueue.scheduleUpload(for: projectID)
            publishProjectStatus(projectID, .pendingUpload)
        default:
            break
        }
    }

    // MARK: - Materialise (T2 write path)

    private func materialise(record: CKRecord, projectID: UUID, syncEngine: CKSyncEngine) async {
        guard isCurrentEngine(syncEngine) else { return }
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MKSync-apply-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        do {
            let result = try coder.unpack(
                projectRecord: record, assetRecords: [], into: tempDir)

            let destRelativePath = "Projects/\(projectID.uuidString).makhtoot"
            let destURL = documentsRootURL
                .appendingPathComponent(destRelativePath, isDirectory: true)

            // Complete local indexing once the installation starts, so an
            // opt-out cannot leave the package and its index out of sync.
            guard isCurrentEngine(syncEngine) else { return }
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: result.package.rootURL, to: destURL)

            if try await metadataStore.project(id: projectID) != nil {
                try await metadataStore.updateSyncState(
                    projectID: projectID, syncState: 1,
                    lastSyncedChangeTag: result.contentHash)
                try await metadataStore.rename(projectID: projectID, to: result.title)
                try await metadataStore.move(projectID: projectID, toFolder: result.folderID)
            } else {
                // Brand-new project from the server: read canvas from manifest.
                let finalPackage = DocumentPackage(rootURL: destURL)
                let manifest = try finalPackage.readManifest()
                _ = try await metadataStore.addProject(
                    projectID: projectID, title: result.title,
                    canvas: manifest.canvas,
                    packageRelativePath: destRelativePath,
                    folderID: result.folderID)
                try await metadataStore.updateSyncState(
                    projectID: projectID, syncState: 1,
                    lastSyncedChangeTag: result.contentHash)
            }

            guard isCurrentEngine(syncEngine) else { return }
            publishProjectStatus(projectID, .synced)
            logger.info("MKSync: applied remote record \(projectID.uuidString)")
        } catch {
            logger.error("MKSync: materialise failed for \(projectID.uuidString): \(error)")
            guard isCurrentEngine(syncEngine) else { return }
            publishProjectStatus(projectID, .error(MKSyncErrorMapper.map(error)))
        }
    }

    // MARK: - Conflict resolution (T7)

    private func handleConflict(
        record: CKRecord,
        projectID: UUID,
        localSummary: MKProjectSummary?,
        syncEngine: CKSyncEngine
    ) async {
        guard isCurrentEngine(syncEngine) else { return }
        guard let localSummary else {
            await materialise(record: record, projectID: projectID, syncEngine: syncEngine)
            return
        }

        logger.info("MKSync: conflict on \(projectID.uuidString) ، creating conflict copy")

        do {
            let allProjects = (try? await metadataStore.listProjects()) ?? []
            guard isCurrentEngine(syncEngine) else { return }
            let existingTitles = Set(allProjects.map(\.title))
            let conflictName = MKConflictNaming.conflictCopyName(
                for: localSummary.title, existingNames: existingTitles)

            let conflictSummary = try await metadataStore.duplicateProject(
                id: projectID, documentsRootURL: documentsRootURL)
            try await metadataStore.rename(
                projectID: conflictSummary.projectID, to: conflictName)

            // Remote wins the original; local divergent copy becomes the conflict copy.
            await materialise(record: record, projectID: projectID, syncEngine: syncEngine)

            guard isCurrentEngine(syncEngine) else { return }
            let copy = conflictSummary.projectID
            let publisher = statusPublisher
            Task { @MainActor in
                publisher.recordConflictCopy(original: projectID, copy: copy)
            }
            logger.info("MKSync: conflict copy '\(conflictName)' created")
        } catch {
            logger.error("MKSync: conflict resolution failed for \(projectID.uuidString): \(error)")
            guard isCurrentEngine(syncEngine) else { return }
            publishProjectStatus(projectID, .error(MKSyncErrorMapper.map(error)))
        }
    }

    // MARK: - Sent changes callback (T5 success handling)

    private func processSentChanges(
        _ result: CKSyncEngine.Event.SentRecordZoneChanges, syncEngine: CKSyncEngine
    ) async {
        for saved in result.savedRecords {
            guard isCurrentEngine(syncEngine) else { return }
            guard let projectID = UUID(uuidString: saved.recordID.recordName),
                  saved.recordType == MKSyncSchema.projectRecordType else { continue }
            await pendingQueue.clear(id: projectID)
            guard isCurrentEngine(syncEngine) else { return }
            let hash = saved[MKSyncSchema.fieldContentHash] as? String
            try? await metadataStore.updateSyncState(
                projectID: projectID, syncState: 1, lastSyncedChangeTag: hash)
            guard isCurrentEngine(syncEngine) else { return }
            publishProjectStatus(projectID, .synced)
        }

        for failure in result.failedRecordSaves {
            guard isCurrentEngine(syncEngine) else { return }
            guard let projectID = UUID(uuidString: failure.record.recordID.recordName),
                  failure.record.recordType == MKSyncSchema.projectRecordType else { continue }
            publishProjectStatus(projectID, .error(MKSyncErrorMapper.map(failure.error)))
            logger.error("MKSync: save failed \(projectID.uuidString): \(failure.error)")
        }

        for deleted in result.deletedRecordIDs {
            guard isCurrentEngine(syncEngine) else { return }
            guard let projectID = UUID(uuidString: deleted.recordName) else { continue }
            await pendingQueue.clear(id: projectID)
            guard isCurrentEngine(syncEngine) else { return }
            try? await metadataStore.clearTombstone(id: projectID)
        }

        // S-3: the batch's temp copy of every uploaded project's package
        // bytes (created in `nextBatch(syncEngine:)`) is no longer needed once
        // CloudKit has reported results for the batch, success or failure ،
        // mirrors the download path's own `defer`-based cleanup in
        // `materialise(record:projectID:)`.
        guard isCurrentEngine(syncEngine) else { return }
        cleanupBatchTempDir(for: projectIDs(in: result))
    }

    /// Every record ID `result` mentions, mapped back to project IDs ،
    /// covers saves (success and failure) and deletes (success and
    /// failure) so a batch's tracked temp dir is found regardless of which
    /// outcome CKSyncEngine reports for its members.
    private func projectIDs(in result: CKSyncEngine.Event.SentRecordZoneChanges) -> Set<UUID> {
        var ids = Set<UUID>()
        for saved in result.savedRecords {
            if let id = UUID(uuidString: saved.recordID.recordName) { ids.insert(id) }
        }
        for failure in result.failedRecordSaves {
            if let id = UUID(uuidString: failure.record.recordID.recordName) { ids.insert(id) }
        }
        for deleted in result.deletedRecordIDs {
            if let id = UUID(uuidString: deleted.recordName) { ids.insert(id) }
        }
        for (recordID, _) in result.failedRecordDeletes {
            if let id = UUID(uuidString: recordID.recordName) { ids.insert(id) }
        }
        return ids
    }

    // MARK: - Batch temp dir tracking (S-3)
    //
    // Factored out of `nextBatch(syncEngine:)`/`processSentChanges(_:)` as
    // small, directly-testable steps: `CKSyncEngine.SendChangesContext` and
    // `CKSyncEngine.Event.SentRecordZoneChanges` are opaque CloudKit types
    // with no public initializer anywhere in this codebase (mirrors
    // `applyRemoteRecord(_:)`'s own doc comment on why it's exposed the same
    // way), so `MKSyncBatchTempCleanupTests` drives these two methods
    // directly with synthesised project-ID sets and real temp directories
    // instead of trying to construct a live batch/event round-trip.

    /// Records that `dir` holds `projectIDs`' packed package bytes for an
    /// in-flight upload batch, so `cleanupBatchTempDir(for:)` can find and
    /// remove it once the batch completes.
    func trackBatchTempDir(_ dir: URL, for projectIDs: Set<UUID>) {
        batchTempDirs[projectIDs] = dir
    }

    /// Removes the temp directory tracked for `projectIDs` (if any) from
    /// disk and stops tracking it. A no-op if no directory is tracked for
    /// that exact project-ID set (e.g. `processSentChanges(_:)` already
    /// cleaned it up, or nothing was ever tracked for it).
    func cleanupBatchTempDir(for projectIDs: Set<UUID>) {
        guard let dir = batchTempDirs.removeValue(forKey: projectIDs) else { return }
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Account observation (T9)

    private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) {
        guard let activeConsent else { return }
        switch change.changeType {
        case .signIn(let current), .switchAccounts(_, let current):
            // A new engine can report the account we just bound to.
            guard current.recordName != boundIdentity?.userRecordName else { return }
        case .signOut:
            break
        @unknown default:
            break
        }

        // Leave CloudKit's delegate callback before awaiting cancellation.
        stopEngine()
        Task { [weak self] in await self?.refreshAccountStatus(consent: activeConsent) }
    }

    private func startObservingAccountChanges(consent: UUID) {
        accountObserverTask = Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: .CKAccountChanged)
            for await _ in notifications {
                guard !Task.isCancelled else { break }
                Task { [weak self] in await self?.refreshAccountStatus(consent: consent) }
            }
        }
    }

    private static func fetchCurrentIdentity(container: CKContainer) async -> MKSyncAccountIdentity? {
        // CKContainer.fetchUserRecordID has no async variant ، bridge via continuation.
        return await withCheckedContinuation { continuation in
            container.fetchUserRecordID { recordID, _ in
                let identity = recordID.map { MKSyncAccountIdentity(userRecordName: $0.recordName) }
                continuation.resume(returning: identity)
            }
        }
    }

    // MARK: - First enable / second device (T12)

    private func enqueueAllPendingFromStore(syncEngine: CKSyncEngine) async {
        guard isCurrentEngine(syncEngine) else { return }
        guard let projects = try? await metadataStore.listProjects() else { return }
        var count = 0
        for project in projects where project.syncState == 0 || project.lastSyncedChangeTag == nil {
            guard isCurrentEngine(syncEngine) else { return }
            await pendingQueue.scheduleUpload(for: project.projectID)
            guard isCurrentEngine(syncEngine) else { return }
            publishProjectStatus(project.projectID, .pendingUpload)
            count += 1
        }
        if let tombstones = try? await metadataStore.tombstones() {
            for id in tombstones {
                guard isCurrentEngine(syncEngine) else { return }
                await pendingQueue.scheduleDelete(for: id)
            }
        }
        if count > 0 { logger.info("MKSync: enqueued \(count) for initial upload") }
    }

    // MARK: - Local change observer (T4)

    private func startObservingChanges(syncEngine: CKSyncEngine) {
        changeObserverTask?.cancel()
        changeObserverTask = Task { [weak self] in
            guard let self else { return }
            let stream = await self.metadataStore.changes
            for await change in stream {
                if Task.isCancelled { break }
                guard await self.isCurrentEngine(syncEngine) else { break }
                await self.handleLocalChange(change)
            }
        }
    }

    func handleLocalChange(_ change: MKProjectChange) async {
        switch change {
        case .created(let summary), .modified(let summary):
            await pendingQueue.scheduleUpload(for: summary.projectID)
            await markDurablyDirtyIfAlreadySynced(summary.projectID)
            publishProjectStatus(summary.projectID, .pendingUpload)
        case .renamed(let id, _):
            await pendingQueue.scheduleUpload(for: id)
            await markDurablyDirtyIfAlreadySynced(id)
            publishProjectStatus(id, .pendingUpload)
        case .deleted(let id):
            // No durable-dirty marker needed here: `MetadataStore.deleteProject`
            // (WS-02/WS-11) already writes a durable `MKTombstoneRecord` for
            // `id` as part of the SAME local delete that produced this
            // `.deleted` change ، `enqueueAllPendingFromStore`'s
            // `metadataStore.tombstones()` scan already survives a kill here
            // with no gap (unlike the upload path below).
            await pendingQueue.scheduleDelete(for: id)
        }
    }

    /// P14 hardening pass (docs/impl-log/WS-07-p14-run3.md, item 4 ، MKSync
    /// pending-queue durability backlog item). Closes a real, previously-
    /// undocumented gap in D1's rebuild rationale (`docs/impl-log/WS-11.md`
    /// §5): `enqueueAllPendingFromStore` only re-enqueues a project on
    /// relaunch when `syncState == 0 || lastSyncedChangeTag == nil` ، true
    /// for a NEVER-synced project (`MKProjectRecord.init`'s own `syncState:
    /// Int = 0` default) and, separately, already handled for deletes via
    /// the durable tombstone registry (see the comment above). But a
    /// project that had ALREADY synced successfully once (`syncState == 1`,
    /// a real `lastSyncedChangeTag`) and is then modified AGAIN only became
    /// "dirty" in the **in-memory** `MKSyncPendingQueue` ، if the process is
    /// killed before that queue's 5 s debounce fires and the upload
    /// completes (`processSentChanges` is the only other writer of
    /// `syncState`), the durable `MKProjectRecord` still reads `syncState ==
    /// 1` with a now-STALE `lastSyncedChangeTag` on the next launch, so the
    /// rebuild scan silently skips it ، a real project edit would never
    /// reach CloudKit at all, with no error surfaced anywhere.
    ///
    /// Fix: durably flip `syncState` back to `0` in the SAME call that
    /// enqueues the in-memory entry, so the two can never diverge across a
    /// kill ، no new SwiftData table needed (the schema-complexity D1
    /// rejected), reusing the field the rebuild scan already reads.
    /// `lastSyncedChangeTag` is deliberately left untouched (not `nil`'d):
    /// it is opaque, only ever compared for presence/absence today, and
    /// clearing it would lose the one piece of state that could later help
    /// diagnose a conflict against the stale server copy.
    private func markDurablyDirtyIfAlreadySynced(_ projectID: UUID) async {
        guard let project = try? await metadataStore.project(id: projectID), project.syncState != 0 else {
            return   // never-synced projects are already durably correct as-is
        }
        try? await metadataStore.updateSyncState(
            projectID: projectID, syncState: 0, lastSyncedChangeTag: project.lastSyncedChangeTag)
    }

    // MARK: - State persistence

    private func loadStateSerialization() -> CKSyncEngine.State.Serialization? {
        guard let data = try? Data(contentsOf: statePersistenceURL) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func persistStateSerialization(_ serialization: CKSyncEngine.State.Serialization) {
        if let data = try? JSONEncoder().encode(serialization) {
            try? data.write(to: statePersistenceURL, options: .atomic)
        }
    }

    private func persistIdentity(_ identity: MKSyncAccountIdentity) throws {
        let data = try JSONEncoder().encode(identity.userRecordName)
        try data.write(to: identityPersistenceURL, options: .atomic)
    }

    private func loadLastKnownIdentity() -> MKSyncAccountIdentity? {
        guard
            let data = try? Data(contentsOf: identityPersistenceURL),
            let name = try? JSONDecoder().decode(String.self, from: data)
        else { return nil }
        return MKSyncAccountIdentity(userRecordName: name)
    }

    // MARK: - Status publish helpers

    private func publishStatus(_ state: MKSyncGlobalState) {
        guard let consent = activeConsent else { return }
        if case .error(let error) = state { recordLastError(error) }
        Task { @MainActor [preference, entitlementProvider, statusPublisher] in
            guard preference.enabledRevision == consent,
                  entitlementProvider.isEntitled(.cloudSync) else { return }
            statusPublisher.update(globalState: state)
        }
    }

    private func publishProjectStatus(_ id: UUID, _ state: MKSyncProjectState) {
        // UX-5: every per-project error (`materialise`, `handleConflict`,
        // `processSentChanges`'s `failedRecordSaves` loop) previously only
        // ever reached the per-project badge, never any persisted/shared
        // error surface ، this is the "beyond .zoneNotFound" extension.
        if case .error(let error) = state { recordLastError(error) }
        let publisher = statusPublisher
        Task { @MainActor in publisher.update(projectID: id, state: state) }
    }

    // MARK: - Diagnostics (tests / instruments)

    public func pendingEntry(for projectID: UUID) async -> MKSyncPendingEntry? {
        await pendingQueue.entry(for: projectID)
    }
}
