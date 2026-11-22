package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkMemoryAccountable
import net.binjamshid.makhtoot.mk.model.MkAssetRef
import net.binjamshid.makhtoot.mk.model.MkNode
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.persistence.MkAssetStore
import net.binjamshid.makhtoot.mk.render.MkAssetProviding

class MkDocumentAssetProvider(
    var cache: Map<MkAssetRef, Any> = emptyMap(),
    val assetStore: MkAssetStore,
    var refs: Set<MkAssetRef> = emptyList()
) : MkAssetProviding, MkMemoryAccountable {
    val image: Any
        get() = throw MkNotYetPorted("app.MkDocumentAssetProvider.image")
    override fun resolveRasterImage(ref: MkAssetRef): Any? { throw MkNotYetPorted("app.MkDocumentAssetProvider.resolveRasterImage") }
    override fun resolvePDFPage(ref: MkAssetRef): CGPDFPage? { throw MkNotYetPorted("app.MkDocumentAssetProvider.resolvePDFPage") }
    fun prime(ref: MkAssetRef, data: ByteArray): Any? { throw MkNotYetPorted("app.MkDocumentAssetProvider.prime") }
    suspend fun primeReachableAssets(scene: MkScene) { throw MkNotYetPorted("app.MkDocumentAssetProvider.primeReachableAssets") }
    fun visit(node: MkNode) { throw MkNotYetPorted("app.MkDocumentAssetProvider.visit") }
    override suspend fun accountedBytes(): Int { throw MkNotYetPorted("app.MkDocumentAssetProvider.accountedBytes") }
    override suspend fun evictOffscreen() { throw MkNotYetPorted("app.MkDocumentAssetProvider.evictOffscreen") }
    override suspend fun evictAll() { throw MkNotYetPorted("app.MkDocumentAssetProvider.evictAll") }
    companion object {
        fun rasterRefs(scene: MkScene): Set<MkAssetRef> { throw MkNotYetPorted("app.MkDocumentAssetProvider.rasterRefs") }
    }
}

