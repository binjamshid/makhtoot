package net.binjamshid.makhtoot.navigation

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkProjectId

sealed class MkRoute {
    object Browser : MkRoute()
    data class Editor(val arg0: MkProjectId) : MkRoute()
    object Settings : MkRoute()
    data class Paywall(val arg0: MkPaywallContext) : MkRoute()
    object Onboarding : MkRoute()
    val id: MkRoute
        get() = throw MkNotYetPorted("app.MkRoute.id")
}

sealed class MkPaywallContext {
    object OnboardingTrialIntro : MkPaywallContext()
    data class PremiumFeatureTap(val arg0: MkPremiumFeature) : MkPaywallContext()
    object SettingsUpgrade : MkPaywallContext()
}

enum class MkPremiumFeature {
    CUSTOM_CANVAS, PREMIUM_FONT, PHOTO_BACKGROUND, CLOUD_SYNC, EXPORT_FORMAT, PREMIUM_ASSET;
    val storeFeatureIdentifier: String
        get() = throw MkNotYetPorted("app.MkPremiumFeature.storeFeatureIdentifier")
}

val MkPaywallContext.storeContext: MkPaywallContext
    get() = throw MkNotYetPorted("app.MkPaywallContext.storeContext")

