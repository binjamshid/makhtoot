package net.binjamshid.makhtoot.mk.canvas

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.geometry.MkTransform2D
import net.binjamshid.makhtoot.mk.model.MkAssetRef
import net.binjamshid.makhtoot.mk.model.MkBackgroundImageFit
import net.binjamshid.makhtoot.mk.model.MkFill
import net.binjamshid.makhtoot.mk.model.MkFontRef
import net.binjamshid.makhtoot.mk.model.MkLigatureSetting
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.model.MkShadow
import net.binjamshid.makhtoot.mk.model.MkSolidColor
import net.binjamshid.makhtoot.mk.model.MkStroke
import net.binjamshid.makhtoot.mk.model.MkTextStyle

class MkInspectorModel(
    val session: MkCanvasSession
) {
    val positionValue: Value<MkPoint>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.positionValue")
    val rotationDegreesValue: Value<Double>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.rotationDegreesValue")
    val opacityValue: Value<Double>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.opacityValue")
    val sizeValue: Value<MkSize>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.sizeValue")
    val fillValue: Value<MkFill>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.fillValue")
    val strokeValue: Value<MkStroke?>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.strokeValue")
    val shadowValue: Value<MkShadow?>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.shadowValue")
    val textStyleValue: Value<MkTextStyle>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.textStyleValue")
    val fontRefValue: Value<MkFontRef>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.fontRefValue")
    val highlightColorValue: Value<MkFill>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.highlightColorValue")
    val backgroundColorValue: MkSolidColor
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.backgroundColorValue")
    val backgroundImageRef: MkAssetRef?
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.backgroundImageRef")
    val backgroundImageFitValue: MkBackgroundImageFit?
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.backgroundImageFitValue")
    val pointSizeValue: Value<Double>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.pointSizeValue")
    val isBoldValue: Value<Boolean>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.isBoldValue")
    val isItalicValue: Value<Boolean>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.isItalicValue")
    val isUnderlineValue: Value<Boolean>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.isUnderlineValue")
    val isStrikethroughValue: Value<Boolean>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.isStrikethroughValue")
    val trackingValue: Value<Double>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.trackingValue")
    val baselineShiftValue: Value<Double>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.baselineShiftValue")
    val lineHeightMultipleValue: Value<Double>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.lineHeightMultipleValue")
    val ligatureSettingValue: Value<MkLigatureSetting>
        get() = throw MkNotYetPorted("mk-canvas.MkInspectorModel.ligatureSettingValue")
    fun beginEdit() { throw MkNotYetPorted("mk-canvas.MkInspectorModel.beginEdit") }
    fun endEdit() { throw MkNotYetPorted("mk-canvas.MkInspectorModel.endEdit") }
    fun setPosition(newPosition: MkPoint) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setPosition") }
    fun setRotationDegrees(degrees: Double) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setRotationDegrees") }
    fun setOpacity(value: Double) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setOpacity") }
    fun setFill(fill: MkFill) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setFill") }
    fun setStroke(stroke: MkStroke?) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setStroke") }
    fun setShadow(shadow: MkShadow?) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setShadow") }
    fun setHighlightColor(color: MkSolidColor?) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setHighlightColor") }
    fun setBackgroundColor(color: MkSolidColor) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setBackgroundColor") }
    fun setBackgroundImage(ref: MkAssetRef, fit: MkBackgroundImageFit = MkBackgroundImageFit.COVER) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setBackgroundImage") }
    fun setBackgroundImageFit(fit: MkBackgroundImageFit) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setBackgroundImageFit") }
    fun removeBackgroundImage(fallback: MkSolidColor? = null) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.removeBackgroundImage") }
    fun setFont(fontRef: MkFontRef) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setFont") }
    fun setPointSize(size: Double) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setPointSize") }
    fun setBold(isBold: Boolean) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setBold") }
    fun setItalic(isItalic: Boolean) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setItalic") }
    fun setUnderline(isUnderline: Boolean) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setUnderline") }
    fun setStrikethrough(isStrikethrough: Boolean) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setStrikethrough") }
    fun setTracking(tracking: Double) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setTracking") }
    fun setBaselineShift(baselineShift: Double) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setBaselineShift") }
    fun setLineHeightMultiple(lineHeightMultiple: Double) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setLineHeightMultiple") }
    fun setSize(newWidth: Double?, newHeight: Double?) { throw MkNotYetPorted("mk-canvas.MkInspectorModel.setSize") }
    companion object {
        fun worldTransform(id: MkNodeId, scene: MkScene): MkTransform2D? { throw MkNotYetPorted("mk-canvas.MkInspectorModel.worldTransform") }
    }
    sealed class Value<T: Equatable> {
        data class Uniform(val arg0: T) : Value()
        object Mixed : Value()
        object Empty : Value()
    }
}

