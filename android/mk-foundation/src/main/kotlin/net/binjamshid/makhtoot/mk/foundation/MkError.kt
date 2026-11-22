package net.binjamshid.makhtoot.mk.foundation

/**
 * Root error interface every MakhtootKit module conforms its error types to.
 * Ports `Sources/MKFoundation/MKError.swift`.
 */
interface MkError {
    /** A stable, non-localized code for logs, support conversations, and crash reports. */
    val errorCode: String

    /** The Arabic string to show the user, or `null` if this error is never user-facing. */
    val arabicUserMessage: String?

    /** The wrapped system/framework error, if any, for diagnostics. */
    val underlying: Throwable?
}

/**
 * A stable code-range registry so error codes from different modules never
 * collide in logs.
 */
object MkErrorCode {
    const val ioPrefix: String = "io"
    const val validationPrefix: String = "validation"
    const val entitlementPrefix: String = "entitlement"
}

/**
 * I/O failures: reading/writing project packages, assets, or catalog data.
 * Ports `MKIOError`. Associated-value field renamed `wrappedError` (was
 * `underlying` in Swift) to avoid colliding with the [MkError.underlying]
 * interface member name — documented mechanical deviation
 * (`ANDROID_SPINE.md` §9).
 */
sealed class MkIoError : Exception(), MkError {
    /** فشل حفظ الملف (Latin gloss: file save failed) */
    data class WriteFailed(val wrappedError: Throwable) : MkIoError()

    /** تعذّرت قراءة الملف (Latin gloss: could not read the file) */
    data class ReadFailed(val wrappedError: Throwable) : MkIoError()

    /** الملف غير موجود (Latin gloss: the file does not exist) */
    object NotFound : MkIoError()

    override val errorCode: String
        get() = throw MkNotYetPorted("MkIoError.errorCode")
    override val arabicUserMessage: String?
        get() = throw MkNotYetPorted("MkIoError.arabicUserMessage")
    override val underlying: Throwable?
        get() = throw MkNotYetPorted("MkIoError.underlying")
}

/**
 * Input-validation failures: malformed user input, unsupported file formats,
 * out-of-range numeric fields, etc. Ports `MKValidationError`.
 */
sealed class MkValidationError : Exception(), MkError {
    /** قيمة غير صالحة (Latin gloss: invalid value) */
    data class InvalidValue(val field: String) : MkValidationError()

    /** صيغة الملف غير مدعومة (Latin gloss: unsupported file format) */
    object UnsupportedFormat : MkValidationError()

    override val errorCode: String
        get() = throw MkNotYetPorted("MkValidationError.errorCode")
    override val arabicUserMessage: String?
        get() = throw MkNotYetPorted("MkValidationError.arabicUserMessage")
    override val underlying: Throwable?
        get() = throw MkNotYetPorted("MkValidationError.underlying")
}

/**
 * Entitlement/premium-gating failures. Ports `MKEntitlementError`.
 */
sealed class MkEntitlementError : Exception(), MkError {
    /**
     * هذه الميزة تتطلب الاشتراك المميز (Latin gloss: this feature requires the
     * premium subscription)
     */
    data class NotEntitled(
        val capability: net.binjamshid.makhtoot.mk.foundation.entitlement.MkPremiumCapability,
    ) : MkEntitlementError()

    override val errorCode: String
        get() = throw MkNotYetPorted("MkEntitlementError.errorCode")
    override val arabicUserMessage: String?
        get() = throw MkNotYetPorted("MkEntitlementError.arabicUserMessage")
    override val underlying: Throwable?
        get() = throw MkNotYetPorted("MkEntitlementError.underlying")
}
