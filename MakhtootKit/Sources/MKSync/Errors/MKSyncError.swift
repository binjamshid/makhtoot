import CloudKit
import Foundation
import MKFoundation

// T10 ، Quota & error taxonomy. Every CloudKit error that can reach the
// user is mapped here to an `MKSyncError` case with an Arabic message and
// a recovery action. The mapping from `CKError` is a pure function
// (`MKSyncErrorMapper.map`) so it can be tested without a live CKSyncEngine.

/// Errors produced by the sync engine that are surfaced to the UI layer
/// (WS-12 settings, WS-13 project browser badges).
///
/// Cases carry Arabic user-facing messages via `localizedMessage`.
/// Recovery actions are suggestions rendered by WS-12's UI; MKSync itself
/// takes no destructive action without explicit user consent.
public enum MKSyncError: Error, Sendable, Equatable {
    /// iCloud storage quota exceeded. User must free space or disable
    /// large-project sync.
    case quotaExceeded
    /// No network connection; engine will retry silently when reachable.
    case networkUnavailable
    /// A single asset exceeds the practical upload threshold (advisory ،
    /// sync still attempts). Carries the project title for UI display.
    case assetTooLarge(projectTitle: String)
    /// The sync zone was deleted on the server (e.g. "Reset iCloud").
    /// Engine recreates the zone and triggers a full re-upload.
    case zoneNotFound
    /// CloudKit server rejected the record for an unexpected reason.
    case serverRejected
    /// Insufficient CloudKit permissions (e.g. iCloud Drive disabled).
    case permissionFailure
    /// Account unavailable (signed out, restricted, or temporarily offline).
    case accountUnavailable
    /// Server requested a retry delay. `retryAfter` is in seconds.
    case throttled(retryAfter: TimeInterval)
    /// An error we received but didn't recognise; carries the raw CKError code.
    case unknown(code: Int)

    // MARK: - Arabic user-facing messages (T10)

    /// Arabic message for the end user. Must be RTL-safe (no embedded LTR
    /// numerals ، uses Arabic-Indic where a number is required).
    public var localizedMessage: String {
        switch self {
        case .quotaExceeded:
            return "مساحة iCloud ممتلئة ، أفرغ مساحة أو عطّل مزامنة المشاريع الكبيرة"
        case .networkUnavailable:
            return "لا يوجد اتصال بالإنترنت ، ستُستأنف المزامنة عند توفّر الشبكة"
        case .assetTooLarge(let title):
            // N8-2: project titles may carry Latin-script runs ، FSI/PDI-
            // isolate the interpolation so a Latin title cannot reorder
            // the «» quotes or the Arabic sentence around it.
            return "المشروع «\(MKRTLUtilities.isolated(title))» يحتوي على ملفات كبيرة ، تجري المزامنة لكن قد تستغرق وقتًا أطول"
        case .zoneNotFound:
            return "تمت إعادة تعيين بيانات iCloud ، جارٍ إعادة رفع المشاريع"
        case .serverRejected:
            return "رفض خادم iCloud الطلب ، يُرجى المحاولة لاحقًا"
        case .permissionFailure:
            return "تحقّق من إعدادات iCloud وتأكّد من تفعيل iCloud Drive"
        case .accountUnavailable:
            return "سجّل الدخول إلى iCloud من الإعدادات لتفعيل المزامنة"
        case .throttled:
            return "يُحدّد iCloud سرعة المزامنة مؤقتًا ، ستُستأنف تلقائيًا"
        case .unknown:
            return "حدث خطأ غير متوقع في المزامنة ، يُرجى المحاولة لاحقًا"
        }
    }

    /// Suggested recovery action for the UI layer to render as a button or link.
    public var recoveryAction: MKSyncRecoveryAction {
        switch self {
        case .quotaExceeded: return .openICloudSettings
        case .permissionFailure: return .openICloudSettings
        case .accountUnavailable: return .openICloudSettings
        case .assetTooLarge: return .none
        case .networkUnavailable: return .none
        case .zoneNotFound: return .none
        case .serverRejected: return .none
        case .throttled: return .none
        case .unknown: return .none
        }
    }
}

/// Recovery actions the UI can offer alongside a `MKSyncError`.
public enum MKSyncRecoveryAction: Sendable, Equatable {
    /// Open the Settings → Apple Account → iCloud panel.
    case openICloudSettings
    /// No specific action; dismiss only.
    case none
}

// MARK: - CKError → MKSyncError mapping (T10)

/// Pure-function CKError → MKSyncError mapper. A free enum (not a type
/// method) so the mapping can be tested without any live CloudKit machinery.
public enum MKSyncErrorMapper {
    /// Maps a CloudKit error to the closest `MKSyncError` case.
    /// - Parameters:
    ///   - error: Any `Error`; if not a `CKError` returns `.unknown(code: -1)`.
    ///   - projectTitle: Used to fill `.assetTooLarge`'s associated value.
    public static func map(_ error: Error, projectTitle: String = "") -> MKSyncError {
        guard let ckError = error as? CKError else { return .unknown(code: -1) }
        return mapCKError(ckError, projectTitle: projectTitle)
    }

    static func mapCKError(_ ckError: CKError, projectTitle: String) -> MKSyncError {
        switch ckError.code {
        case .quotaExceeded:
            return .quotaExceeded
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .assetFileNotFound, .assetFileModified:
            return .assetTooLarge(projectTitle: projectTitle)
        case .zoneNotFound:
            return .zoneNotFound
        case .serverRejectedRequest:
            return .serverRejected
        case .permissionFailure:
            return .permissionFailure
        case .notAuthenticated:
            return .accountUnavailable
        case .serviceUnavailable, .requestRateLimited:
            let retryAfter = (ckError.userInfo[CKErrorRetryAfterKey] as? NSNumber)?.doubleValue ?? 30
            return .throttled(retryAfter: retryAfter)
        case .zoneBusy:
            let retryAfter = (ckError.userInfo[CKErrorRetryAfterKey] as? NSNumber)?.doubleValue ?? 5
            return .throttled(retryAfter: retryAfter)
        case .partialFailure:
            // Drill into the partial errors; return the first mappable one.
            if let partials = ckError.partialErrorsByItemID {
                for (_, subError) in partials {
                    let mapped = map(subError, projectTitle: projectTitle)
                    if mapped != .unknown(code: -1) { return mapped }
                }
            }
            return .serverRejected
        default:
            return .unknown(code: ckError.code.rawValue)
        }
    }
}
