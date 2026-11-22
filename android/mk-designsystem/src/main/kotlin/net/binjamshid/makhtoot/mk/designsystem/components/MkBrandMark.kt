package net.binjamshid.makhtoot.mk.designsystem.components

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.designsystem.MkTypeRole

enum class MkBrandMarkStyle(val rawValue: String) {
    WORDMARK_ONLY(""), CIRCLE(""), DIAMOND("");
    val id: String
        get() = throw MkNotYetPorted("mk-designsystem.MkBrandMarkStyle.id")
    val displayName: String
        get() = throw MkNotYetPorted("mk-designsystem.MkBrandMarkStyle.displayName")
}

@androidx.compose.runtime.Composable
fun MkBrandMark(style: MkBrandMarkStyle, wordmarkRole: MkTypeRole = MkTypeRole.LARGE_TITLE) { }

