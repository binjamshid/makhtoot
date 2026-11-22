import Foundation
import Testing
@testable import MKStore
#if canImport(StoreKitTest)
import StoreKitTest
#endif

@Suite("MKProductCatalog ، T2", .serialized)
struct MKProductCatalogTests {
    #if canImport(StoreKitTest)
    @Test(.enabled(if: StoreKitConfigLocator.isStoreKitTestSessionAvailable,
                   "StoreKit daemon unavailable outside Xcode test host ، environment-deferred; see WS-10 §4/§12"))
    func loadsAllThreeProductsFromStoreKitConfig() async throws {
        let session = try StoreKitConfigLocator.makeSession()
        defer { session.clearTransactions() }
        let catalog = MKProductCatalog()
        let state = await catalog.load()
        guard case .loaded(let products) = state else {
            Issue.record("expected .loaded, got \(state)")
            return
        }
        #expect(products.count == 3)
        #expect(Set(products.map(\.id)) == Set(MKStoreIDs.all))
        for product in products {
            #expect(!product.displayPrice.isEmpty)
        }
    }

    @Test func offlineWithNoCacheYieldsCatalogUnavailable() async {
        // No SKTestSession started ، `Product.products(for:)` has nothing
        // to resolve against and no prior successful load to fall back on.
        let catalog = MKProductCatalog(maxRetries: 1, baseBackoff: .milliseconds(1))
        let state = await catalog.load()
        #expect(state == .catalogUnavailable)
    }

    @Test func catalogUnavailableStringMatchesCanonicalDF7() {
        // T2 AC: "offline catalog-unavailable state renders exactly
        // 'يتطلب الاتصال بالإنترنت' (not a paraphrase)."
        #expect(MKStoreError.catalogUnavailable.errorDescription == "يتطلب الاتصال بالإنترنت")
    }
    #else
    @Test func storeKitTestUnavailableOnThisPlatform() {
        // Documents the gap rather than silently having zero tests in
        // this suite on a platform without StoreKitTest.
        #expect(Bool(true))
    }
    #endif
}
