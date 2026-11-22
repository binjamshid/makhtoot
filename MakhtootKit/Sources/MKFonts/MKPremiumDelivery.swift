import Foundation

/// T13 ، D-121 delivery-mode election. `.hosted` needs FD-04 (a real
/// static-HTTPS base URL); until the founder resolves FD-04 the documented
/// fallback is `.bundledFallback` ، premium fonts ship inside the app
/// bundle (still entitlement-gated at *unlock* time) and no network call is
/// ever made. Both modes compile from the same source (T13 AC); WS-15
/// documents which one a given build/archive uses.
public enum MKPremiumDelivery: Sendable {
    case hosted(manifestURL: URL)
    case bundledFallback

    /// FD-04 is still open (founder-pending) as of this WS-09 run ، see
    /// `docs/impl-log/WS-09.md`. The placeholder base URL below is
    /// EXPLICITLY marked invalid (`.invalid` TLD is reserved by RFC 2606
    /// for exactly this purpose ، it can never resolve) so a build
    /// misconfigured to `.hosted(.default)` fails loudly (network error)
    /// rather than silently hitting an unintended real host.
    public static let placeholderManifestURL = URL(string: "https://fonts.example-makhtoot.invalid/catalog-manifest-v1.json")!

    /// v1 posture (documented default until FD-04 resolves): bundle
    /// premium fonts in-app behind entitlement. WS-15's archive/build
    /// settings select the actual shipped mode; this is MKFonts' own
    /// compile-time default so `MKFontDownloader`/`MKCatalogManifestFetchService`
    /// have a safe value to construct against in tests and previews.
    public static let current: MKPremiumDelivery = .bundledFallback
}
