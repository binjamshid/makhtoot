import Foundation

/// Root error protocol every MakhtootKit module conforms its error types to.
/// Splitting `errorCode` (stable, non-localized, for logs/support) from
/// `arabicUserMessage` (what the user actually sees, `ar`-only per D-100)
/// keeps diagnostics and UI copy from drifting into the same string.
public protocol MKError: Swift.Error, Sendable {
    /// A stable, non-localized code for logs, support conversations, and
    /// crash reports (e.g. `"io.write-failed"`).
    var errorCode: String { get }

    /// The Arabic string to show the user, or `nil` if this error is never
    /// user-facing (e.g. an internal invariant violation surfaced only in
    /// logs). Every non-nil value must be Arabic with a Latin gloss on
    /// first use in the declaring file's doc comments (FOUNDATION §12).
    var arabicUserMessage: String? { get }

    /// The wrapped system/framework error, if any, for diagnostics.
    var underlying: (any Swift.Error)? { get }
}

/// A stable code-range registry so error codes from different modules never
/// collide in logs. Each module reserves a prefix; WS-01 owns the
/// foundation-level prefixes below, later workstreams add their own here or
/// in their own module (as long as the prefix is unique).
public enum MKErrorCode {
    public static let ioPrefix = "io"
    public static let validationPrefix = "validation"
    public static let entitlementPrefix = "entitlement"
}

/// I/O failures: reading/writing project packages, assets, or catalog data.
/// Owner: WS-01 defines the taxonomy; WS-02 (`MKPersistence`) is the primary
/// producer.
public enum MKIOError: MKError {
    /// فشل حفظ الملف (Latin gloss: file save failed)
    case writeFailed(underlying: any Swift.Error)
    /// تعذّرت قراءة الملف (Latin gloss: could not read the file)
    case readFailed(underlying: any Swift.Error)
    /// الملف غير موجود (Latin gloss: the file does not exist)
    case notFound

    public var errorCode: String {
        switch self {
        case .writeFailed: return "\(MKErrorCode.ioPrefix).write-failed"
        case .readFailed: return "\(MKErrorCode.ioPrefix).read-failed"
        case .notFound: return "\(MKErrorCode.ioPrefix).not-found"
        }
    }

    public var arabicUserMessage: String? {
        switch self {
        case .writeFailed: return "فشل حفظ الملف"
        case .readFailed: return "تعذّرت قراءة الملف"
        case .notFound: return "الملف غير موجود"
        }
    }

    public var underlying: (any Swift.Error)? {
        switch self {
        case .writeFailed(let error), .readFailed(let error): return error
        case .notFound: return nil
        }
    }
}

/// Input-validation failures: malformed user input, unsupported file
/// formats, out-of-range numeric fields, etc. Owner: WS-01 defines the
/// taxonomy; individual workstreams (fonts, import, inspector) add cases in
/// their own modules following this pattern.
public enum MKValidationError: MKError {
    /// قيمة غير صالحة (Latin gloss: invalid value)
    case invalidValue(field: String)
    /// صيغة الملف غير مدعومة (Latin gloss: unsupported file format)
    case unsupportedFormat

    public var errorCode: String {
        switch self {
        case .invalidValue: return "\(MKErrorCode.validationPrefix).invalid-value"
        case .unsupportedFormat: return "\(MKErrorCode.validationPrefix).unsupported-format"
        }
    }

    public var arabicUserMessage: String? {
        switch self {
        case .invalidValue: return "قيمة غير صالحة"
        case .unsupportedFormat: return "صيغة الملف غير مدعومة"
        }
    }

    public var underlying: (any Swift.Error)? { nil }
}

/// Entitlement/premium-gating failures. Owner: WS-01 defines the taxonomy
/// (the protocol shape this packet ships); WS-10 (`MKStore`) is the primary
/// producer once the real `MKEntitlementResolver` replaces
/// `StubEntitlementResolver`.
public enum MKEntitlementError: MKError {
    /// هذه الميزة تتطلب الاشتراك المميز (Latin gloss: this feature requires
    /// the premium subscription)
    case notEntitled(capability: MKPremiumCapability)

    public var errorCode: String {
        "\(MKErrorCode.entitlementPrefix).not-entitled"
    }

    public var arabicUserMessage: String? {
        "هذه الميزة تتطلب الاشتراك المميز"
    }

    public var underlying: (any Swift.Error)? { nil }
}
