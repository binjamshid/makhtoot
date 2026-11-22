package net.binjamshid.makhtoot.mk.designsystem

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

enum class MkTypeRole {
    DISPLAY, LARGE_TITLE, TITLE, TITLE2, HEADLINE, BODY, CALLOUT, FOOTNOTE, CAPTION, MONO
}

data class MkTypeStyle(
    val font: Any,
    val weight: Any? = null,
    val lineHeightMultiplier: Double,
    val pointSize: Double
) {
    val extraLineSpacing: Double
        get() = throw MkNotYetPorted("mk-designsystem.MkTypeStyle.extraLineSpacing")
}

data class MkTypeRamp(
    val fonts: MkFontSet
) {
    fun style(role: MkTypeRole): MkTypeStyle { throw MkNotYetPorted("mk-designsystem.MkTypeRamp.style") }
    companion object {
        val default: Any? = null
    }
}

fun androidx.compose.ui.Modifier.mkTypeStyle(style: MkTypeStyle): androidx.compose.ui.Modifier { throw MkNotYetPorted("mk-designsystem.View.mkTypeStyle") }
fun androidx.compose.ui.Modifier.mkDefaultFont(theme: MkTheme, size: Double = 17.0): androidx.compose.ui.Modifier { throw MkNotYetPorted("mk-designsystem.View.mkDefaultFont") }

