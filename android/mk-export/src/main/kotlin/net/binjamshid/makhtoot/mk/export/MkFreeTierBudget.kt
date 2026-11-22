package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize

object MkFreeTierBudget {
    val effectivePixelBudget: Any = 2000000
    fun clamped(size: MkSize, budget: Int = effectivePixelBudget): MkSize { throw MkNotYetPorted("mk-export.MkFreeTierBudget.clamped") }
    fun exceedsBudget(size: MkSize, budget: Int = effectivePixelBudget): Boolean { throw MkNotYetPorted("mk-export.MkFreeTierBudget.exceedsBudget") }
}

