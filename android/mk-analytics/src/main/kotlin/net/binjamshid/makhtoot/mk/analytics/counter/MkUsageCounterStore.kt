package net.binjamshid.makhtoot.mk.analytics.counter

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

class MkUsageCounterStore(
    val storeURL: java.net.URI
) {
    val isEmpty: Boolean
        get() = throw MkNotYetPorted("mk-analytics.MkUsageCounterStore.isEmpty")
    fun load() { throw MkNotYetPorted("mk-analytics.MkUsageCounterStore.load") }
    fun increment(fontID: String) { throw MkNotYetPorted("mk-analytics.MkUsageCounterStore.increment") }
    fun closedWeekEntries(): List<Triple<String, String, Int>> { throw MkNotYetPorted("mk-analytics.MkUsageCounterStore.closedWeekEntries") }
    fun deleteEntries(week: String) { throw MkNotYetPorted("mk-analytics.MkUsageCounterStore.deleteEntries") }
    fun wipeAll() { throw MkNotYetPorted("mk-analytics.MkUsageCounterStore.wipeAll") }
    fun pruneOldEntries(currentWeek: String? = null): Set<String> { throw MkNotYetPorted("mk-analytics.MkUsageCounterStore.pruneOldEntries") }
    companion object {
        fun production(): MkUsageCounterStore { throw MkNotYetPorted("mk-analytics.MkUsageCounterStore.production") }
    }
}

object MkIsoWeek {
    fun current(): String { throw MkNotYetPorted("mk-analytics.MkIsoWeek.current") }
    fun string(date: java.time.Instant): String { throw MkNotYetPorted("mk-analytics.MkIsoWeek.string") }
    fun week(n: Int, base: String): String? { throw MkNotYetPorted("mk-analytics.MkIsoWeek.week") }
    fun date(weekString: String): java.time.Instant? { throw MkNotYetPorted("mk-analytics.MkIsoWeek.date") }
}

