import Foundation

/// Store error taxonomy (WS-10 T13). Every StoreKit-facing failure surfaced
/// to UI goes through one of these cases ، raw `StoreKitError`/
/// `Product.PurchaseError` values never reach the app layer directly, so
/// paywall/settings copy stays centrally owned and Arabic-localized here.
public enum MKStoreError: Error, LocalizedError, Equatable, Sendable {
    /// A purchase's `VerificationResult` failed Apple's on-device JWS
    /// check (`checkVerified`, T3). No entitlement is ever granted on this
    /// path ، this is the single most safety-critical branch in the
    /// module.
    case failedVerification

    /// `product.purchase()` threw something other than the handled cases
    /// (`.pending`, `.userCancelled` are not errors ، see
    /// `MKPurchaseController`). The underlying error's description is
    /// preserved for logs only, never shown verbatim to the user.
    case purchaseFailed(underlying: String)

    /// `MKProductCatalog` has no cached products and the network round
    /// trip to `Product.products(for:)` failed (offline or App Store
    /// unreachable). Paywall renders the canonical DF-7 string exactly:
    /// "يتطلب الاتصال بالإنترنت".
    case catalogUnavailable

    /// `AppStore.sync()` (restore) failed.
    case restoreFailed(underlying: String)

    /// Ask-to-Buy: the purchase is pending a Family Sharing organizer's
    /// approval. Not a terminal failure ، the paywall shows a distinct
    /// "pending" state, not an error banner, but this case exists so
    /// `MKPurchaseController`'s result type can still be a single
    /// `Result<MKPurchaseOutcome, MKStoreError>` shape where a caller wants
    /// to treat it as a short-circuit. See `MKPurchaseOutcome.pendingApproval`
    /// for the non-error-path surfacing WS-13 should actually bind to.
    case pendingApproval

    /// A `restore()`/`purchase()` call was attempted while the device has
    /// no cached entitlement AND no network ، distinct from
    /// `catalogUnavailable` (that's product *loading*; this is the
    /// operation itself requiring a live connection).
    case networkRequired

    public var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "تعذّر التحقق من عملية الشراء."
        case .purchaseFailed:
            return "تعذّرت عملية الشراء. حاول مرة أخرى."
        case .catalogUnavailable:
            return "يتطلب الاتصال بالإنترنت"
        case .restoreFailed:
            return "تعذّرت استعادة المشتريات. حاول مرة أخرى."
        case .pendingApproval:
            return "بانتظار موافقة العائلة"
        case .networkRequired:
            return "يتطلب الاتصال بالإنترنت"
        }
    }
}
