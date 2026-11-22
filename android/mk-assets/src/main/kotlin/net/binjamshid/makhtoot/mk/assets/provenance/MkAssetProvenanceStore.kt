package net.binjamshid.makhtoot.mk.assets.provenance

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.assets.model.MkAssetProvenance

data class MkAssetProvenanceStore(
    val records: Map<String, MkAssetProvenance>
) {
    val allRecords: List<MkAssetProvenance>
        get() = throw MkNotYetPorted("mk-assets.MkAssetProvenanceStore.allRecords")
    val count: Int
        get() = throw MkNotYetPorted("mk-assets.MkAssetProvenanceStore.count")
    fun provenance(assetID: String): MkAssetProvenance? { throw MkNotYetPorted("mk-assets.MkAssetProvenanceStore.provenance") }
    companion object {
        val standard: Any? = null
    }
}

object MkAssetProvenanceCodec {
    fun encode(store: MkAssetProvenanceStore): ByteArray { throw MkNotYetPorted("mk-assets.MkAssetProvenanceCodec.encode") }
    fun decode(data: ByteArray): MkAssetProvenanceStore { throw MkNotYetPorted("mk-assets.MkAssetProvenanceCodec.decode") }
}

