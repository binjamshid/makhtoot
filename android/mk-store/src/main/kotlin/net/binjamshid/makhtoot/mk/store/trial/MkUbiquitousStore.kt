package net.binjamshid.makhtoot.mk.store.trial

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkUbiquitousStore(
    val store: Any? = null
) : MkKeyValueStoring {
    override fun read(key: String): ByteArray? { throw MkNotYetPorted("mk-store.MkUbiquitousStore.read") }
    override fun write(key: String, value: ByteArray) { throw MkNotYetPorted("mk-store.MkUbiquitousStore.write") }
    override fun delete(key: String) { throw MkNotYetPorted("mk-store.MkUbiquitousStore.delete") }
    fun changeNotifications(): kotlinx.coroutines.flow.Flow<Unit> { throw MkNotYetPorted("mk-store.MkUbiquitousStore.changeNotifications") }
}

