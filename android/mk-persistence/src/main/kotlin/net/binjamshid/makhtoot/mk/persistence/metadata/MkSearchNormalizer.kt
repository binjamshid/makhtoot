package net.binjamshid.makhtoot.mk.persistence.metadata

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkScene

object MkSearchNormalizer {
    fun normalize(input: String): String { throw MkNotYetPorted("mk-persistence.MkSearchNormalizer.normalize") }
    fun matches(query: String, text: String): Boolean { throw MkNotYetPorted("mk-persistence.MkSearchNormalizer.matches") }
}

object MkSearchTextExtractor {
    fun extract(scene: MkScene, title: String): String { throw MkNotYetPorted("mk-persistence.MkSearchTextExtractor.extract") }
}

