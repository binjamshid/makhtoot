import Foundation

/// The six entitlement states a user can be in (FOUNDATION §0 glossary),
/// with precedence **lifetime > subscribed > inGracePeriod > inBillingRetry
/// > trial > free** (D-113). Grace period and billing retry both retain
/// premium access (with a banner, owned by WS-10/WS-12 UI); `trial` is the
/// app-side 7-day trial (D-123); `free` is the terminal state with no
/// premium access.
///
/// WS-01 ships only the state's shape and precedence ordering. The real
/// producer ، observing `Transaction.currentEntitlements` +
/// `Product.SubscriptionInfo.Status` ، is WS-10's `MKEntitlementResolver`
/// (see `MakhtootKit/CONTRACTS.md`).
public enum MKEntitlementState: Equatable, Sendable {
    case lifetime
    case subscribed
    case inGracePeriod
    case inBillingRetry
    case trial(daysLeft: Int)
    case free

    /// D-113 precedence rank: lower is higher priority. Two states compare
    /// by this rank regardless of associated values (two `trial` states
    /// compare equal in rank; `daysLeft` is not part of precedence).
    private var precedenceRank: Int {
        switch self {
        case .lifetime: return 0
        case .subscribed: return 1
        case .inGracePeriod: return 2
        case .inBillingRetry: return 3
        case .trial: return 4
        case .free: return 5
        }
    }

    /// Whether `self` outranks `other` per D-113 precedence (strictly
    /// higher priority, i.e. lower rank).
    public func outranks(_ other: MKEntitlementState) -> Bool {
        precedenceRank < other.precedenceRank
    }

    /// The higher-precedence of `lhs`/`rhs` per D-113. Ties (equal rank)
    /// keep `lhs`.
    public static func highestPrecedence(_ lhs: MKEntitlementState, _ rhs: MKEntitlementState) -> MKEntitlementState {
        rhs.outranks(lhs) ? rhs : lhs
    }

    /// Whether this state currently grants premium access. Every state
    /// except `.free` does (grace/billing-retry retain premium per D-113;
    /// trial is full-premium per D-123).
    public var grantsPremiumAccess: Bool {
        if case .free = self { return false }
        return true
    }
}

extension MKEntitlementState: Comparable {
    /// Comparable in precedence order ، `lhs < rhs` means `rhs` outranks
    /// `lhs`. This lets callers `sort()`/`max()` a collection of states by
    /// D-113 precedence directly.
    public static func < (lhs: MKEntitlementState, rhs: MKEntitlementState) -> Bool {
        rhs.outranks(lhs)
    }
}
