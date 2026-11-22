package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.MkInspectorModel
import net.binjamshid.makhtoot.mk.color.MkColorSpec
import net.binjamshid.makhtoot.mk.color.MkIccProfileStore
import net.binjamshid.makhtoot.mk.fonts.MkFontRecord
import net.binjamshid.makhtoot.mk.fonts.MkFontRegistry
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkSolidColor
import net.binjamshid.makhtoot.mk.fonts.MkFontId

@androidx.compose.runtime.Composable
fun MkFontSettingsSheet(inspector: MkInspectorModel, fontRegistry: MkFontRegistry, sampleText: String, showFontBrowser: Boolean = false, showTextColorPicker: Boolean = false, showHighlightColorPicker: Boolean = false, showsFontManagement: Boolean = false, selectedFontRecord: MkFontRecord? = null, sizePresets: List<Double> = listOf(9, 12, 14, 16, 18, 24, 36, 48, 60, 72, 96, 144, 200), traitGlyphSize: Double = 16.0, clearHighlightIconSize: Double = 20.0, colorToolIconSize: Double = 18.0, initial: Any? = null, clamped: Any? = null, inside: Any? = null, ink: Any? = null) { }
fun MkFontSettingsSheet_variableAxisTags(filename: String): Set<Substring> { throw MkNotYetPorted("app.MkFontSettingsSheet.variableAxisTags") }
@androidx.compose.runtime.Composable
fun MkFontSettingsSheet_traitButton(label: String, isOn: Boolean, supported: Boolean = true, action: () -> Unit) { }
val MkFontSettingsSheet_currentPointSize: Double
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.currentPointSize")
val MkFontSettingsSheet_currentFontID: MkFontId?
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.currentFontID")
val MkFontSettingsSheet_isBold: Boolean
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.isBold")
val MkFontSettingsSheet_isItalic: Boolean
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.isItalic")
val MkFontSettingsSheet_isUnderline: Boolean
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.isUnderline")
val MkFontSettingsSheet_isStrikethrough: Boolean
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.isStrikethrough")
val MkFontSettingsSheet_hasSelection: Boolean
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.hasSelection")
val MkFontSettingsSheet_currentID: String?
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.currentID")
@androidx.compose.runtime.Composable
fun MkFontSettingsSheet_sizeRow() { }
@androidx.compose.runtime.Composable
fun MkFontSettingsSheet_traitsRow() { }
val MkFontSettingsSheet_boldSupported: Boolean
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.boldSupported")
val MkFontSettingsSheet_italicSupported: Boolean
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.italicSupported")
@androidx.compose.runtime.Composable
fun MkFontSettingsSheet_traitsUnsupportedExplanation() { }
val MkFontSettingsSheet_currentTextColor: (red: Double, green: Double, blue: Double, alpha: Double)
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.currentTextColor")
@androidx.compose.runtime.Composable
fun MkFontSettingsSheet_textColorRow() { }
val MkFontSettingsSheet_currentHighlightColor: (red: Double, green: Double, blue: Double, alpha: Double)?
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.currentHighlightColor")
val MkFontSettingsSheet_hasHighlight: Boolean
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.hasHighlight")
@androidx.compose.runtime.Composable
fun MkFontSettingsSheet_highlightColorRow() { }
@androidx.compose.runtime.Composable
fun MkFontSettingsSheet_fontRow() { }
@androidx.compose.runtime.Composable
fun MkFontSettingsSheet_fontValueText() { }
@androidx.compose.runtime.Composable
fun MkFontSettingsSheet_emptySelectionView() { }
val MkFontSettingsSheet_emptySelectionText: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.emptySelectionText")
val MkFontSettingsSheet_titleLabel: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.titleLabel")
val MkFontSettingsSheet_doneLabel: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.doneLabel")
val MkFontSettingsSheet_sizeLabel: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.sizeLabel")
val MkFontSettingsSheet_traitsLabel: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.traitsLabel")
val MkFontSettingsSheet_boldUnsupportedText: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.boldUnsupportedText")
val MkFontSettingsSheet_italicUnsupportedText: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.italicUnsupportedText")
val MkFontSettingsSheet_fontLabel: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.fontLabel")
val MkFontSettingsSheet_textColorLabel: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.textColorLabel")
val MkFontSettingsSheet_textColorValueLabel: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.textColorValueLabel")
val MkFontSettingsSheet_highlightLabel: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.highlightLabel")
val MkFontSettingsSheet_highlightValueLabel: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.highlightValueLabel")
val MkFontSettingsSheet_noHighlightLabel: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.noHighlightLabel")
val MkFontSettingsSheet_clearHighlightLabel: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.clearHighlightLabel")
val MkFontSettingsSheet_mixedLabel: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.mixedLabel")
val MkFontSettingsSheet_manageFontsLabel: String
    get() = throw MkNotYetPorted("app.MkFontSettingsSheet.manageFontsLabel")

