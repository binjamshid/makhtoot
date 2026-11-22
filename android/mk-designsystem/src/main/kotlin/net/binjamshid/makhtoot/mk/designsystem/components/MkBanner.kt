package net.binjamshid.makhtoot.mk.designsystem.components

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

enum class MkBannerSeverity {
    INFO, WARNING, DESTRUCTIVE
}

@androidx.compose.runtime.Composable
fun MkBanner(message: String, severity: MkBannerSeverity = MkBannerSeverity.INFO) { }

