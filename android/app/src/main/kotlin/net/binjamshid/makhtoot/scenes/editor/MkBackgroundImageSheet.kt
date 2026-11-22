package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkBackgroundImageFit

@androidx.compose.runtime.Composable
fun MkBackgroundImageSheet(viewModel: MkEditorViewModel, onRequestPaywall: () -> Unit, pickerItem: PhotosPickerItem? = null, showsPhotosPicker: Boolean = false, showsFileImporter: Boolean = false, isIngesting: Boolean = false, ingestErrorText: String? = null, previewIconSize: Double = 32.0, outcome: Any? = null) { }
fun MkBackgroundImageSheet_requestPhotosPicker() { throw MkNotYetPorted("app.MkBackgroundImageSheet.requestPhotosPicker") }
suspend fun MkBackgroundImageSheet_ingest(photosPickerItem: PhotosPickerItem) { throw MkNotYetPorted("app.MkBackgroundImageSheet.ingest") }
suspend fun MkBackgroundImageSheet_ingest(fileURL: java.net.URI) { throw MkNotYetPorted("app.MkBackgroundImageSheet.ingest") }
suspend fun MkBackgroundImageSheet_commitIngest(data: ByteArray) { throw MkNotYetPorted("app.MkBackgroundImageSheet.commitIngest") }
val MkBackgroundImageSheet_isEntitled: Boolean
    get() = throw MkNotYetPorted("app.MkBackgroundImageSheet.isEntitled")
val MkBackgroundImageSheet_hasImage: Boolean
    get() = throw MkNotYetPorted("app.MkBackgroundImageSheet.hasImage")
val MkBackgroundImageSheet_currentFit: MkBackgroundImageFit
    get() = throw MkNotYetPorted("app.MkBackgroundImageSheet.currentFit")
@androidx.compose.runtime.Composable
fun MkBackgroundImageSheet_previewArea() { }
val MkBackgroundImageSheet_title: String
    get() = throw MkNotYetPorted("app.MkBackgroundImageSheet.title")
val MkBackgroundImageSheet_doneLabel: String
    get() = throw MkNotYetPorted("app.MkBackgroundImageSheet.doneLabel")
val MkBackgroundImageSheet_chooseFromPhotosLabel: String
    get() = throw MkNotYetPorted("app.MkBackgroundImageSheet.chooseFromPhotosLabel")
val MkBackgroundImageSheet_chooseFromFilesLabel: String
    get() = throw MkNotYetPorted("app.MkBackgroundImageSheet.chooseFromFilesLabel")
val MkBackgroundImageSheet_editLabel: String
    get() = throw MkNotYetPorted("app.MkBackgroundImageSheet.editLabel")
val MkBackgroundImageSheet_fitCoverLabel: String
    get() = throw MkNotYetPorted("app.MkBackgroundImageSheet.fitCoverLabel")
val MkBackgroundImageSheet_fitContainLabel: String
    get() = throw MkNotYetPorted("app.MkBackgroundImageSheet.fitContainLabel")
val MkBackgroundImageSheet_removeLabel: String
    get() = throw MkNotYetPorted("app.MkBackgroundImageSheet.removeLabel")
val MkBackgroundImageSheet_noImageExplanation: String
    get() = throw MkNotYetPorted("app.MkBackgroundImageSheet.noImageExplanation")
val MkBackgroundImageSheet_genericFailureText: String
    get() = throw MkNotYetPorted("app.MkBackgroundImageSheet.genericFailureText")
val MkBackgroundImageSheet_ingestFailureText: String
    get() = throw MkNotYetPorted("app.MkBackgroundImageSheet.ingestFailureText")

