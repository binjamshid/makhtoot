package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkAffineTransform
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkPlatformFont
import net.binjamshid.makhtoot.mk.model.MkLiveTextNode
import net.binjamshid.makhtoot.mk.model.MkPathTextNode

object MkTextOutlining {
    fun isEmojiCluster(codepoints: List<Long>): Boolean { throw MkNotYetPorted("mk-export.MkTextOutlining.isEmojiCluster") }
    fun emojiGlyphPNGData(ctFont: MkPlatformFont, glyph: CGGlyph, pixelSize: Int = 128): ByteArray? { throw MkNotYetPorted("mk-export.MkTextOutlining.emojiGlyphPNGData") }
    fun outlineLiveText(node: MkLiveTextNode, fonts: MkFontProviding): List<GlyphOutline> { throw MkNotYetPorted("mk-export.MkTextOutlining.outlineLiveText") }
    fun outlinePathText(node: MkPathTextNode, fonts: MkFontProviding): List<GlyphOutline> { throw MkNotYetPorted("mk-export.MkTextOutlining.outlinePathText") }
    fun pathTextHighlightRibbon(node: MkPathTextNode, fonts: MkFontProviding): Any? { throw MkNotYetPorted("mk-export.MkTextOutlining.pathTextHighlightRibbon") }
    data class GlyphOutline(
        var path: Any,
        var localTransform: MkAffineTransform,
        var codepoints: List<Long>,
        var fontPostScriptName: String,
        var ctFont: MkPlatformFont,
        var glyphID: CGGlyph,
        var isColorGlyph: Boolean
    )
}

