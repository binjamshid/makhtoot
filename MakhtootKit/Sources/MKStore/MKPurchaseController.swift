import Foundation
import StoreKit
import MKFoundation

/// Result of `MKPurchaseController.purchase(productID:)` (T3). Deliberately
/// not throwing `MKStoreError` for the two non-error paths (`.pending`,
/// `.userCancelled` per StoreKit's own `Product.PurchaseResult` ، T3 AC
/// "all cases handled").
public enum MKPurchaseOutcome: Sendable, Equatable {
    /// `showsRedundantSubscriptionSheet` is T19/D-228: true only when this
    /// purchase was `.premium.lifetime` AND the resolver's state
    /// immediately before the purchase was `.subscribed`/`.inGracePeriod`/
    /// `.inBillingRetry`, AND the one-time-per-event marker hasn't already
    /// fired for this transaction.
    case purchased(showsRedundantSubscriptionSheet: Bool)
    /// Ask-to-Buy (Family Sharing organizer approval pending). Arabic
    /// surfacing string: "بانتظار موافقة العائلة" (`MKStoreError.pendingApproval`'s
    /// `errorDescription`, reused here for copy consistency even though
    /// this isn't an error path).
    case pendingApproval
    /// Silent ، no banner, no error (T3 AC).
    case userCancelled
    case failed(MKStoreError)
}

public enum MKRestoreOutcome: Sendable, Equatable {
    case restoredPremium
    /// "لا توجد مشتريات سابقة" (T8).
    case nothingToRestore
    case failed(MKStoreError)
}

/// Purchase + restore flows (T3, T8, T19). An `actor`, holding the only
/// mutable state this module needs beyond the resolver/trial actors: the
/// T19 one-time-sheet marker.
public actor MKPurchaseController {
    private let catalog: MKProductCatalog
    private let resolver: MKEntitlementResolver
    private let sheetMarkerStore: any MKKeyValueStoring
    private let sheetMarkerKey = "lifetime.redundantSheet.shownForTransactionID"

    public init(
        catalog: MKProductCatalog,
        resolver: MKEntitlementResolver,
        sheetMarkerStore: any MKKeyValueStoring = MKKeychainStore(service: MKSecureStoreKeys.trialKeychainService)
    ) {
        self.catalog = catalog
        self.resolver = resolver
        self.sheetMarkerStore = sheetMarkerStore
    }

    /// T3 pseudocode, verbatim shape:
    /// ```
    /// switch try await product.purchase() {
    /// case .success(let vr): let txn = try checkVerified(vr); await resolver.refresh(); await txn.finish()
    /// case .pending: state = .pendingApproval
    /// case .userCancelled: break
    /// }
    /// ```
    @discardableResult
    public func purchase(productID: String) async -> MKPurchaseOutcome {
        guard let product = await catalog.product(for: productID) else {
            return .failed(.catalogUnavailable)
        }
        let priorState = resolver.state
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await resolver.resolve()
                await transaction.finish()
                let showsSheet = productID == MKStoreIDs.lifetime
                    && Self.isSubscriptionLike(priorState)
                    && shouldShowRedundantSheet(for: transaction.id)
                return .purchased(showsRedundantSubscriptionSheet: showsSheet)
            case .pending:
                return .pendingApproval
            case .userCancelled:
                return .userCancelled
            @unknown default:
                return .userCancelled
            }
        } catch let error as MKStoreError {
            return .failed(error)
        } catch {
            return .failed(.purchaseFailed(underlying: String(describing: error)))
        }
    }

    private static func isSubscriptionLike(_ state: MKEntitlementState) -> Bool {
        switch state {
        case .subscribed, .inGracePeriod, .inBillingRetry: return true
        case .lifetime, .trial, .free: return false
        }
    }

    /// T19 AC: "fires exactly once per qualifying purchase event (not on
    /// every launch)". Keyed by the lifetime transaction's own StoreKit
    /// `id` rather than a single ever-fired boolean, so a (hypothetical,
    /// StoreKit-disallowed-in-practice-but-not-worth-assuming) repeat
    /// qualifying event would still be distinguishable from the first.
    private func shouldShowRedundantSheet(for transactionID: UInt64) -> Bool {
        let key = String(transactionID)
        if let data = sheetMarkerStore.read(sheetMarkerKey),
           let alreadyShown = String(data: data, encoding: .utf8),
           alreadyShown == key {
            return false
        }
        sheetMarkerStore.write(sheetMarkerKey, value: Data(key.utf8))
        return true
    }

    /// T8: `AppStore.sync()` + re-resolve; mandatory restore UI hook
    /// (D-113/Guideline 3.1.2(c)).
    @discardableResult
    public func restore() async -> MKRestoreOutcome {
        do {
            try await AppStore.sync()
        } catch {
            return .failed(.restoreFailed(underlying: String(describing: error)))
        }
        let newState = await resolver.resolve()
        return Self.isStoreBackedPremium(newState) ? .restoredPremium : .nothingToRestore
    }

    private static func isStoreBackedPremium(_ state: MKEntitlementState) -> Bool {
        switch state {
        case .lifetime, .subscribed, .inGracePeriod, .inBillingRetry: return true
        case .trial, .free: return false
        }
    }
}
