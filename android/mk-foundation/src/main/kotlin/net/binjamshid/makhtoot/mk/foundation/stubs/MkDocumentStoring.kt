package net.binjamshid.makhtoot.mk.foundation.stubs

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkProjectId

/**
 * Minimal open/save hooks so canvas and engine test code can round-trip "a
 * document" before `mk-persistence`'s real `.makhtoot` file-package
 * persistence (D-308) exists. Ports
 * `Sources/MKFoundation/Stubs/MKDocumentStoring.swift`.
 */
interface MkDocumentStoring {
    /** Persists [data] for [id], replacing any previous value. */
    suspend fun save(data: ByteArray, id: MkProjectId)

    /** Loads the most recently saved data for [id], or `null` if none exists yet. */
    suspend fun load(id: MkProjectId): ByteArray?

    /** Removes any stored data for [id]. */
    suspend fun delete(id: MkProjectId)
}

/**
 * In-memory [MkDocumentStoring] conformer: no disk I/O, no crash recovery,
 * nothing survives process exit. `mk-persistence` replaces this. Ports
 * `InMemoryDocumentStore` (a Swift `actor`) — Android's real isolation
 * guarantee (Batch 2) is expected to come from a `Mutex`-guarded map or a
 * confined coroutine dispatcher, a documented mechanical substitution
 * (`ANDROID_SPINE.md` §9): Kotlin has no `actor` language feature.
 */
class MkInMemoryDocumentStore : MkDocumentStoring {
    override suspend fun save(data: ByteArray, id: MkProjectId): Unit =
        throw MkNotYetPorted("MkInMemoryDocumentStore.save")

    override suspend fun load(id: MkProjectId): ByteArray? =
        throw MkNotYetPorted("MkInMemoryDocumentStore.load")

    override suspend fun delete(id: MkProjectId): Unit =
        throw MkNotYetPorted("MkInMemoryDocumentStore.delete")
}
