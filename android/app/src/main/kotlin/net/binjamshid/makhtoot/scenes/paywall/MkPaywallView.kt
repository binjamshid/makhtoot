package net.binjamshid.makhtoot.scenes.paywall

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.store.MkCatalogState
import net.binjamshid.makhtoot.mk.store.MkStoreProduct
import net.binjamshid.makhtoot.mk.store.paywall.MkPaywallContext
import net.binjamshid.makhtoot.mk.store.paywall.MkPaywallState
import net.binjamshid.makhtoot.mk.store.paywall.MkPaywallStateMachine

@androidx.compose.runtime.Composable
fun MkPaywallView(context: MkPaywallContext, onClose: () -> Unit, machine: MkPaywallStateMachine? = null, products: List<MkStoreProduct> = emptyList(), catalogState: MkCatalogState? = null, showsRedundantSheet: Boolean = false, headerIconSize: Double = 44.0, featureIconSize: Double = 16.0, purchaseMachine: Any? = null, comparison: List<ComparisonRow>? = null) { }
suspend fun MkPaywallView_load() { throw MkNotYetPorted("app.MkPaywallView.load") }
@androidx.compose.runtime.Composable
fun MkPaywallView_productList(products: List<MkStoreProduct>) { }
@androidx.compose.runtime.Composable
fun MkPaywallView_productRow(product: MkStoreProduct) { }
@androidx.compose.runtime.Composable
fun MkPaywallView_statusBanner(state: MkPaywallState) { }
@androidx.compose.runtime.Composable
fun MkPaywallView_closeBar() { }
@androidx.compose.runtime.Composable
fun MkPaywallView_header() { }
@androidx.compose.runtime.Composable
fun MkPaywallView_featuresSection() { }
@androidx.compose.runtime.Composable
fun MkPaywallView_restoreButton() { }
val MkPaywallView_isBusy: Boolean
    get() = throw MkNotYetPorted("app.MkPaywallView.isBusy")
@androidx.compose.runtime.Composable
fun MkPaywallView_freeTierNote() { }
@androidx.compose.runtime.Composable
fun MkPaywallView_legalLinks() { }
val MkPaywallView_featuresTitle: String
    get() = throw MkNotYetPorted("app.MkPaywallView.featuresTitle")
val MkPaywallView_featureColumnLabel: String
    get() = throw MkNotYetPorted("app.MkPaywallView.featureColumnLabel")
val MkPaywallView_freeColumnLabel: String
    get() = throw MkNotYetPorted("app.MkPaywallView.freeColumnLabel")
val MkPaywallView_premiumColumnLabel: String
    get() = throw MkNotYetPorted("app.MkPaywallView.premiumColumnLabel")
val MkPaywallView_notIncludedMark: String
    get() = throw MkNotYetPorted("app.MkPaywallView.notIncludedMark")
val MkPaywallView_notIncludedSpoken: String
    get() = throw MkNotYetPorted("app.MkPaywallView.notIncludedSpoken")
val MkPaywallView_title: String
    get() = throw MkNotYetPorted("app.MkPaywallView.title")
val MkPaywallView_trialFraming: String
    get() = throw MkNotYetPorted("app.MkPaywallView.trialFraming")
val MkPaywallView_autoRenewDisclosure: String
    get() = throw MkNotYetPorted("app.MkPaywallView.autoRenewDisclosure")
val MkPaywallView_restoreLabel: String
    get() = throw MkNotYetPorted("app.MkPaywallView.restoreLabel")
val MkPaywallView_privacyLabel: String
    get() = throw MkNotYetPorted("app.MkPaywallView.privacyLabel")
val MkPaywallView_termsLabel: String
    get() = throw MkNotYetPorted("app.MkPaywallView.termsLabel")
val MkPaywallView_freeTierCopy: String
    get() = throw MkNotYetPorted("app.MkPaywallView.freeTierCopy")
val MkPaywallView_successCopy: String
    get() = throw MkNotYetPorted("app.MkPaywallView.successCopy")
val MkPaywallView_failedGenericCopy: String
    get() = throw MkNotYetPorted("app.MkPaywallView.failedGenericCopy")
val MkPaywallView_closeLabel: String
    get() = throw MkNotYetPorted("app.MkPaywallView.closeLabel")

@androidx.compose.runtime.Composable
fun MkRedundantSubscriptionSheet(onDismiss: () -> Unit, iconSize: Double = 40.0) { }
val MkRedundantSubscriptionSheet_title: String
    get() = throw MkNotYetPorted("app.MkRedundantSubscriptionSheet.title")
val MkRedundantSubscriptionSheet_body_: String
    get() = throw MkNotYetPorted("app.MkRedundantSubscriptionSheet.body_")
val MkRedundantSubscriptionSheet_manageLabel: String
    get() = throw MkNotYetPorted("app.MkRedundantSubscriptionSheet.manageLabel")
val MkRedundantSubscriptionSheet_dismissLabel: String
    get() = throw MkNotYetPorted("app.MkRedundantSubscriptionSheet.dismissLabel")

