import Foundation

/// The premium capabilities gated by entitlement state. Named to match the
/// export/font/sync gating vocabulary used across FOUNDATION §6–8 (D-118,
/// D-119, D-121) so downstream workstreams (WS-08 export, WS-09 fonts,
/// WS-11 sync) can gate against a single shared enum instead of ad hoc
/// booleans.
public enum MKPremiumCapability: Sendable, CaseIterable {
    case premiumFonts
    case fontImport
    case photoBackgrounds
    case premiumExportFormats
    case hiResExport
    case cloudSync
    case premiumAssets
}

/// The single-source entitlement query surface every other module consumes.
/// WS-01 ships this protocol plus `StubEntitlementResolver` (always
/// `.lifetime`) so WS-03..WS-08 can build and test against a real premium
/// user without waiting on WS-10. WS-10 ships the real
/// `MKEntitlementResolver` conforming to this same protocol ، see
/// `MakhtootKit/CONTRACTS.md` for the replacement plan.
///
/// Conformers must be `Sendable`: entitlement state is read from
/// `Sendable` service contexts (export, sync) as well as `@MainActor` UI
/// (D-102).
public protocol MKEntitlementProviding: Sendable {
    /// The current entitlement state (D-113 precedence already resolved).
    var state: MKEntitlementState { get }

    /// Whether `capability` is currently usable under `state`. Grace
    /// period and billing retry answer `true` for everything (premium
    /// retained with a banner, per D-113); `trial` answers `true` for
    /// everything (full-premium trial, D-123); `free` answers `false` for
    /// every capability.
    func isEntitled(_ capability: MKPremiumCapability) -> Bool
}

public extension MKEntitlementProviding {
    /// Default implementation matching D-113: any non-`.free` state grants
    /// every capability. Conformers only need to override this if a future
    /// tier introduces partial entitlement (none exists in v1 ، FOUNDATION
    /// §8 has a single premium tier).
    func isEntitled(_ capability: MKPremiumCapability) -> Bool {
        state.grantsPremiumAccess
    }
}
