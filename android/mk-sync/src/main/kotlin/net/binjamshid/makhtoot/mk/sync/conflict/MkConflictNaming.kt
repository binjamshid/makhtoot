package net.binjamshid.makhtoot.mk.sync.conflict

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

object MkConflictNaming {
    val conflictSuffix: String = "(نسخة متعارضة)"
    fun conflictCopyName(originalName: String, existingNames: Set<String>): String { throw MkNotYetPorted("mk-sync.MkConflictNaming.conflictCopyName") }
}

