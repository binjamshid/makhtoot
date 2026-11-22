package net.binjamshid.makhtoot.mk.export

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.model.MkLiveTextNode

object MkSvgTextWriter {
    fun renderLiveText(node: MkLiveTextNode, fonts: MkFontProviding, fontData: MkExportFontDataProviding, fontLicense: MkFontLicenseProviding, indent: String): Triple<String, String?, MkFallbackNote?> { throw MkNotYetPorted("mk-export.MkSvgTextWriter.renderLiveText") }
}

