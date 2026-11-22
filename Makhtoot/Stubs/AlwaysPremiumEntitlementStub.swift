import MKFoundation

/// The shell's own always-premium entitlement stub (WS-13 packet §3: "Stub:
/// `AlwaysPremiumEntitlementStub` then WS-10's `SandboxScenarioStub`
/// presets"). Deliberately a *distinct* type from `MKFoundation`'s
/// `StubEntitlementResolver` ، that one's own doc comment says "never ship
/// ... in `AppEnvironment.swift`'s production wiring; it exists purely to
/// unblock parallel development and tests."
///
/// **WS-10 T16 update (stub retirement):** the composition root
/// (`AppContainer.init`) now defaults `entitlementProvider` to the real
/// `MKEntitlementResolver` (`MKStore`) instead of this type ، see
/// `AppContainer.swift`'s own stub-matrix table row for the swap record.
/// This type is kept ONLY as a convenience for Debug-configuration
/// previews/manual QA that want a fixed "always premium" seam without
/// pulling `MKStore`'s async product/trial machinery into a SwiftUI
/// `#Preview`; production code (Release or otherwise) must never construct
/// it. `#if DEBUG`-gated per D-229(3) so a Release reference is a build
/// error, not just a lint finding ، `Scripts/stub-source-audit.sh` (WS-10)
/// additionally greps for any accidental non-preview reference.
#if DEBUG
struct AlwaysPremiumEntitlementStub: MKEntitlementProviding {
    var state: MKEntitlementState { .lifetime }
}
#endif
