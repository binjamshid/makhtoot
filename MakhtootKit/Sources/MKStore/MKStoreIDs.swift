import Foundation

// FD-01 applied: every id below derives from the confirmed real bundle ID
// `net.binjamshid.makhtoot` (FOUNDATION.md §0, FD-01 founder-confirmed).
// The `Makhtoot.storekit` config file mirrors these values.

/// Product/subscription-group identifiers for the three Makhtoot Premium
/// products (BRIEF pricing, D-216 tier mapping): monthly $2.99, annual
/// $29.99, lifetime (non-consumable) $89.99.
public enum MKStoreIDs {
    /// Auto-renewable subscription, monthly tier, $2.99/mo intent.
    public static let monthly = "net.binjamshid.makhtoot.premium.monthly"

    /// Auto-renewable subscription, annual tier, $29.99/yr intent.
    public static let annual = "net.binjamshid.makhtoot.premium.annual"

    /// Non-consumable, one-time purchase, $89.99 intent. Grants permanent
    /// premium regardless of subscription state (D-113 precedence: highest
    /// rank).
    public static let lifetime = "net.binjamshid.makhtoot.premium.lifetime"

    /// The App Store Connect subscription group both auto-renewables share
    /// (FOUNDATION §0). Required so `Product.SubscriptionInfo.Status`
    /// resolves upgrade/crossgrade/highest-status semantics across the two
    /// tiers as one group, not two independent products.
    public static let subscriptionGroup = "Makhtoot Premium"

    /// All three product ids, in the order the paywall should render them
    /// (monthly, annual, lifetime ، cheapest recurring commitment first,
    /// lifetime last as the "buy once" anchor).
    public static let all: [String] = [monthly, annual, lifetime]

    /// The two auto-renewable ids (subset of `all`), used wherever code
    /// needs "subscriptions only" (e.g. `Product.SubscriptionInfo.Status`
    /// lookups, which non-consumables don't have).
    public static let subscriptions: [String] = [monthly, annual]
}
