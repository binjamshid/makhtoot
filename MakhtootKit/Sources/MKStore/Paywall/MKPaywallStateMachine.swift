import Foundation
import Observation

/// Why this paywall is showing (T10). Deliberately decoupled from the app
/// target's own `PaywallContext`/`PremiumFeature` enums
/// (`Makhtoot/AppShell/Navigation/MKRoute.swift`, WS-13) ، `MKStore` cannot
/// import the app target, and shouldn't need to: `premiumFeatureTap` here
/// carries a plain feature identifier string, which the app-side call site
/// maps its own `PremiumFeature` case to (e.g. `.customCanvas` →
/// `"customCanvas"`) when constructing this context. Keeps `MKStore`
/// reusable/testable with zero knowledge of the app's route graph.
public enum MKPaywallContext: Sendable, Hashable {
    case onboardingTrialIntro
    case trialExpired
    case premiumFeatureTap(feature: String)
    case settingsUpsell
}

/// T10 state list, plus `nothingToRestore` ، T8 requires a THIRD distinct
/// restore outcome ("restored-premium, nothing-to-restore, failed") beyond
/// the packet's own T10 sketch (`browsing, purchasing, pendingApproval,
/// success, failed, dismissed`), which doesn't have a slot for "restore
/// ran, found nothing, but that isn't an error". Added as its own case
/// rather than overloading `.failed` with a non-error underlying reason.
public enum MKPaywallState: Sendable, Equatable {
    case browsing
    case purchasing(productID: String)
    case pendingApproval
    case success
    case nothingToRestore
    case failed(MKStoreError)
    case dismissed
}

/// The paywall state machine (T10). `@MainActor`/`@Observable` ، this
/// drives SwiftUI directly (WS-13 renders it), so it lives on the main
/// actor rather than as a plain `actor` like the rest of `MKStore`'s
/// engine types; every async call it makes into `MKPurchaseController`
/// (an `actor`) already hops off the main actor for the actual StoreKit
/// work and hops back only to publish the resulting state.
@MainActor
@Observable
public final class MKPaywallStateMachine {
    public let context: MKPaywallContext
    public private(set) var state: MKPaywallState = .browsing
    /// T19/D-228: set when the just-completed purchase was `.lifetime`
    /// while a subscription was active/grace/billingRetry. The view layer
    /// (WS-13/WS-10 `PaywallView`) presents the one-time redundant-
    /// subscription sheet when this is `true` after a `.success`
    /// transition, then should call `acknowledgeRedundantSubscriptionSheet()`
    /// so it doesn't re-trigger from stale state on the next render pass.
    public private(set) var showsRedundantSubscriptionSheet = false
    private let purchaseController: MKPurchaseController

    public init(context: MKPaywallContext, purchaseController: MKPurchaseController) {
        self.context = context
        self.purchaseController = purchaseController
    }

    public func purchase(productID: String) async {
        state = .purchasing(productID: productID)
        let outcome = await purchaseController.purchase(productID: productID)
        switch outcome {
        case .purchased(let showsSheet):
            showsRedundantSubscriptionSheet = showsSheet
            state = .success
        case .pendingApproval:
            state = .pendingApproval
        case .userCancelled:
            state = .browsing
        case .failed(let error):
            state = .failed(error)
        }
    }

    public func acknowledgeRedundantSubscriptionSheet() {
        showsRedundantSubscriptionSheet = false
    }

    /// T8: mandatory restore hook, distinct outcomes.
    public func restore() async {
        let outcome = await purchaseController.restore()
        switch outcome {
        case .restoredPremium:
            state = .success
        case .nothingToRestore:
            state = .nothingToRestore
        case .failed(let error):
            state = .failed(error)
        }
    }

    public func dismiss() {
        state = .dismissed
    }

    /// Resets to `.browsing` ، e.g. re-presenting after a dismissed/failed
    /// paywall for a different feature tap.
    public func reset() {
        state = .browsing
    }
}
