package net.binjamshid.makhtoot.mk.sync.changetracking

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

enum class MkSyncPendingKind {
    UPLOAD, DELETE
}

data class MkSyncPendingEntry(
    val projectID: java.util.UUID,
    val kind: MkSyncPendingKind,
    val enqueuedAt: java.time.Instant = java.time.Instant.now()
)

class MkSyncPendingQueue {
    val count: Int
        get() = throw MkNotYetPorted("mk-sync.MkSyncPendingQueue.count")
    fun scheduleUpload(projectID: java.util.UUID, date: java.time.Instant = java.time.Instant.now()) { throw MkNotYetPorted("mk-sync.MkSyncPendingQueue.scheduleUpload") }
    fun scheduleDelete(projectID: java.util.UUID, date: java.time.Instant = java.time.Instant.now()) { throw MkNotYetPorted("mk-sync.MkSyncPendingQueue.scheduleDelete") }
    fun nextBatch(debounce: kotlin.time.Duration? = null): List<MkSyncPendingEntry> { throw MkNotYetPorted("mk-sync.MkSyncPendingQueue.nextBatch") }
    fun allEntries(): List<MkSyncPendingEntry> { throw MkNotYetPorted("mk-sync.MkSyncPendingQueue.allEntries") }
    fun clear(id: java.util.UUID) { throw MkNotYetPorted("mk-sync.MkSyncPendingQueue.clear") }
    fun entry(id: java.util.UUID): MkSyncPendingEntry? { throw MkNotYetPorted("mk-sync.MkSyncPendingQueue.entry") }
    fun removeAll() { throw MkNotYetPorted("mk-sync.MkSyncPendingQueue.removeAll") }
}

