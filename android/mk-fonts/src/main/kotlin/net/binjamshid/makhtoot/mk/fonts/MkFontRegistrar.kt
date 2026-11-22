package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontHandle
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontVariantRequest
import net.binjamshid.makhtoot.mk.foundation.stubs.MkPlatformFont

data class MkFontRegistrar(
    val registry: MkFontRegistry
) {
    suspend fun registerBundledFontsAtLaunch(): List<MkFontId> { throw MkNotYetPorted("mk-fonts.MkFontRegistrar.registerBundledFontsAtLaunch") }
}

class MkRegistryFontProvider : MkFontProviding {
    override fun resolve(handle: MkFontHandle): MkPlatformFont { throw MkNotYetPorted("mk-fonts.MkRegistryFontProvider.resolve") }
    override fun resolve(handle: MkFontHandle, variant: MkFontVariantRequest): MkPlatformFont { throw MkNotYetPorted("mk-fonts.MkRegistryFontProvider.resolve") }
}