@androidx.compose.runtime.Composable
fun MkColorPickerSheet(colorToolIconSize: Double = 18.0, title: String, initialColor: (red: Double, green: Double, blue: Double, alpha: Double), onSelect: ((red: Double, green: Double, blue: Double, alpha: Double)) -> Unit, hue: Double, saturation: Double, brightness: Double, alpha: Double, activeTab: Tab? = null, favourites: List<MkSolidColor> = emptyList(), showEyedropper: Boolean = false, seed: Any? = null, hsba: Any? = null, spec: Any = currentSpec, ci: Any? = null, sampled: Any? = null, color: Any? = null, updated: Any? = null, cleaned: Any? = null, r: Any? = null, g: Any? = null, b: Any? = null, profile: MkIccProfileStore.loadBundled = MkIccProfileStore.loadBundled()) { }
@androidx.compose.runtime.Composable
fun MkColorPickerSheet_labeledStrip<Content: View>(label: String, content: () -> Any) { }
fun MkColorPickerSheet_addCurrentToFavourites() { throw MkNotYetPorted("app.MkColorPickerSheet.addCurrentToFavourites") }
fun MkColorPickerSheet_removeFavourite(index: Int) { throw MkNotYetPorted("app.MkColorPickerSheet.removeFavourite") }
fun MkColorPickerSheet_applyFavourite(color: MkSolidColor) { throw MkNotYetPorted("app.MkColorPickerSheet.applyFavourite") }
fun MkColorPickerSheet_setChannel(r: Double? = null, g: Double? = null, b: Double? = null) { throw MkNotYetPorted("app.MkColorPickerSheet.setChannel") }
fun MkColorPickerSheet_byte(v: Double): Int { throw MkNotYetPorted("app.MkColorPickerSheet.byte") }
fun MkColorPickerSheet_commitHex(text: String) { throw MkNotYetPorted("app.MkColorPickerSheet.commitHex") }
fun MkColorPickerSheet_pct(v: Double): String { throw MkNotYetPorted("app.MkColorPickerSheet.pct") }
val MkColorPickerSheet_currentSpec: MkColorSpec
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.currentSpec")
val MkColorPickerSheet_currentColor: androidx.compose.ui.graphics.Color
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.currentColor")
@androidx.compose.runtime.Composable
fun MkColorPickerSheet_previewRow() { }
@androidx.compose.runtime.Composable
fun MkColorPickerSheet_tabSelector() { }
@androidx.compose.runtime.Composable
fun MkColorPickerSheet_customTabContent() { }
@androidx.compose.runtime.Composable
fun MkColorPickerSheet_favouritesTabContent() { }
val MkColorPickerSheet_redBinding: androidx.compose.runtime.MutableState<Double>
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.redBinding")
val MkColorPickerSheet_greenBinding: androidx.compose.runtime.MutableState<Double>
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.greenBinding")
val MkColorPickerSheet_blueBinding: androidx.compose.runtime.MutableState<Double>
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.blueBinding")
val MkColorPickerSheet_alphaPercentBinding: androidx.compose.runtime.MutableState<Double>
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.alphaPercentBinding")
val MkColorPickerSheet_hexString: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.hexString")
val MkColorPickerSheet_cmykPreviewText: String?
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.cmykPreviewText")
val MkColorPickerSheet_hueLabel: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.hueLabel")
val MkColorPickerSheet_alphaLabel: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.alphaLabel")
val MkColorPickerSheet_cancelLabel: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.cancelLabel")
val MkColorPickerSheet_selectLabel: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.selectLabel")
val MkColorPickerSheet_customTabLabel: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.customTabLabel")
val MkColorPickerSheet_favouritesTabLabel: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.favouritesTabLabel")
val MkColorPickerSheet_noFavouritesText: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.noFavouritesText")
val MkColorPickerSheet_eyedropperLabel: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.eyedropperLabel")
val MkColorPickerSheet_addFavouriteLabel: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.addFavouriteLabel")
val MkColorPickerSheet_deleteFavouriteLabel: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.deleteFavouriteLabel")
val MkColorPickerSheet_redLabel: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.redLabel")
val MkColorPickerSheet_greenLabel: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.greenLabel")
val MkColorPickerSheet_blueLabel: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.blueLabel")
val MkColorPickerSheet_alphaPercentLabel: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.alphaPercentLabel")
val MkColorPickerSheet_cmykLabel: String
    get() = throw MkNotYetPorted("app.MkColorPickerSheet.cmykLabel")

