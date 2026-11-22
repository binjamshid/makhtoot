import StoreKit

/// Shared JWS-verification helper (T3/T4/T5): every `VerificationResult`
/// this module ever inspects ، purchase results, `Transaction.currentEntitlements`,
/// `Transaction.updates`, `Product.SubscriptionInfo.Status.renewalInfo`/
/// `.transaction` ، goes through this single choke point. Unverified ⇒
/// throw, never silently degrade to "treat as verified" (T3 AC: "no
/// entitlement is ever granted on this path").
func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified:
        throw MKStoreError.failedVerification
    case .verified(let safe):
        return safe
    }
}
