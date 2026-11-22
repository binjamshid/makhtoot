package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.assets.browser.MkAssetBrowserModel
import net.binjamshid.makhtoot.mk.assets.model.MkAssetDescriptor
import net.binjamshid.makhtoot.mk.assets.rendering.MkAssetThumbnailRenderer

@androidx.compose.runtime.Composable
fun MkAssetBrowserSheet(viewModel: MkEditorViewModel, model: MkAssetBrowserModel, thumbnailRenderer: MkAssetThumbnailRenderer, onRequestPaywall: () -> Unit, selectedFilter: Filter? = null, searchText: String = "", isLoadingMetadata: Boolean = true, columns: List<String>? = null, emptyStateIconSize: Double = 32.0, outcome: Any? = null) { }
fun MkAssetBrowserSheet_select(descriptor: MkAssetDescriptor) { throw MkNotYetPorted("app.MkAssetBrowserSheet.select") }
val MkAssetBrowserSheet_currentDescriptors: List<MkAssetDescriptor>
    get() = throw MkNotYetPorted("app.MkAssetBrowserSheet.currentDescriptors")
@androidx.compose.runtime.Composable
fun MkAssetBrowserSheet_filterChips() { }
@androidx.compose.runtime.Composable
fun MkAssetBrowserSheet_assetGrid() { }
@androidx.compose.runtime.Composable
fun MkAssetBrowserSheet_emptyState() { }
val MkAssetBrowserSheet_titleLabel: String
    get() = throw MkNotYetPorted("app.MkAssetBrowserSheet.titleLabel")
val MkAssetBrowserSheet_closeLabel: String
    get() = throw MkNotYetPorted("app.MkAssetBrowserSheet.closeLabel")
val MkAssetBrowserSheet_searchPrompt: String
    get() = throw MkNotYetPorted("app.MkAssetBrowserSheet.searchPrompt")
val MkAssetBrowserSheet_recentLabel: String
    get() = throw MkNotYetPorted("app.MkAssetBrowserSheet.recentLabel")
val MkAssetBrowserSheet_favoritesLabel: String
    get() = throw MkNotYetPorted("app.MkAssetBrowserSheet.favoritesLabel")
val MkAssetBrowserSheet_emptyStateLabel: String
    get() = throw MkNotYetPorted("app.MkAssetBrowserSheet.emptyStateLabel")

@androidx.compose.runtime.Composable
fun MkAssetCell(descriptor: MkAssetDescriptor, isLocked: Boolean, isFavorite: Boolean, thumbnailRenderer: MkAssetThumbnailRenderer, onSelect: () -> Unit, onToggleFavorite: () -> Unit, thumbnail: Any? = null) { }
val MkAssetCell_lockedHint: String
    get() = throw MkNotYetPorted("app.MkAssetCell.lockedHint")
val MkAssetCell_addFavoriteLabel: String
    get() = throw MkNotYetPorted("app.MkAssetCell.addFavoriteLabel")
val MkAssetCell_removeFavoriteLabel: String
    get() = throw MkNotYetPorted("app.MkAssetCell.removeFavoriteLabel")

