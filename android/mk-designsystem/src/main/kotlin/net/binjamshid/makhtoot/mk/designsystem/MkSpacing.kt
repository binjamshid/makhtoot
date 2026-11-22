package net.binjamshid.makhtoot.mk.designsystem

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkSpacing(
    var xs: Double = 4.0,
    var sm: Double = 8.0,
    var md: Double = 12.0,
    var lg: Double = 16.0,
    var xl: Double = 24.0,
    var xxl: Double = 32.0,
    var xxxl: Double = 48.0
) {
    companion object {
        val default: MkSpacing = MkSpacing()
    }
}

