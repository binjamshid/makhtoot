package net.binjamshid.makhtoot.mk.designsystem

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkElevationStyle(
    var radius: Double,
    var yOffset: Double,
    var opacity: Double
)

data class MkElevationStyles(
    var panel: MkElevationStyle,
    var floatingBar: MkElevationStyle
)

data class MkRadiusScale(
    var button: Double,
    var card: Double,
    var sheet: Double,
    var pill: Double,
    var style: Any? = null
)

data class MkFontSet(
    var display: String,
    var ui: String,
    var accent: String? = null,
    var mono: String
)

interface MkTheme {
    val bg: androidx.compose.ui.graphics.Color
    val bgAlt: androidx.compose.ui.graphics.Color
    val surface: androidx.compose.ui.graphics.Color
    val surfaceMuted: androidx.compose.ui.graphics.Color
    val border: androidx.compose.ui.graphics.Color
    val ink: androidx.compose.ui.graphics.Color
    val inkMuted: androidx.compose.ui.graphics.Color
    val inkFaint: androidx.compose.ui.graphics.Color
    val primary: androidx.compose.ui.graphics.Color
    val primaryPressed: androidx.compose.ui.graphics.Color
    val onPrimary: androidx.compose.ui.graphics.Color
    val secondary: androidx.compose.ui.graphics.Color
    val canvasBackdrop: androidx.compose.ui.graphics.Color
    val selectionStroke: androidx.compose.ui.graphics.Color
    val warning: androidx.compose.ui.graphics.Color
    val destructive: androidx.compose.ui.graphics.Color
    val fonts: MkFontSet
    val typeRamp: MkTypeRamp
    val spacing: MkSpacing
    val radius: MkRadiusScale
    val elevation: MkElevationStyles
    val motion: MkMotionTokens
}

enum class MkThemeId(val rawValue: String) {
    HIBR(""), NAQSH(""), RAML(""), TAYF(""), KUFI("");
    val id: String
        get() = throw MkNotYetPorted("mk-designsystem.MkThemeId.id")
    val displayName: String
        get() = throw MkNotYetPorted("mk-designsystem.MkThemeId.displayName")
    fun resolve(): MkTheme { throw MkNotYetPorted("mk-designsystem.MkThemeId.resolve") }
}

val Any.mkTheme: MkTheme
    get() = throw MkNotYetPorted("mk-designsystem.Any.mkTheme")

