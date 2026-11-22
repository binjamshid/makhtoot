package net.binjamshid.makhtoot.navigation

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkProjectId

sealed class MkRoute {
    object Browser : MkRoute()
    data class Editor(val arg0: MkProjectId) : MkRoute()
    object Settings : MkRoute()
    object Onboarding : MkRoute()
    val id: MkRoute
        get() = throw MkNotYetPorted("app.MkRoute.id")
}
