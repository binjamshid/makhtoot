package net.binjamshid.makhtoot.mk.fonts

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

sealed class MkPremiumDelivery {
    data class Hosted(val manifestURL: java.net.URI) : MkPremiumDelivery()
    object BundledFallback : MkPremiumDelivery()
    companion object {
        val placeholderManifestURL: java.net.URI = java.net.URI("https://fonts.example-makhtoot.invalid/catalog-manifest-v1.json")
    }
}

