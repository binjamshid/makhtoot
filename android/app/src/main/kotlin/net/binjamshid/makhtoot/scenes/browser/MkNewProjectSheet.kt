package net.binjamshid.makhtoot.scenes.browser

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkCanvasSpec

@androidx.compose.runtime.Composable
fun MkNewProjectSheet(onCreate: (MkCanvasSpec) -> Unit, onCreateFromPhoto: (MkCanvasSpec, ByteArray) -> Unit, customWidthText: String = "1080", customHeightText: String = "1080", showsCustomFields: Boolean = false, photoPickerItem: PhotosPickerItem? = null, showsPhotoPicker: Boolean = false, isIngestingPhoto: Boolean = false, cardIconSize: Double = 26.0, presets: List<Preset>? = null, columns: List<String>? = null, pixelSize: Any? = null, canvasSize: Any? = null, currentArea: Any? = null, scale: Any? = null, width: Any? = null, height: Any? = null) { }
suspend fun MkNewProjectSheet_ingestPhoto(item: PhotosPickerItem) { throw MkNotYetPorted("app.MkNewProjectSheet.ingestPhoto") }
@androidx.compose.runtime.Composable
fun MkNewProjectSheet_presetCard(preset: Preset) { }
fun MkNewProjectSheet_dimensionLabel(size: MkSize): String { throw MkNotYetPorted("app.MkNewProjectSheet.dimensionLabel") }
@androidx.compose.runtime.Composable
fun MkNewProjectSheet_photoCard() { }
@androidx.compose.runtime.Composable
fun MkNewProjectSheet_customCard() { }
@androidx.compose.runtime.Composable
fun MkNewProjectSheet_customFieldsPanel() { }
val MkNewProjectSheet_navTitle: String
    get() = throw MkNotYetPorted("app.MkNewProjectSheet.navTitle")
val MkNewProjectSheet_cancelLabel: String
    get() = throw MkNotYetPorted("app.MkNewProjectSheet.cancelLabel")
val MkNewProjectSheet_customLabel: String
    get() = throw MkNotYetPorted("app.MkNewProjectSheet.customLabel")
val MkNewProjectSheet_customSubtitle: String
    get() = throw MkNotYetPorted("app.MkNewProjectSheet.customSubtitle")
val MkNewProjectSheet_photoLabel: String
    get() = throw MkNotYetPorted("app.MkNewProjectSheet.photoLabel")
val MkNewProjectSheet_photoSubtitle: String
    get() = throw MkNotYetPorted("app.MkNewProjectSheet.photoSubtitle")
val MkNewProjectSheet_widthLabel: String
    get() = throw MkNotYetPorted("app.MkNewProjectSheet.widthLabel")
val MkNewProjectSheet_heightLabel: String
    get() = throw MkNotYetPorted("app.MkNewProjectSheet.heightLabel")
val MkNewProjectSheet_widthPlaceholder: String
    get() = throw MkNotYetPorted("app.MkNewProjectSheet.widthPlaceholder")
val MkNewProjectSheet_heightPlaceholder: String
    get() = throw MkNotYetPorted("app.MkNewProjectSheet.heightPlaceholder")
val MkNewProjectSheet_createCustomLabel: String
    get() = throw MkNotYetPorted("app.MkNewProjectSheet.createCustomLabel")