@androidx.compose.runtime.Composable
fun MkSaturationBrightnessSquare(hue: Double, saturation: Double, brightness: Double, cornerRadius: Double, x: Any? = null, y: Any? = null) { }
@androidx.compose.runtime.Composable
fun MkSaturationBrightnessSquare_thumb(size: MkSize) { }
fun MkSaturationBrightnessSquare_update(location: MkPoint, size: MkSize) { throw MkNotYetPorted("app.MkSaturationBrightnessSquare.update") }

@androidx.compose.runtime.Composable
fun MkHueStrip(hue: Double, cornerRadius: Double) { }
@androidx.compose.runtime.Composable
fun MkHueStrip_thumbFill(geo: GeometryProxy) { }

@androidx.compose.runtime.Composable
fun MkAlphaStrip(hue: Double, saturation: Double, brightness: Double, alpha: Double, cornerRadius: Double) { }
@androidx.compose.runtime.Composable
fun MkAlphaStrip_thumbFill(geo: GeometryProxy) { }
val MkAlphaStrip_opaqueColor: androidx.compose.ui.graphics.Color
    get() = throw MkNotYetPorted("app.MkAlphaStrip.opaqueColor")

@androidx.compose.runtime.Composable
fun MkCheckerboardPattern(cell: Double = 6.0, row: Int = 0, y: Double = 0.0, col: Int = 0, x: Double = 0.0, isLight: Any? = null) { }

@androidx.compose.runtime.Composable
fun MkHexColorField(value: String, onCommit: (String) -> Unit, text: String = "", isFocused: Boolean) { }
val MkHexColorField_hexLabel: String
    get() = throw MkNotYetPorted("app.MkHexColorField.hexLabel")

data class MkSystemEyedropperView(
    val initial: UIColor,
    val onPick: (UIColor) -> Unit,
    val controller: UIColorPickerViewController = UIColorPickerViewController()
) : UIViewControllerRepresentable {
    fun makeUIViewController(context: Context): UIColorPickerViewController { throw MkNotYetPorted("app.MkSystemEyedropperView.makeUIViewController") }
    fun updateUIViewController(uiViewController: UIColorPickerViewController, context: Context) { throw MkNotYetPorted("app.MkSystemEyedropperView.updateUIViewController") }
    fun makeCoordinator(): Coordinator { throw MkNotYetPorted("app.MkSystemEyedropperView.makeCoordinator") }
    class Coordinator(
        val onPick: (UIColor) -> Unit
    ) : Any, UIColorPickerViewControllerDelegate {
        fun colorPickerViewControllerDidFinish(viewController: UIColorPickerViewController) { throw MkNotYetPorted("app.Coordinator.colorPickerViewControllerDidFinish") }
        fun colorPickerViewController(viewController: UIColorPickerViewController, color: UIColor, continuously: Boolean) { throw MkNotYetPorted("app.Coordinator.colorPickerViewController") }
    }
}

object MkColorFavouritesStore {
    val key: String = "mk.colorPicker.favourites.v1"
    fun load(): List<MkSolidColor> { throw MkNotYetPorted("app.MkColorFavouritesStore.load") }
    fun save(colors: List<MkSolidColor>) { throw MkNotYetPorted("app.MkColorFavouritesStore.save") }
}

