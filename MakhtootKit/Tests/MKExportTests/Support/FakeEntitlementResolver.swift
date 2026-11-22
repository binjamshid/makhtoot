import MKFoundation

// WS-08 packet §3: "gating tests use a scripted `FakeEntitlement(state:)` ،
// free AND premium behavior tested before WS-10 lands." D-229(3)'s
// "no non-test/non-composition-root reference" rule is satisfied
// structurally: this type lives ONLY in `Tests/MKExportTests`, never in
// `Sources/MKExport`.
struct FakeEntitlementResolver: MKEntitlementProviding {
    let state: MKEntitlementState

    static let alwaysPremium = FakeEntitlementResolver(state: .lifetime)
    static let alwaysFree = FakeEntitlementResolver(state: .free)
    static let trial = FakeEntitlementResolver(state: .trial(daysLeft: 3))
    static let subscribed = FakeEntitlementResolver(state: .subscribed)
    static let inGracePeriod = FakeEntitlementResolver(state: .inGracePeriod)
    static let inBillingRetry = FakeEntitlementResolver(state: .inBillingRetry)
}
