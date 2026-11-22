import Foundation

/// Embedding rights bitset ، CANONICAL shape per D-227(1) (ARCHITECTURE.md
/// §17.3, rewritten to match this WS-09 T2 record). WS-08's `embedPDF`/
/// `embedSVG` consumers are accessors over this set, never ad hoc booleans:
/// `embeddingRights.contains(.pdf)` / `.contains(.svg)`. Do not add a
/// fourth "rasterOnly" bit ، the empty set (`[]`) already means "no
/// embedding rights, outline/raster fallback only" (T15: imported fonts get
/// `[]`).
public struct MKEmbeddingRights: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Permits PDF text-subset embedding (`MKTextEmbedPolicy.embedSubset`,
    /// ARCHITECTURE §16.5).
    public static let pdf = MKEmbeddingRights(rawValue: 1 << 0)
    /// Permits SVG `@font-face` subset embedding (§16.6).
    public static let svg = MKEmbeddingRights(rawValue: 1 << 1)
    /// Permits commercial-software bundling/distribution at all (OFL 1.1
    /// §2's "bundled ... with any software" clause) ، distinct from the
    /// per-export-format bits so a future FD-07 commercial license can
    /// narrow `.pdf`/`.svg` independently while still setting this.
    public static let commercialUse = MKEmbeddingRights(rawValue: 1 << 2)
}

/// JSON representation is an array of string keys (`["pdf","svg",
/// "commercialUse"]`) rather than a raw integer ، far more auditable in a
/// hand-inspectable `records.json` and stable across any future bit
/// reordering (a raw-Int encoding would silently corrupt on reorder).
extension MKEmbeddingRights: Codable {
    private static let wireKeys: [(String, MKEmbeddingRights)] = [
        ("pdf", .pdf), ("svg", .svg), ("commercialUse", .commercialUse),
    ]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let keys = try container.decode([String].self)
        var result: MKEmbeddingRights = []
        for key in keys {
            if let match = Self.wireKeys.first(where: { $0.0 == key })?.1 {
                result.insert(match)
            }
        }
        self = result
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let keys = Self.wireKeys.filter { contains($0.1) }.map(\.0)
        try container.encode(keys)
    }
}

/// License classification. Encoded on the wire as the exact license-string
/// spelling ARCHITECTURE §17.3 shows (`"OFL-1.1"`) ، an enum in Swift for
/// call-site type safety (T2's request), a plain string in JSON (D-227's
/// canonical shape). `.commercial`/`.prohibited` are FD-07 schema hooks
/// (inert in v1 ، no v1 manifest may contain them, T11 AC).
public enum MKLicenseType: String, Sendable, Codable, Hashable {
    case ofl11 = "OFL-1.1"
    case apacheV2Reserved = "Apache-2.0-Reserved"
    case commercial
    case prohibited
    /// User-imported font (T15): no redistribution rights are knowable, so
    /// this is not "unverified OFL" ، it is its own explicit category.
    case userProvided = "user-provided"
}

/// The CANONICAL `MKLicenseRecord` app-wide (D-227(1)). Field set is frozen
/// to exactly what's listed below ، WS-08's embedding-rights consumers key
/// off `embeddingRights` directly; do not add parallel booleans.
public struct MKLicenseRecord: Sendable, Codable, Hashable {
    public var fontID: MKFontID
    public var familyName: String
    public var licenseType: MKLicenseType
    public var copyrightNotice: String
    public var reservedFontNames: [String]
    public var sourceRepoURL: String
    public var licenseFileBundlePath: String
    /// ISO-8601 date string (`YYYY-MM-DD`), per ARCHITECTURE §17.3.
    public var verificationDate: String
    public var verifiedBy: String
    public var redistributionConfirmed: Bool
    public var embeddingRights: MKEmbeddingRights

    public init(
        fontID: MKFontID, familyName: String, licenseType: MKLicenseType, copyrightNotice: String,
        reservedFontNames: [String], sourceRepoURL: String, licenseFileBundlePath: String,
        verificationDate: String, verifiedBy: String, redistributionConfirmed: Bool,
        embeddingRights: MKEmbeddingRights
    ) {
        self.fontID = fontID
        self.familyName = familyName
        self.licenseType = licenseType
        self.copyrightNotice = copyrightNotice
        self.reservedFontNames = reservedFontNames
        self.sourceRepoURL = sourceRepoURL
        self.licenseFileBundlePath = licenseFileBundlePath
        self.verificationDate = verificationDate
        self.verifiedBy = verifiedBy
        self.redistributionConfirmed = redistributionConfirmed
        self.embeddingRights = embeddingRights
    }

    /// T15: the record every user-imported font gets. No embedding rights,
    /// `redistributionConfirmed == false` ، WS-08 outlines on export,
    /// Settings→Support→Licensing shows the user-responsibility notice
    /// (`MKFontsStrings.userImportedLicenseNotice`).
    public static func userProvided(fontID: MKFontID, familyName: String, importedAt: Date) -> MKLicenseRecord {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return MKLicenseRecord(
            fontID: fontID, familyName: familyName, licenseType: .userProvided,
            copyrightNotice: "", reservedFontNames: [], sourceRepoURL: "",
            licenseFileBundlePath: "", verificationDate: formatter.string(from: importedAt),
            verifiedBy: "user-import", redistributionConfirmed: false, embeddingRights: []
        )
    }
}

/// Extra per-font verification evidence WS-09's D-222 protocol produces
/// (steps 7-8) ، not part of the canonical D-227 `MKLicenseRecord` shape
/// (which stays frozen to what WS-08 consumes), but shipped alongside it in
/// `records.json` and surfaced at Settings→Support→Licensing (T16) so the
/// gate outcomes are auditable, not just asserted in prose.
public struct MKFontVerificationEvidence: Sendable, Codable, Hashable {
    public enum GateResult: String, Sendable, Codable {
        case pass
        case fail
        /// The gate could not be executed this run (e.g. Arrange Mode does
        /// not exist yet) ، distinct from `fail`: a `blocked` gate is not
        /// asserted as either passing or failing, and must be re-run before
        /// being asserted either way.
        case blocked
    }

    public var arrangeFidelityGate: GateResult
    public var arrangeFidelityNote: String
    public var gposCursiveAttachmentPresent: Bool
    public var gposNote: String

    public init(arrangeFidelityGate: GateResult, arrangeFidelityNote: String, gposCursiveAttachmentPresent: Bool, gposNote: String) {
        self.arrangeFidelityGate = arrangeFidelityGate
        self.arrangeFidelityNote = arrangeFidelityNote
        self.gposCursiveAttachmentPresent = gposCursiveAttachmentPresent
        self.gposNote = gposNote
    }
}
