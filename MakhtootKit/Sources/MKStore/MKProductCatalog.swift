import Foundation
import StoreKit

/// A loaded product, projected to the stable UI-facing shape (T2). Never
/// exposes `StoreKit.Product` directly outside `MKStore` ، `MKPurchaseController`
/// resolves the concrete `Product` for a `MKStoreProduct.id` when purchasing.
public struct MKStoreProduct: Identifiable, Equatable, Sendable {
    public let id: String
    /// Apple-storefront-localized display price (e.g. "‏2.99 د.إ.‏" or
    /// "$2.99" depending on storefront) ، no custom currency-code
    /// formatting anywhere in this module (T2 AC).
    public let displayPrice: String
    public let displayName: String
    public let kind: Kind

    public enum Kind: Equatable, Sendable {
        case subscription(period: String)
        case nonConsumable
    }

    public init(id: String, displayPrice: String, displayName: String, kind: Kind) {
        self.id = id
        self.displayPrice = displayPrice
        self.displayName = displayName
        self.kind = kind
    }
}

/// The catalog's externally-observable state (T2 AC: "offline → cached-or-
/// empty with `catalogUnavailable` state").
public enum MKCatalogState: Equatable, Sendable {
    case loading
    case loaded([MKStoreProduct])
    /// No cached products AND the live load failed. Paywall must render
    /// gracefully without prices and show the exact canonical DF-7 string
    /// "يتطلب الاتصال بالإنترنت" (never a paraphrase ، T2 AC).
    case catalogUnavailable
}

/// Loads and caches the three Makhtoot Premium products (T2). An `actor` ،
/// every StoreKit round trip and the in-memory cache are serialized through
/// it, matching the concurrency shape every other WS-10 actor in this
/// module uses (`MKEntitlementResolver`, `MKTrialManager`,
/// `MKPurchaseController`).
public actor MKProductCatalog {
    private var cached: [String: Product] = [:]
    private var lastLoadedProjection: [MKStoreProduct] = []
    private let ids: [String]
    private let maxRetries: Int
    private let baseBackoff: Duration

    public init(
        ids: [String] = MKStoreIDs.all,
        maxRetries: Int = 3,
        baseBackoff: Duration = .milliseconds(200)
    ) {
        self.ids = ids
        self.maxRetries = maxRetries
        self.baseBackoff = baseBackoff
    }

    /// The concrete `Product` StoreKit resolved for `id`, if loaded.
    /// `MKPurchaseController` uses this to call `.purchase()`.
    public func product(for id: String) -> Product? {
        cached[id]
    }

    /// Last successfully loaded projection, even if the most recent
    /// `load()` failed (T2: "offline → cached-or-empty").
    public var cachedProjection: [MKStoreProduct] {
        lastLoadedProjection
    }

    /// Loads (or reloads) the three products, with retry + exponential
    /// backoff on transient failure (T2 AC). Returns the resolved catalog
    /// state; never throws ، StoreKit failures degrade to
    /// `.catalogUnavailable` (if nothing is cached) rather than propagate.
    @discardableResult
    public func load() async -> MKCatalogState {
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                let products = try await Product.products(for: ids)
                for product in products {
                    cached[product.id] = product
                }
                lastLoadedProjection = ids.compactMap { id in
                    cached[id].map(Self.project)
                }
                guard !lastLoadedProjection.isEmpty else {
                    return .catalogUnavailable
                }
                return .loaded(lastLoadedProjection)
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    let backoff = baseBackoff * Int(1 << attempt)
                    try? await Task.sleep(for: backoff)
                }
            }
        }
        _ = lastError
        if !lastLoadedProjection.isEmpty {
            // Offline-but-previously-cached: T2 AC ، render cached
            // products rather than degrading to unavailable.
            return .loaded(lastLoadedProjection)
        }
        return .catalogUnavailable
    }

    private static func project(_ product: Product) -> MKStoreProduct {
        let kind: MKStoreProduct.Kind
        if let subscription = product.subscription {
            kind = .subscription(period: Self.periodDescription(subscription.subscriptionPeriod))
        } else {
            kind = .nonConsumable
        }
        return MKStoreProduct(
            id: product.id,
            displayPrice: product.displayPrice,
            displayName: product.displayName,
            kind: kind
        )
    }

    private static func periodDescription(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day: return period.value == 1 ? "يوم" : "\(period.value) أيام"
        case .week: return period.value == 1 ? "أسبوع" : "\(period.value) أسابيع"
        case .month: return period.value == 1 ? "شهر" : "\(period.value) أشهر"
        case .year: return period.value == 1 ? "سنة" : "\(period.value) سنوات"
        @unknown default: return ""
        }
    }
}
