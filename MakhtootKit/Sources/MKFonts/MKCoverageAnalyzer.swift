import CoreText
import Foundation

/// T10 ، per-font Unicode-range coverage, derived from `CTFontCopyCharacterSet`.
/// Ranges match the packet's exact list. Presentation-Forms coverage is
/// informational only (D-103: never used to select rendering path).
public struct MKCoverageAnalyzer: Sendable {
    public init() {}

    public struct RangeCoverage: Sendable, Hashable {
        public var rangeName: String
        public var coveredCount: Int
        public var totalCount: Int
        public var percentage: Double
    }

    public func analyze(_ font: CTFont) -> MKCoverageReport {
        guard let charSet = CTFontCopyCharacterSet(font) as CFCharacterSet? else {
            return MKCoverageReport(ranges: [], supportsTashkeel: false, supportsQuranicMarks: false, supportsLatin: false)
        }
        let ranges = Self.definedRanges.map { def -> RangeCoverage in
            let covered = def.scalars.filter { charSet.hasMember(inPlane: $0) }.count
            let total = def.scalars.count
            return RangeCoverage(
                rangeName: def.name, coveredCount: covered, totalCount: total,
                percentage: total == 0 ? 0 : Double(covered) / Double(total) * 100
            )
        }
        func percent(_ name: String) -> Double { ranges.first(where: { $0.rangeName == name })?.percentage ?? 0 }
        return MKCoverageReport(
            ranges: ranges,
            supportsTashkeel: percent("tashkeel") >= 80,
            supportsQuranicMarks: percent("quranicMarks") >= 50,
            supportsLatin: percent("basicLatin") >= 80
        )
    }

    private struct RangeDef {
        let name: String
        let scalars: [UInt32]
    }

    private static func closedRange(_ lower: UInt32, _ upper: UInt32) -> [UInt32] {
        Array(lower...upper)
    }

    private static let definedRanges: [RangeDef] = [
        RangeDef(name: "arabic", scalars: closedRange(0x0600, 0x06FF)),
        RangeDef(name: "arabicSupplement", scalars: closedRange(0x0750, 0x077F)),
        RangeDef(name: "arabicExtendedA", scalars: closedRange(0x08A0, 0x08FF)),
        RangeDef(name: "presentationFormsAB_informationalOnly", scalars:
            closedRange(0xFB50, 0xFDFF) + closedRange(0xFE70, 0xFEFF)),
        RangeDef(name: "tashkeel", scalars: closedRange(0x064B, 0x065F) + [0x0670]),
        RangeDef(name: "quranicMarks", scalars: closedRange(0x06D6, 0x06ED)),
        RangeDef(name: "arabicIndicDigits", scalars: closedRange(0x0660, 0x0669)),
        RangeDef(name: "extendedArabicIndicDigits", scalars: closedRange(0x06F0, 0x06F9)),
        RangeDef(name: "basicLatin", scalars: closedRange(0x0041, 0x005A) + closedRange(0x0061, 0x007A) + closedRange(0x0030, 0x0039)),
    ]
}

/// Cached-once, stored-on-catalog-entry coverage summary (T10 AC).
public struct MKCoverageReport: Sendable, Hashable, Codable {
    public var ranges: [MKCoverageAnalyzer.RangeCoverage]
    public var supportsTashkeel: Bool
    public var supportsQuranicMarks: Bool
    public var supportsLatin: Bool

    public init(ranges: [MKCoverageAnalyzer.RangeCoverage], supportsTashkeel: Bool, supportsQuranicMarks: Bool, supportsLatin: Bool) {
        self.ranges = ranges
        self.supportsTashkeel = supportsTashkeel
        self.supportsQuranicMarks = supportsQuranicMarks
        self.supportsLatin = supportsLatin
    }
}

extension MKCoverageAnalyzer.RangeCoverage: Codable {}

private extension CFCharacterSet {
    /// `CFCharacterSetIsLongCharacterMember` handles the full 21-bit
    /// Unicode range (astral-safe, though every range this module queries
    /// is in the BMP); kept as one small helper so callers never touch the
    /// C API's plane-splitting directly.
    func hasMember(inPlane scalar: UInt32) -> Bool {
        CFCharacterSetIsLongCharacterMember(self, scalar)
    }
}
