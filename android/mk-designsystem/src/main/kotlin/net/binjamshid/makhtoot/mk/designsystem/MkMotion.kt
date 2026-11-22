package net.binjamshid.makhtoot.mk.designsystem

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

enum class MkMotionCurve {
    EASE_IN_OUT
}

data class MkMotionTokens(
    var fastDuration: Double = 0.15,
    var standardDuration: Double = 0.25,
    var modalDuration: Double = 0.35,
    var curve: MkMotionCurve = MkMotionCurve.EASE_IN_OUT,
    var reducesMotion: Boolean = false
) {
    val fast: Any
        get() = throw MkNotYetPorted("mk-designsystem.MkMotionTokens.fast")
    val standard: Any
        get() = throw MkNotYetPorted("mk-designsystem.MkMotionTokens.standard")
    val modal: Any
        get() = throw MkNotYetPorted("mk-designsystem.MkMotionTokens.modal")
    companion object {
        val default: MkMotionTokens = MkMotionTokens()
    }
}

