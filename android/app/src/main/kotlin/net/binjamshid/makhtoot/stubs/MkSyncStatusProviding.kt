package net.binjamshid.makhtoot.stubs

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkProjectId
import net.binjamshid.makhtoot.mk.sync.status.MkSyncStatusPublisher

enum class MkSyncBadgeState {
    NONE, SYNCING, SYNCED, ERROR
}

interface MkSyncStatusProviding {
    fun badge(id: MkProjectId): MkSyncBadgeState
}

class MkSyncStatusAdapter(
    val publisher: MkSyncStatusPublisher
) : MkSyncStatusProviding {
    override fun badge(id: MkProjectId): MkSyncBadgeState { throw MkNotYetPorted("app.MkSyncStatusAdapter.badge") }
}

class MkStaticSyncStatusPublisher : MkSyncStatusProviding {
    override fun badge(id: MkProjectId): MkSyncBadgeState { throw MkNotYetPorted("app.MkStaticSyncStatusPublisher.badge") }
}

