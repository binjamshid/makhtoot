package net.binjamshid.makhtoot

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.designsystem.MkTheme

data class MkMakhtootApp(
    var themeIDRaw: String? = null,
    var colorSchemeRaw: String = "system",
    var container: MkAppContainer = MkAppContainer()
) {
    val theme: MkTheme
        get() = throw MkNotYetPorted("app.MkMakhtootApp.theme")
    val preferredColorScheme: ColorScheme?
        get() = throw MkNotYetPorted("app.MkMakhtootApp.preferredColorScheme")
    val body: Scene
        get() = throw MkNotYetPorted("app.MkMakhtootApp.body")
}

