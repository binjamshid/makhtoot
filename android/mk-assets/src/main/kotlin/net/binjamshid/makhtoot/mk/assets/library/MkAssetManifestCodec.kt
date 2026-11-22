package net.binjamshid.makhtoot.mk.assets.library

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.assets.model.MkAssetDescriptor
import net.binjamshid.makhtoot.mk.assets.provenance.MkAssetProvenanceStore

object MkAssetManifestCodec {
    fun encode(descriptors: List<MkAssetDescriptor>): ByteArray { throw MkNotYetPorted("mk-assets.MkAssetManifestCodec.encode") }
    fun decode(data: ByteArray): List<MkAssetDescriptor> { throw MkNotYetPorted("mk-assets.MkAssetManifestCodec.decode") }
    fun loadBundledManifest(): List<MkAssetDescriptor> { throw MkNotYetPorted("mk-assets.MkAssetManifestCodec.loadBundledManifest") }
    fun loadBundledProvenanceRecords(): MkAssetProvenanceStore { throw MkNotYetPorted("mk-assets.MkAssetManifestCodec.loadBundledProvenanceRecords") }
}

sealed class MkAssetManifestError : Exception() {
    data class ResourceNotFound(val arg0: String) : MkAssetManifestError()
}

object MkAssetManifestGenerator {
    fun resourcesDirectory(): java.net.URI { throw MkNotYetPorted("mk-assets.MkAssetManifestGenerator.resourcesDirectory") }
    fun regenerate(): Pair<java.net.URI, java.net.URI> { throw MkNotYetPorted("mk-assets.MkAssetManifestGenerator.regenerate") }
}

