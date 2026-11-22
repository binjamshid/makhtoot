package net.binjamshid.makhtoot.mk.store.trial

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

interface MkKeyValueStoring {
    fun read(key: String): ByteArray?
    fun write(key: String, value: ByteArray)
    fun delete(key: String)
}

data class MkKeychainStore(
    val service: String
) : MkKeyValueStoring {
    override fun read(key: String): ByteArray? { throw MkNotYetPorted("mk-store.MkKeychainStore.read") }
    override fun write(key: String, value: ByteArray) { throw MkNotYetPorted("mk-store.MkKeychainStore.write") }
    override fun delete(key: String) { throw MkNotYetPorted("mk-store.MkKeychainStore.delete") }
}

class MkInMemoryKeyValueStore(
    val seed: Map<String, ByteArray> = emptyMap()
) : MkKeyValueStoring {
    override fun read(key: String): ByteArray? { throw MkNotYetPorted("mk-store.MkInMemoryKeyValueStore.read") }
    override fun write(key: String, value: ByteArray) { throw MkNotYetPorted("mk-store.MkInMemoryKeyValueStore.write") }
    override fun delete(key: String) { throw MkNotYetPorted("mk-store.MkInMemoryKeyValueStore.delete") }
}

object MkSecureStoreKeys {
    val trialKeychainService: String = "net.binjamshid.makhtoot.trial"
    val trialRecordKey: String = "trial.record"
    val trialKVSKey: String = "trial.record"
    val referralLedgerKeychainService: String = "net.binjamshid.makhtoot.referral"
    val referralLedgerKey: String = "referral.ledger"
}

