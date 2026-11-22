import Foundation
import MKFoundation

/// Companion detail carried alongside `MKFoundation.MKEntitlementState`
/// (WS-01-shipped, `CONTRACTS.md`-locked shape: `lifetime, subscribed,
/// inGracePeriod, inBillingRetry, trial(daysLeft:), free` ، no associated
/// values on `.subscribed`/`.inGracePeriod`).
///
/// **Deviation note (logged per packet §"stop-and-report on locked-decision
/// conflicts", resolved rather than escalated ، see `docs/impl-log/WS-10.md`
/// "Deviations" section for the full writeup):** T1's pseudocode describes
/// `subscribed(renewalInfo)` / `inGracePeriod(until: Date?)` as associated
/// values directly on the enum. The actually-shipped `MKEntitlementState`
/// (owned by `MKFoundation`, WS-01, already consumed by fenced-off
/// `MKExport`/`MKFonts` sources this packet may not touch) carries no
/// associated values on those cases. Adding them now would be source-
/// breaking for any fenced call site that constructs the bare case (Swift
/// allows *matching* `case .subscribed:` without capturing new associated
/// data, but *constructing* `.subscribed` without an argument would no
/// longer compile). Rather than widen this packet's fence into
/// MKExport/MKFonts to chase every construction site, T9's banner
/// requirement (grace-period "until" date) and T3's renewal-info need are
/// satisfied by this companion struct, published by `MKEntitlementResolver`
/// alongside (not instead of) the plain `MKEntitlementState` the protocol
/// already promises. `MKFoundation.MKEntitlementState` itself is
/// unmodified.
public struct MKEntitlementDetail: Equatable, Sendable {
    /// Present only when the resolved state is `.inGracePeriod`. Apple-side
    /// value from `Product.SubscriptionInfo.RenewalInfo` ، exact grace
    /// durations are **VERIFY-AT-SUBMISSION** (T9), never hardcoded here.
    public var gracePeriodExpiration: Date?

    /// Present only when the resolved state is `.subscribed`. Carries the
    /// renewal date + auto-renew product id so paywall/settings copy can
    /// show "auto-renews on <date>" without re-deriving it.
    public var renewalInfo: MKRenewalInfo?

    /// The product id currently backing `.lifetime`/`.subscribed`/grace/
    /// billing-retry, when known. `nil` for `.trial`/`.free`.
    public var activeProductID: String?

    public init(
        gracePeriodExpiration: Date? = nil,
        renewalInfo: MKRenewalInfo? = nil,
        activeProductID: String? = nil
    ) {
        self.gracePeriodExpiration = gracePeriodExpiration
        self.renewalInfo = renewalInfo
        self.activeProductID = activeProductID
    }

    public static let none = MKEntitlementDetail()
}

/// Minimal renewal-info projection (T1/T3). Deliberately NOT a direct
/// wrapper of `Product.SubscriptionInfo.RenewalInfo` ، that type is not
/// `Sendable`-friendly across all StoreKit SDK versions and carries far
/// more than UI needs; this is the stable, testable surface.
public struct MKRenewalInfo: Equatable, Sendable {
    public var willAutoRenew: Bool
    public var renewalDate: Date?
    public var autoRenewProductID: String?

    public init(willAutoRenew: Bool, renewalDate: Date?, autoRenewProductID: String?) {
        self.willAutoRenew = willAutoRenew
        self.renewalDate = renewalDate
        self.autoRenewProductID = autoRenewProductID
    }
}
