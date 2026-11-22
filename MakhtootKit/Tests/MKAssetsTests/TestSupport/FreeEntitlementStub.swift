import MKFoundation

// WS-14 packet §3: "MKStore (WS-10) via MKEntitlementProviding for premium
// gating. Stub: AlwaysPremiumEntitlementStub, then real; tests must inject
// free to verify gating." `AlwaysPremiumEntitlementStub` lives in
// `Makhtoot/Stubs/` (the APP TARGET, out of this run's fence) ، for tests,
// `MKFoundation.StubEntitlementResolver` already covers the "always
// premium" side (`CONTRACTS.md`: "always `.lifetime`"). This file adds the
// missing "always free" counterpart the packet explicitly requires tests
// inject.
struct FreeEntitlementStub: MKEntitlementProviding {
    var state: MKEntitlementState { .free }
}
