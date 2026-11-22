import Foundation
import Testing
import MKFoundation
@testable import MKStore
#if canImport(StoreKitTest)
import StoreKitTest
#endif

@Suite("MKPurchaseController ، T3/T8/T19", .serialized)
struct MKPurchaseControllerTests {
    #if canImport(StoreKitTest)
    private func makeController() async throws -> (SKTestSession, MKProductCatalog, MKEntitlementResolver, MKPurchaseController) {
        let session = try StoreKitConfigLocator.makeSession()
        let catalog = MKProductCatalog()
        _ = await catalog.load()
        let trialManager = MKTrialManager(
            local: MKInMemoryKeyValueStore(),
            cloud: MKInMemoryKeyValueStore(),
            clock: MKFakeClock()
        )
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("mk-store-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let resolver = MKEntitlementResolver(
            catalog: catalog,
            trialManager: trialManager,
            cacheURL: cacheDir.appendingPathComponent("cache.json")
        )
        let controller = MKPurchaseController(
            catalog: catalog,
            resolver: resolver,
            sheetMarkerStore: MKInMemoryKeyValueStore()
        )
        return (session, catalog, resolver, controller)
    }

    // T-store-01 / T-SK-2..4: purchase each product.
    @Test(
        .enabled(if: StoreKitConfigLocator.isStoreKitTestSessionAvailable,
                 "StoreKit daemon unavailable outside Xcode test host ، environment-deferred; see WS-10 §4/§12"),
        arguments: [MKStoreIDs.monthly, MKStoreIDs.annual, MKStoreIDs.lifetime]
    )
    func purchaseEachProductGrantsExpectedState(productID: String) async throws {
        let (session, _, resolver, controller) = try await makeController()
        defer { session.clearTransactions() }

        let outcome = await controller.purchase(productID: productID)
        guard case .purchased(let showsSheet) = outcome else {
            Issue.record("expected .purchased, got \(outcome)")
            return
        }
        #expect(showsSheet == false) // no prior subscription ، T19 must not fire

        let state = await resolver.resolve()
        switch productID {
        case MKStoreIDs.lifetime:
            #expect(state == .lifetime)
        default:
            #expect(state == .subscribed)
        }
    }

    // T-SK-6/T-store-06/T19: lifetime purchased while subscribed fires
    // the redundant-subscription sheet exactly once.
    @Test(.enabled(if: StoreKitConfigLocator.isStoreKitTestSessionAvailable,
                   "StoreKit daemon unavailable outside Xcode test host ، environment-deferred; see WS-10 §4/§12"))
    func lifetimeWhileSubscribedFiresRedundantSheetOnce() async throws {
        let (session, _, resolver, controller) = try await makeController()
        defer { session.clearTransactions() }

        _ = await controller.purchase(productID: MKStoreIDs.monthly)
        _ = await resolver.resolve()

        let outcome = await controller.purchase(productID: MKStoreIDs.lifetime)
        guard case .purchased(let showsSheet) = outcome else {
            Issue.record("expected .purchased, got \(outcome)")
            return
        }
        #expect(showsSheet)

        let finalState = await resolver.resolve()
        #expect(finalState == .lifetime) // lifetime dominates D-113
    }

    @Test(.enabled(if: StoreKitConfigLocator.isStoreKitTestSessionAvailable,
                   "StoreKit daemon unavailable outside Xcode test host ، environment-deferred; see WS-10 §4/§12"))
    func restoreWithNoPriorPurchasesReturnsNothingToRestore() async throws {
        let (session, _, _, controller) = try await makeController()
        defer { session.clearTransactions() }
        let outcome = await controller.restore()
        #expect(outcome == .nothingToRestore)
    }

    @Test(.enabled(if: StoreKitConfigLocator.isStoreKitTestSessionAvailable,
                   "StoreKit daemon unavailable outside Xcode test host ، environment-deferred; see WS-10 §4/§12"))
    func restoreAfterLifetimePurchaseReturnsRestoredPremium() async throws {
        let (session, _, _, controller) = try await makeController()
        defer { session.clearTransactions() }
        _ = await controller.purchase(productID: MKStoreIDs.lifetime)
        let outcome = await controller.restore()
        #expect(outcome == .restoredPremium)
    }
    #else
    @Test func storeKitTestUnavailableOnThisPlatform() {
        #expect(Bool(true))
    }
    #endif
}
