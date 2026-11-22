import MKFoundation
import MKStore

/// The shell's route model (WS-13 packet §5 T3): `browser, editor(projectID),
/// settings, paywall(context), onboarding` ، exactly the five routes the
/// packet names. `Identifiable` (via `Self` as `id`) so routes can drive
/// `.sheet(item:)`/`.fullScreenCover(item:)` directly.
enum MKRoute: Hashable, Sendable, Identifiable {
    case browser
    case editor(MKProjectID)
    case settings
    case paywall(PaywallContext)
    case onboarding

    var id: Self { self }
}

/// Where a paywall presentation originated ، every context renders the same
/// one paywall implementation (WS-13 packet §5 T10: "One implementation
/// reused for all contexts"), but the origin matters for dismissibility
/// rules and analytics (later slice; not implemented yet).
enum PaywallContext: Hashable, Sendable {
    case onboardingTrialIntro
    case premiumFeatureTap(PremiumFeature)
    case settingsUpgrade
}

/// The premium features whose free-tier tap routes to the paywall
/// (WS-13 packet §5 T8's "أبعاد مخصصة" custom-canvas gate is the first
/// concrete consumer; the rest are named now so `PaywallContext` doesn't
/// need a breaking change when the editor slice adds more tap points).
enum PremiumFeature: Hashable, Sendable, CaseIterable {
    case customCanvas
    case premiumFont
    case photoBackground
    case cloudSync
    case exportFormat
    /// WS-14's asset-browser premium tap (`MKAssetBrowserModel.select(_:)`'s
    /// `.premiumRequired(capability: .premiumAssets, ...)` outcome) ، see
    /// `MKAssetBrowserModel.swift`'s file header for the one-line
    /// coordination note this fulfills, and the editor's asset-browser
    /// panel call site for the matching `nav.presentPaywall(...)` wiring.
    case premiumAsset

    /// Feature identifier for `MKStore.MKPaywallContext.premiumFeatureTap`
    /// (WS-10 T10 ، that type is intentionally decoupled from this app-side
    /// enum, see its own header comment; this is the one mapping point).
    var storeFeatureIdentifier: String {
        switch self {
        case .customCanvas: return "customCanvas"
        case .premiumFont: return "premiumFont"
        case .photoBackground: return "photoBackground"
        case .cloudSync: return "cloudSync"
        case .exportFormat: return "exportFormat"
        case .premiumAsset: return "premiumAsset"
        }
    }
}

extension PaywallContext {
    /// Maps this app-side context to `MKStore`'s decoupled
    /// `MKPaywallContext` (WS-10 T10). `.trialExpired` (an `MKStore`
    /// context with no app-side origin yet ، no call site fabricates a
    /// "trial just expired" route today, WS-13 didn't wire one) simply has
    /// no case here to map FROM; it isn't needed until a future slice adds
    /// that route.
    var storeContext: MKPaywallContext {
        switch self {
        case .onboardingTrialIntro:
            return .onboardingTrialIntro
        case .premiumFeatureTap(let feature):
            return .premiumFeatureTap(feature: feature.storeFeatureIdentifier)
        case .settingsUpgrade:
            return .settingsUpsell
        }
    }
}
