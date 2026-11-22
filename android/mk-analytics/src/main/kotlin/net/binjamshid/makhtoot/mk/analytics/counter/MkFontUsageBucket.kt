package net.binjamshid.makhtoot.mk.analytics.counter

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

enum class MkFontUsageBucket(val rawValue: String) {
    LOW(""), MEDIUM(""), HIGH(""), VERY_HIGH(""), INTENSE("");
    companion object {
        fun bucket(count: Int): MkFontUsageBucket { throw MkNotYetPorted("mk-analytics.MkFontUsageBucket.bucket") }
    }
}

