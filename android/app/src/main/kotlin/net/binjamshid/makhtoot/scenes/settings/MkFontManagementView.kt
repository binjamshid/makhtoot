package net.binjamshid.makhtoot.scenes.settings

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.fonts.MkFontRecord
import net.binjamshid.makhtoot.mk.fonts.MkFontId

@androidx.compose.runtime.Composable
fun MkFontManagementView(records: List<MkFontRecord> = emptyList(), systemInstalledIDs: Set<MkFontId> = emptyList(), showsFileImporter: Boolean = false, isImporting: Boolean = false, importErrorText: String? = null, showsPaywall: Boolean = false, installErrorText: String? = null, installingFontID: MkFontId? = null, isInstalled: Any? = null, isBusy: Any? = null) { }
@androidx.compose.runtime.Composable
fun MkFontManagementView_installRow(record: MkFontRecord) { }
suspend fun MkFontManagementView_refresh() { throw MkNotYetPorted("app.MkFontManagementView.refresh") }
fun MkFontManagementView_install(fontID: MkFontId) { throw MkNotYetPorted("app.MkFontManagementView.install") }
fun MkFontManagementView_uninstall(fontID: MkFontId) { throw MkNotYetPorted("app.MkFontManagementView.uninstall") }
suspend fun MkFontManagementView_importFont(url: java.net.URI) { throw MkNotYetPorted("app.MkFontManagementView.importFont") }
val MkFontManagementView_isEntitledToImport: Boolean
    get() = throw MkNotYetPorted("app.MkFontManagementView.isEntitledToImport")
@androidx.compose.runtime.Composable
fun MkFontManagementView_importSection() { }
@androidx.compose.runtime.Composable
fun MkFontManagementView_installedFontsSection() { }
val MkFontManagementView_navTitle: String
    get() = throw MkNotYetPorted("app.MkFontManagementView.navTitle")
val MkFontManagementView_importSectionHeader: String
    get() = throw MkNotYetPorted("app.MkFontManagementView.importSectionHeader")
val MkFontManagementView_importActionLabel: String
    get() = throw MkNotYetPorted("app.MkFontManagementView.importActionLabel")
val MkFontManagementView_importSectionFooter: String
    get() = throw MkNotYetPorted("app.MkFontManagementView.importSectionFooter")
val MkFontManagementView_installedSectionHeader: String
    get() = throw MkNotYetPorted("app.MkFontManagementView.installedSectionHeader")
val MkFontManagementView_installedSectionFooter: String
    get() = throw MkNotYetPorted("app.MkFontManagementView.installedSectionFooter")
val MkFontManagementView_installActionLabel: String
    get() = throw MkNotYetPorted("app.MkFontManagementView.installActionLabel")
val MkFontManagementView_uninstallActionLabel: String
    get() = throw MkNotYetPorted("app.MkFontManagementView.uninstallActionLabel")
val MkFontManagementView_genericImportFailureText: String
    get() = throw MkNotYetPorted("app.MkFontManagementView.genericImportFailureText")
val MkFontManagementView_genericInstallFailureText: String
    get() = throw MkNotYetPorted("app.MkFontManagementView.genericInstallFailureText")

