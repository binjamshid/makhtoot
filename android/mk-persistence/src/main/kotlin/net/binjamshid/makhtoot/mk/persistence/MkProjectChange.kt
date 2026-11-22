package net.binjamshid.makhtoot.mk.persistence

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.persistence.metadata.MkProjectSummary

sealed class MkProjectChange {
    data class Created(val arg0: MkProjectSummary) : MkProjectChange()
    data class Modified(val arg0: MkProjectSummary) : MkProjectChange()
    data class Renamed(val arg0: java.util.UUID, val newTitle: String) : MkProjectChange()
    data class Deleted(val arg0: java.util.UUID) : MkProjectChange()
}

