package net.binjamshid.makhtoot.navigation

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkProjectId

class MkAppNavigationModel(
    var path: List<MkRoute> = emptyList(),
    var presentedSheet: MkRoute? = null,
    var presentedFullScreenCover: MkRoute? = null,
    var sidebarSelection: SidebarItem? = null,
    var pendingBackgroundImageImport: PendingBackgroundImageImport? = null
) {
    val hasCompletedOnboarding: Boolean
        get() = throw MkNotYetPorted("app.MkAppNavigationModel.hasCompletedOnboarding")
    val lastOpenProjectID: MkProjectId?
        get() = throw MkNotYetPorted("app.MkAppNavigationModel.lastOpenProjectID")
    val uuid: Any
        get() = throw MkNotYetPorted("app.MkAppNavigationModel.uuid")
    fun openEditor(id: MkProjectId, isRegularWidth: Boolean) { throw MkNotYetPorted("app.MkAppNavigationModel.openEditor") }
    fun presentSettings() { throw MkNotYetPorted("app.MkAppNavigationModel.presentSettings") }
    fun completeOnboarding() { throw MkNotYetPorted("app.MkAppNavigationModel.completeOnboarding") }
    fun resetOnboarding() { throw MkNotYetPorted("app.MkAppNavigationModel.resetOnboarding") }
    companion object {
        val hasCompletedOnboardingKey: String = "MKHasCompletedOnboarding"
        val lastOpenProjectIDKey: String = "MKLastOpenProjectID"
    }
    enum class SidebarItem {
        BROWSER, SETTINGS
    }
    data class PendingBackgroundImageImport(
        val projectID: MkProjectId,
        val data: ByteArray
    )
}

