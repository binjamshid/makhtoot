import Foundation
import MKFoundation

/// T19 ، the complete `MKFonts` error taxonomy. Conforms to the repo-wide
/// `MKError` protocol (`MKFoundation/MKError.swift`: `errorCode` +
/// `arabicUserMessage` + `underlying`) ، every case has a non-nil Arabic
/// message (exhaustive switch test in `MKFontErrorTests`). Also conforms to
/// `LocalizedError` (T19's own literal request) by forwarding
/// `errorDescription` to `arabicUserMessage`, so SwiftUI/Foundation call
/// sites that only know about `LocalizedError` still surface the right
/// string.
public enum MKFontError: MKError {
    case premiumRequired
    case unknownFont(fontID: MKFontID)
    case checksumMismatch
    case offline
    case unsupportedFormat(detected: String)
    case corruptFile
    case fontLocked(fontID: MKFontID)
    case registrationFailed(underlying: (any Swift.Error)?)
    case licenseRecordMissing(fontID: MKFontID)

    public var errorCode: String {
        switch self {
        case .premiumRequired: return "fonts.premium-required"
        case .unknownFont: return "fonts.unknown-font"
        case .checksumMismatch: return "fonts.checksum-mismatch"
        case .offline: return "fonts.offline"
        case .unsupportedFormat: return "fonts.unsupported-format"
        case .corruptFile: return "fonts.corrupt-file"
        case .fontLocked: return "fonts.font-locked"
        case .registrationFailed: return "fonts.registration-failed"
        case .licenseRecordMissing: return "fonts.license-record-missing"
        }
    }

    public var arabicUserMessage: String? {
        switch self {
        case .premiumRequired:
            // Latin gloss: this font requires the premium subscription
            return "هذا الخط يتطلب الاشتراك المميز"
        case .unknownFont:
            // Latin gloss: font not found in the catalog
            return "الخط غير موجود في القائمة"
        case .checksumMismatch:
            // Latin gloss: font integrity check failed
            return "فشل التحقق من سلامة الخط"
        case .offline:
            // Latin gloss: no internet connection ، premium fonts require a connection to download
            return "لا يتوفر اتصال بالإنترنت ، الخطوط المميزة تتطلب اتصالًا للتنزيل"
        case .unsupportedFormat(let detected):
            if detected.lowercased().contains("woff") {
                // Latin gloss: WOFF format is not supported ، use TTF or OTF
                return "صيغة WOFF غير مدعومة ، استخدم TTF أو OTF"
            }
            // Latin gloss: this font format is not supported
            return "صيغة هذا الخط غير مدعومة"
        case .corruptFile:
            // Latin gloss: the font file is corrupt or incomplete
            return "ملف الخط تالف أو غير مكتمل"
        case .fontLocked:
            // Latin gloss: this font is locked ، subscribe to unlock it
            return "هذا الخط مُقفل ، اشترك لإلغاء القفل"
        case .registrationFailed:
            // Latin gloss: font registration failed
            return "فشل تسجيل الخط"
        case .licenseRecordMissing:
            // Latin gloss: no license record found for this font
            return "لا يوجد سجل ترخيص لهذا الخط"
        }
    }

    public var underlying: (any Swift.Error)? {
        switch self {
        case .registrationFailed(let underlying): return underlying
        default: return nil
        }
    }
}

extension MKFontError: LocalizedError {
    public var errorDescription: String? { arabicUserMessage }
}
