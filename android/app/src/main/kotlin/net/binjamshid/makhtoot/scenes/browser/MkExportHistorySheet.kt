package net.binjamshid.makhtoot.scenes.browser

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.stubs.MkProjectExportHistoryEntry

@androidx.compose.runtime.Composable
fun MkExportHistorySheet(projectName: String, entries: List<MkProjectExportHistoryEntry>, emptyStateIconSize: Double = 36.0) { }
@androidx.compose.runtime.Composable
fun MkExportHistorySheet_row(entry: MkProjectExportHistoryEntry) { }
@androidx.compose.runtime.Composable
fun MkExportHistorySheet_emptyState() { }
val MkExportHistorySheet_navTitle: String
    get() = throw MkNotYetPorted("app.MkExportHistorySheet.navTitle")
val MkExportHistorySheet_closeLabel: String
    get() = throw MkNotYetPorted("app.MkExportHistorySheet.closeLabel")
val MkExportHistorySheet_emptyTitle: String
    get() = throw MkNotYetPorted("app.MkExportHistorySheet.emptyTitle")

