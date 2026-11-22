package net.binjamshid.makhtoot.mk.store.trial

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

interface MkClockProviding {
    fun now(): java.time.Instant
    fun systemUptime(): Double
}

class MkSystemClock : MkClockProviding {
    override fun now(): java.time.Instant { throw MkNotYetPorted("mk-store.MkSystemClock.now") }
    override fun systemUptime(): Double { throw MkNotYetPorted("mk-store.MkSystemClock.systemUptime") }
}

class MkFakeClock(
    now: java.time.Instant = java.time.Instant.now(),
    val uptime: Double = 0.0
) : MkClockProviding {
    override fun now(): java.time.Instant { throw MkNotYetPorted("mk-store.MkFakeClock.now") }
    override fun systemUptime(): Double { throw MkNotYetPorted("mk-store.MkFakeClock.systemUptime") }
    fun advance(interval: Double) { throw MkNotYetPorted("mk-store.MkFakeClock.advance") }
    fun setWallClock(date: java.time.Instant) { throw MkNotYetPorted("mk-store.MkFakeClock.setWallClock") }
    fun setUptime(uptime: Double) { throw MkNotYetPorted("mk-store.MkFakeClock.setUptime") }
}

