package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkProjectId
import net.binjamshid.makhtoot.mk.persistence.metadata.MkProjectSummary

@androidx.compose.runtime.Composable
fun MkMergeDesignSheet(excludingProjectID: MkProjectId, onMerge: (MkProjectId) -> Unit, projects: List<MkProjectSummary> = emptyList(), searchText: String = "", isLoading: Boolean = true) { }
val MkMergeDesignSheet_filtered: List<MkProjectSummary>
    get() = throw MkNotYetPorted("app.MkMergeDesignSheet.filtered")
val MkMergeDesignSheet_base: Any
    get() = throw MkNotYetPorted("app.MkMergeDesignSheet.base")
@androidx.compose.runtime.Composable
fun MkMergeDesignSheet_emptyStateView() { }
val MkMergeDesignSheet_navTitle: String
    get() = throw MkNotYetPorted("app.MkMergeDesignSheet.navTitle")
val MkMergeDesignSheet_cancelLabel: String
    get() = throw MkNotYetPorted("app.MkMergeDesignSheet.cancelLabel")
val MkMergeDesignSheet_emptyStateText: String
    get() = throw MkNotYetPorted("app.MkMergeDesignSheet.emptyStateText")

