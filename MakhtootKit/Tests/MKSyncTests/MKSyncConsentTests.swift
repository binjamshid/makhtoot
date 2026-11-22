import Foundation
import MKFoundation
import MKPersistence
import Testing
@testable import MKSync

@MainActor
@Suite struct MKSyncConsentTests {
    @Test func preferenceDefaultsOffAndPersistsAcrossInstances() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let preference = MKSyncPreference(defaults: defaults)
        #expect(!preference.isEnabled)
        preference.setEnabled(true)
        #expect(MKSyncPreference(defaults: defaults).isEnabled)
        preference.setEnabled(false)
        #expect(!MKSyncPreference(defaults: defaults).isEnabled)
    }

    @Test func accountCheckRequiresBothConsentAndEntitlement() async throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let preference = MKSyncPreference(defaults: defaults)
        let entitlement = TestEntitlement()
        let account = AccountCheck(immediateResult: .noAccount)
        let (controller, root) = try makeController(preference, entitlement, account: account)
        defer { try? FileManager.default.removeItem(at: root) }

        entitlement.allowsSync = true
        await controller.refreshAvailability()
        #expect(await account.callCount == 0)

        entitlement.allowsSync = false
        preference.setEnabled(true)
        await controller.refreshAvailability()
        #expect(await account.callCount == 0)
        #expect(preference.isEnabled)

        entitlement.allowsSync = true
        await controller.refreshAvailability()
        #expect(await account.callCount == 1)
    }

    @Test(arguments: [true, false])
    func delayedAccountCheckCannotContinueAfterAccessIsLost(optOut: Bool) async throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let preference = MKSyncPreference(defaults: defaults)
        let entitlement = TestEntitlement()
        entitlement.allowsSync = true
        let account = AccountCheck()
        let publisher = MKSyncStatusPublisher()
        let (controller, root) = try makeController(
            preference, entitlement, account: account, publisher: publisher)
        defer { try? FileManager.default.removeItem(at: root) }

        preference.setEnabled(true)
        let start = Task { await controller.refreshAvailability() }
        await account.waitUntilCalled()
        if optOut {
            preference.setEnabled(false)
        } else {
            entitlement.allowsSync = false
        }
        await controller.refreshAvailability()

        // A late success must be ignored before fetching an iCloud user ID
        // or creating a CKSyncEngine.
        await account.finish(with: .available)
        await start.value
        #expect(publisher.globalState == (optOut ? .disabled : .pausedEntitlement))
        #expect(preference.isEnabled == !optOut)
        #expect(await account.callCount == 1)
        #expect(await account.identityCallCount == 0)
    }

    @Test func revokingAndGrantingConsentInvalidatesTheOldRevision() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let preference = MKSyncPreference(defaults: defaults)
        preference.setEnabled(true)
        let revision = try #require(preference.enabledRevision)
        preference.setEnabled(false)
        #expect(preference.enabledRevision == nil)
        preference.setEnabled(true)
        #expect(preference.enabledRevision != revision)
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suite = "MKSyncConsentTests-\(UUID())"
        return (try #require(UserDefaults(suiteName: suite)), suite)
    }

    private func makeController(
        _ preference: MKSyncPreference,
        _ entitlement: TestEntitlement,
        account: AccountCheck,
        publisher: MKSyncStatusPublisher = MKSyncStatusPublisher()
    ) throws -> (MKSyncEngineController, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MKSyncConsentTests-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try MetadataStore.makeContainer(at: root.appendingPathComponent("metadata.store"))
        let controller = MKSyncEngineController(
            metadataStore: MetadataStore(modelContainer: store),
            documentsRootURL: root,
            entitlementProvider: entitlement,
            statusPublisher: publisher,
            applicationSupportURL: root,
            preference: preference,
            accountStatus: { await account.read() },
            accountIdentity: { await account.readIdentity() }
        )
        return (controller, root)
    }
}

private final class TestEntitlement: MKEntitlementProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var access = false

    var state: MKEntitlementState { allowsSync ? .lifetime : .free }

    var allowsSync: Bool {
        get { lock.withLock { access } }
        set { lock.withLock { access = newValue } }
    }
}

private actor AccountCheck {
    private(set) var callCount = 0
    private(set) var identityCallCount = 0
    private let immediateResult: MKSyncAccountState?
    private var result: CheckedContinuation<MKSyncAccountState, Never>?
    private var waiter: CheckedContinuation<Void, Never>?

    init(immediateResult: MKSyncAccountState? = nil) {
        self.immediateResult = immediateResult
    }

    func read() async -> MKSyncAccountState {
        callCount += 1
        if let immediateResult { return immediateResult }
        return await withCheckedContinuation { continuation in
            result = continuation
            waiter?.resume()
            waiter = nil
        }
    }

    func readIdentity() -> MKSyncAccountIdentity? {
        identityCallCount += 1
        return nil
    }

    func waitUntilCalled() async {
        guard result == nil else { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func finish(with state: MKSyncAccountState) {
        result?.resume(returning: state)
        result = nil
    }
}
