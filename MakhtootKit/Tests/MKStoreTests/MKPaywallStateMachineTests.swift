import Foundation
import Testing
@testable import MKStore
#if canImport(StoreKitTest)
import StoreKitTest
#endif

@MainActor
@Suite("MKPaywallStateMachine ، T10", .serialized)
struct MKPaywallStateMachineTests {
    #if canImport(StoreKitTest)
    private func makeMachine(context: MKPaywallContext) async throws -> (SKTestSession, MKPaywallStateMachine) {
        let session = try StoreKitConfigLocator.makeSession()
        let catalog = MKProductCatalog()
        _ = await catalog.load()
        let trialManager = MKTrialManager(local: MKInMemoryKeyValueStore(), cloud: MKInMemoryKeyValueStore(), clock: MKFakeClock())
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("mk-paywall-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let resolver = MKEntitlementResolver(catalog: catalog, trialManager: trialManager, cacheURL: cacheDir.appendingPathComponent("cache.json"))
        let controller = MKPurchaseController(catalog: catalog, resolver: resolver, sheetMarkerStore: MKInMemoryKeyValueStore())
        return (session, MKPaywallStateMachine(context: context, purchaseController: controller))
    }

    @Test func startsInBrowsingState() async throws {
        let (session, machine) = try await makeMachine(context: .settingsUpsell)
        defer { session.clearTransactions() }
        #expect(machine.state == .browsing)
    }

    @Test(.enabled(if: StoreKitConfigLocator.isStoreKitTestSessionAvailable,
                   "StoreKit daemon unavailable outside Xcode test host ، environment-deferred; see WS-10 §4/§12"))
    func purchaseTransitionsThroughPurchasingToSuccess() async throws {
        let (session, machine) = try await makeMachine(context: .premiumFeatureTap(feature: "customCanvas"))
        defer { session.clearTransactions() }
        await machine.purchase(productID: MKStoreIDs.monthly)
        #expect(machine.state == .success)
    }

    @Test(.enabled(if: StoreKitConfigLocator.isStoreKitTestSessionAvailable,
                   "StoreKit daemon unavailable outside Xcode test host ، environment-deferred; see WS-10 §4/§12"))
    func restoreWithNothingToRestoreSurfacesDistinctState() async throws {
        let (session, machine) = try await makeMachine(context: .settingsUpsell)
        defer { session.clearTransactions() }
        await machine.restore()
        #expect(machine.state == .nothingToRestore)
    }

    @Test func dismissAlwaysReachable() async throws {
        let (session, machine) = try await makeMachine(context: .trialExpired)
        defer { session.clearTransactions() }
        machine.dismiss()
        #expect(machine.state == .dismissed)
    }
    #else
    @Test func storeKitTestUnavailableOnThisPlatform() {
        #expect(Bool(true))
    }
    #endif
}
