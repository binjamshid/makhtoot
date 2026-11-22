package net.binjamshid.makhtoot.support

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

enum class MkAppSignpost(val rawValue: String) {
    LAUNCH(""), BROWSER_SCROLL(""), EDITOR_OPEN("");
    companion object {
        val signposter: Any? = null
    }
}

class MkLaunchTimer(
    var state: OSSignpostIntervalState? = null,
    var hasEnded: Boolean = false
) {
    fun endIfNeeded() { throw MkNotYetPorted("app.MkLaunchTimer.endIfNeeded") }
    companion object {
        val shared: MkLaunchTimer = MkLaunchTimer()
    }
}

