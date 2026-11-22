package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.fonts.MkFontRecord
import net.binjamshid.makhtoot.mk.fonts.MkFontRegistry
import net.binjamshid.makhtoot.mk.model.MkFontRef
import net.binjamshid.makhtoot.mk.fonts.MkFontId

@androidx.compose.runtime.Composable
fun MkFontBrowserSheet(fontRegistry: MkFontRegistry, currentFontID: String? = null, sampleText: String, onSelect: (MkFontRef) -> Unit, records: List<MkFontRecord> = emptyList(), systemInstalledIDs: Set<MkFontId> = emptyList(), face: Any? = null, isInstalled: Any? = null, ref: Any? = null) { }
@androidx.compose.runtime.Composable
fun MkFontBrowserSheet_fontRow(record: MkFontRecord) { }
val MkFontBrowserSheet_effectiveSample: String
    get() = throw MkNotYetPorted("app.MkFontBrowserSheet.effectiveSample")
val MkFontBrowserSheet_myFonts: List<MkFontRecord>
    get() = throw MkNotYetPorted("app.MkFontBrowserSheet.myFonts")
val MkFontBrowserSheet_catalogFonts: List<MkFontRecord>
    get() = throw MkNotYetPorted("app.MkFontBrowserSheet.catalogFonts")
val MkFontBrowserSheet_myFontsHeader: String
    get() = throw MkNotYetPorted("app.MkFontBrowserSheet.myFontsHeader")

