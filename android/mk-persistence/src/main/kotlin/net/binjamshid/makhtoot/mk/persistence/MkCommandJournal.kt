package net.binjamshid.makhtoot.mk.persistence

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand

data class MkJournalRecord(
    val seq: Int,
    val ts: java.time.Instant,
    val baseRev: String,
    val command: MkCommand
)

class MkCommandJournal(
    val journalURL: java.net.URI
) {
    fun append(command: MkCommand, baseRev: String) { throw MkNotYetPorted("mk-persistence.MkCommandJournal.append") }
    fun truncate() { throw MkNotYetPorted("mk-persistence.MkCommandJournal.truncate") }
    fun isEmpty(): Boolean { throw MkNotYetPorted("mk-persistence.MkCommandJournal.isEmpty") }
    fun readValidRecords(): Pair<List<MkJournalRecord>, ByteArray?> { throw MkNotYetPorted("mk-persistence.MkCommandJournal.readValidRecords") }
}

