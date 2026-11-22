import Foundation
import MKFoundation

/// The signal StoreKit's subscription-group status collapses to, before
/// D-113 precedence is applied. Deliberately independent of
/// `Product.SubscriptionInfo.Status` (a live StoreKit type) so the
/// precedence function below has zero StoreKit dependency and is testable
/// with plain values.
public enum MKSubscriptionSignal: Sendable, Equatable {
    case none
    case subscribed(renewalInfo: MKRenewalInfo?)
    case inGracePeriod(until: Date?)
    case inBillingRetry
    case expired
}

/// The pure D-113 precedence function (T5). Given the three REALIZABLE
/// axes ، axis 1: lifetime owned (bool); axis 2: subscription signal
/// (none/subscribed/inGracePeriod/inBillingRetry/expired); axis 3: trial
/// state (active/expired) ، returns the resolved `MKEntitlementState` +
/// `MKEntitlementDetail`. No `StoreKit` import, no `async`: this is the
/// piece T5's AC precedence test suite exercises directly, independent of
/// whatever StoreKit gathering (`MKEntitlementResolver`) feeds it.
///
/// D-113: `lifetime > subscribed > inGracePeriod > inBillingRetry > trial >
/// free`. D-228(4) grace-over-trial rationale is structural here, not a
/// special case: the `subscription` switch never falls through to check
/// `trial` for `.subscribed`/`.inGracePeriod`/`.inBillingRetry` ، only
/// `.none`/`.expired` do. That's exactly "grace+trial ⇒ grace" and
/// "trial+billingRetry ⇒ billingRetry" (DF-8's explicitly-required
/// combinations) for free, by construction rather than by a hand-added
/// exception.
public enum MKEntitlementPrecedence {
    public static func resolve(
        hasLifetime: Bool,
        subscription: MKSubscriptionSignal,
        trial: MKTrialState
    ) -> (state: MKEntitlementState, detail: MKEntitlementDetail) {
        // Axis 1 dominates unconditionally ، "lifetime+expired-sub ⇒
        // lifetime" falls out of checking this first and returning
        // immediately, regardless of what `subscription`/`trial` say.
        if hasLifetime {
            var detail = MKEntitlementDetail()
            detail.activeProductID = MKStoreIDs.lifetime
            return (.lifetime, detail)
        }

        switch subscription {
        case .subscribed(let renewalInfo):
            var detail = MKEntitlementDetail()
            detail.renewalInfo = renewalInfo
            detail.activeProductID = renewalInfo?.autoRenewProductID
            return (.subscribed, detail)

        case .inGracePeriod(let until):
            var detail = MKEntitlementDetail()
            detail.gracePeriodExpiration = until
            return (.inGracePeriod, detail)

        case .inBillingRetry:
            return (.inBillingRetry, .none)

        case .none, .expired:
            // Only here does trial get a vote ، D-228(3): trial is not
            // consumed by purchase, so a lapsed/refunded subscription
            // falls straight back to an unexpired trial if one remains
            // ("trial+expired-sub ⇒ trial", DF-8).
            if case .active(let daysLeft) = trial {
                return (.trial(daysLeft: daysLeft), .none)
            }
            return (.free, .none)
        }
    }
}
