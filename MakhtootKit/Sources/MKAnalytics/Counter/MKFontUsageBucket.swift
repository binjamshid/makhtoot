import Foundation

/// Coarsened usage bucket applied at upload time (D-125 "counts bucketed"):
/// raw weekly counts → one of five intervals. The raw count never leaves
/// the device ، only the bucket label is included in the uploaded payload.
///
/// Bucket boundaries (T2/WS-12-A2 ADR): chosen to be coarse enough that
/// a bucket value alone cannot re-identify a specific user's workflow
/// while still being useful for aggregate popularity inference at the
/// fleet level.
public enum MKFontUsageBucket: String, Codable, Sendable, Equatable {
    /// 1–4 uses in the week.
    case low     = "1-4"
    /// 5–9 uses in the week.
    case medium  = "5-9"
    /// 10–24 uses in the week.
    case high    = "10-24"
    /// 25–49 uses in the week.
    case veryHigh = "25-49"
    /// 50 or more uses in the week.
    case intense  = "50+"

    /// Derive a bucket from a raw weekly count. T2 AC: bucketing table test.
    public static func bucket(for count: Int) -> MKFontUsageBucket {
        switch count {
        case 1...4:   return .low
        case 5...9:   return .medium
        case 10...24: return .high
        case 25...49: return .veryHigh
        default:      return count > 0 ? .intense : .low
        }
    }
}
