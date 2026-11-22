package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

@androidx.compose.runtime.Composable
fun MkMemoryBannerView(viewModel: MkEditorViewModel) { }

@androidx.compose.runtime.Composable
fun MkArrangeErrorBannerView(viewModel: MkEditorViewModel) { }

@androidx.compose.runtime.Composable
fun MkAutosaveIndicatorView(viewModel: MkEditorViewModel) { }
val MkAutosaveIndicatorView_savingText: String
    get() = throw MkNotYetPorted("app.MkAutosaveIndicatorView.savingText")
val MkAutosaveIndicatorView_savedText: String
    get() = throw MkNotYetPorted("app.MkAutosaveIndicatorView.savedText")

