import Foundation

/// Compile-time + local-runtime feature flags. Makhtoot is offline-first
/// (BRIEF "Platform"): there is no remote config, no A/B service, no
/// server-driven toggle. A flag's default here is either permanently fixed
/// (compile-time-only seams) or a `UserDefaults`-backed local runtime value
/// a later workstream may expose in Settings.
///
/// `referralProgram` defaults **OFF** per D-124/Q78 and must not be flipped
/// on anywhere in this packet ، activation is FD-05 (founder decision,
/// guideline recheck required) and is owned by WS-10.
public struct MKFeatureFlags: Sendable {
    /// D-124: the referral module (`MKStore/Referral`) is compiled but
    /// inert unless this is `true`. Per D-225 the *shipping* dormancy
    /// mechanism is compile-time exclusion from Release builds, not this
    /// runtime flag alone.
    ///
    /// **Default flipped ON by D-327 (founder, 2026-08-07)**, which granted
    /// FD-05 for iOS and defined `MAKHTOOT_REFERRAL_ENABLED` in Release.
    /// Before D-327 this flag was vestigial ، nothing read it, because no
    /// referral UI existed. `ReferralSection` now reads it, which makes it a
    /// genuine runtime kill switch: setting it back to `false` hides the
    /// feature without a rebuild or a resubmission, useful if App Review
    /// pushes back on the Guideline 3.1.1 surface D-327 accepts.
    ///
    /// Two independent levers, deliberately: this one hides the UI; removing
    /// `MAKHTOOT_REFERRAL_ENABLED` removes the code from the binary entirely
    /// (D-225's original mechanism, still intact).
    public var referralProgram: Bool = true

    /// Supplementary compile/runtime analytics kill switch (D-207 layer 3,
    /// WS-12 T5). When `false`, `MKAnalyticsService` skips all CloudKit
    /// upload operations regardless of local consent state ، a build-time
    /// inertness lever if policy changes at review time. Ships `true`; the
    /// PRIMARY remote kill switch is the CloudKit public-DB `MKAnalyticsConfig`
    /// record (layer 2, D-207/DF-2), not this flag. See T5 for the full
    /// three-layer hierarchy.
    public var analyticsEnabled: Bool = true

    /// v2 extension seam (ARCHITECTURE §24): multi-page canvases. Always
    /// OFF in v1; no workstream in this run activates it.
    public var multiPageSeam: Bool = false

    /// v2 extension seam (D-114): Metal renderer, adopted only if
    /// profiling gates fail against the Core Graphics renderer. Always OFF
    /// in v1.
    public var metalRenderer: Bool = false

    /// MASTER-PLAN P7.5: the alternate app-icon mechanism
    /// (`CFBundleAlternateIcons`, `setAlternateIconName`) is wired and
    /// verified in the built `.app` ، but the bundled artwork in
    /// `Makhtoot/AltIcons/` is placeholder Core Graphics shapes, not
    /// commissioned art. Ships OFF until real artwork lands; this is an
    /// artwork blocker, not an engineering one. Per P7.5: "If icons won't
    /// ship this cycle, don't advertise the option."
    public var alternateAppIcons: Bool = false

    public init() {}

    /// The process-wide default flag set. All call sites should read
    /// through this singleton rather than constructing their own
    /// `MKFeatureFlags()`, so a future Settings-backed override has one
    /// place to plug in.
    public static let `default` = MKFeatureFlags()
}
