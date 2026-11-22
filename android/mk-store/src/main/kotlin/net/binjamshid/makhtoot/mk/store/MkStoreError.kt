package net.binjamshid.makhtoot.mk.store

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

sealed class MkStoreError : Exception() {
    object FailedVerification : MkStoreError()
    data class PurchaseFailed(val underlying: String) : MkStoreError()
    object CatalogUnavailable : MkStoreError()
    data class RestoreFailed(val underlying: String) : MkStoreError()
    object PendingApproval : MkStoreError()
    object NetworkRequired : MkStoreError()
    val errorDescription: String?
        get() = throw MkNotYetPorted("mk-store.MkStoreError.errorDescription")
}

