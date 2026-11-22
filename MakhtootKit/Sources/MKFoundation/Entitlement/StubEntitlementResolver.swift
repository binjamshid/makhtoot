import Foundation

/// Always-premium stub conforming to `MKEntitlementProviding`. This is the
/// WS-01 cross-workstream unblock: WS-03..WS-08 wire this in wherever they
/// need an entitlement source and can build/test premium-gated code paths
/// today. WS-10 replaces this with `MKEntitlementResolver` (real StoreKit 2
/// + `Transaction.currentEntitlements` observation) ، see
/// `MakhtootKit/CONTRACTS.md`.
///
/// Never ship `StubEntitlementResolver` in `AppEnvironment.swift`'s
/// production wiring ، it exists purely to unblock parallel development
/// and tests.
public struct StubEntitlementResolver: MKEntitlementProviding {
    public init() {}

    public var state: MKEntitlementState { .lifetime }
}
