import Foundation
import Testing
import MKFoundation
@testable import MKStore

/// T5 AC: "precedence test suite covers the REALIZABLE 3-axis matrix
/// (D-228/R2-11-4)... exercised in the realizable combinations only,
/// explicitly including `trial+billingRetry` and `trial+expired-sub`
/// (DF-8), plus `lifetime+expired-sub ⇒ lifetime` and `grace+trial ⇒
/// grace`."
@Suite("MKEntitlementPrecedence ، D-113/T5")
struct MKEntitlementPrecedenceTests {
    private static let activeTrial = MKTrialState.active(daysLeft: 5)
    private static let expiredTrial = MKTrialState.expired

    // MARK: - Axis 1 dominance: lifetime always wins, regardless of the
    // other two axes (10 combinations: 5 subscription signals × 2 trial
    // states, all collapsing to `.lifetime`).

    @Test(
        "lifetime dominates every subscription×trial combination",
        arguments: [
            MKSubscriptionSignal.none,
            .subscribed(renewalInfo: nil),
            .inGracePeriod(until: nil),
            .inBillingRetry,
            .expired,
        ],
        [MKTrialState.active(daysLeft: 3), .expired]
    )
    func lifetimeDominates(subscription: MKSubscriptionSignal, trial: MKTrialState) {
        let (state, detail) = MKEntitlementPrecedence.resolve(hasLifetime: true, subscription: subscription, trial: trial)
        #expect(state == .lifetime)
        #expect(detail.activeProductID == MKStoreIDs.lifetime)
    }

    /// Explicit named case for readability/traceability against the
    /// packet's own "lifetime+expired-sub ⇒ lifetime" phrasing.
    @Test func lifetimePlusExpiredSubscriptionYieldsLifetime() {
        let (state, _) = MKEntitlementPrecedence.resolve(hasLifetime: true, subscription: .expired, trial: Self.expiredTrial)
        #expect(state == .lifetime)
    }

    // MARK: - Axis 2 dominance over axis 3 (grace/billingRetry/subscribed
    // never fall through to check trial ، D-228(4) grace-over-trial
    // rationale, structural not a special case).

    @Test func subscribedWinsOverActiveTrial() {
        let renewal = MKRenewalInfo(willAutoRenew: true, renewalDate: nil, autoRenewProductID: MKStoreIDs.monthly)
        let (state, detail) = MKEntitlementPrecedence.resolve(
            hasLifetime: false,
            subscription: .subscribed(renewalInfo: renewal),
            trial: Self.activeTrial
        )
        #expect(state == .subscribed)
        #expect(detail.renewalInfo == renewal)
    }

    /// "grace+trial ⇒ grace" (DF-8, explicit packet requirement).
    @Test func gracePeriodWinsOverActiveTrial() {
        let until = Date(timeIntervalSince1970: 1_800_000_000)
        let (state, detail) = MKEntitlementPrecedence.resolve(
            hasLifetime: false,
            subscription: .inGracePeriod(until: until),
            trial: Self.activeTrial
        )
        #expect(state == .inGracePeriod)
        #expect(detail.gracePeriodExpiration == until)
    }

    /// "trial+billingRetry ⇒ billingRetry" (DF-8, explicit packet
    /// requirement ، billing retry outranks trial per D-113 even though
    /// billing retry is itself the LOWEST-ranked "premium retained" state).
    @Test func billingRetryWinsOverActiveTrial() {
        let (state, _) = MKEntitlementPrecedence.resolve(hasLifetime: false, subscription: .inBillingRetry, trial: Self.activeTrial)
        #expect(state == .inBillingRetry)
    }

    // MARK: - Axis 3 only matters when axis 2 is none/expired.

    /// "trial+expired-sub ⇒ trial" (DF-8, explicit packet requirement ،
    /// D-228(3): trial is not consumed by purchase, so a lapsed
    /// subscription falls back to an unexpired trial).
    @Test func expiredSubscriptionFallsBackToActiveTrial() {
        let (state, _) = MKEntitlementPrecedence.resolve(hasLifetime: false, subscription: .expired, trial: Self.activeTrial)
        #expect(state == .trial(daysLeft: 5))
    }

    @Test func noSubscriptionFallsBackToActiveTrial() {
        let (state, _) = MKEntitlementPrecedence.resolve(hasLifetime: false, subscription: .none, trial: Self.activeTrial)
        #expect(state == .trial(daysLeft: 5))
    }

    @Test func expiredSubscriptionAndExpiredTrialYieldsFree() {
        let (state, _) = MKEntitlementPrecedence.resolve(hasLifetime: false, subscription: .expired, trial: Self.expiredTrial)
        #expect(state == .free)
    }

    @Test func noSubscriptionAndExpiredTrialYieldsFree() {
        let (state, _) = MKEntitlementPrecedence.resolve(hasLifetime: false, subscription: .none, trial: Self.expiredTrial)
        #expect(state == .free)
    }

    @Test func inBillingRetryIgnoresTrialEvenWhenExpired() {
        let (state, _) = MKEntitlementPrecedence.resolve(hasLifetime: false, subscription: .inBillingRetry, trial: Self.expiredTrial)
        #expect(state == .inBillingRetry)
    }

    // MARK: - Full D-113 rank ordering sanity (existing WS-01 comparator).

    @Test func rankOrderingMatchesD113() {
        #expect(MKEntitlementState.lifetime.outranks(.subscribed))
        #expect(MKEntitlementState.subscribed.outranks(.inGracePeriod))
        #expect(MKEntitlementState.inGracePeriod.outranks(.inBillingRetry))
        #expect(MKEntitlementState.inBillingRetry.outranks(.trial(daysLeft: 1)))
        #expect(MKEntitlementState.trial(daysLeft: 1).outranks(.free))
    }
}
