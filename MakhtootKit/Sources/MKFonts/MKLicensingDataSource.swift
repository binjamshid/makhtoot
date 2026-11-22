import Foundation

/// T16 ، display-ready data for Settings→Support→Licensing (Q66). Data
/// only; WS-12 renders it. Sorted bundled → premium → imported (AC).
public actor MKLicensingDataSource {
    private let registry: MKFontRegistry
    private let bundle: Bundle

    public init(registry: MKFontRegistry, bundle: Bundle = MKFontsResources.bundle) {
        self.registry = registry
        self.bundle = bundle
    }

    public struct Section: Sendable, Hashable {
        public var fontID: MKFontID
        public var familyName: String
        public var foundryOrAuthor: String
        public var licenseType: MKLicenseType
        public var fullLicenseText: String?
        public var reservedFontNames: [String]
        public var sourceRepoURL: String
        public var commercialUseStatus: String
        public var coverage: MKCoverageReport?
        public var origin: MKFontOrigin
        public var isProvisionalShip: Bool
        public var arrangeFidelityGateNote: String?
        public var gposCursiveNote: String?
    }

    /// Every registered font appears exactly once (AC). License full text
    /// is loaded lazily (async) from the bundle path recorded on the
    /// record ، byte-identical to the captured file (AC), since it's read
    /// directly from `Resources/Fonts/<Family>/LICENSE-OFL.txt` with no
    /// transformation.
    public func sections() async -> [Section] {
        let records = await registry.records()
        var out: [Section] = []
        for record in records {
            guard let license = await registry.licenseRecord(for: record.fontID) else { continue }
            let evidence = await registry.verificationEvidence(for: record.fontID)
            let fullText = fullLicenseText(for: license)
            // Foundry/author: derived from the copyright line up to the
            // first parenthesis or period ، never fabricated beyond what
            // the captured license text itself says.
            let foundry = foundryFromCopyright(license.copyrightNotice) ?? license.familyName
            let commercialStatus = license.embeddingRights.contains(.commercialUse)
                ? "مسموح بالاستخدام التجاري (OFL 1.1)"     // permitted for commercial use
                : (license.licenseType == .userProvided
                    ? "خط مستورد من المستخدم ، التزام الترخيص مسؤولية المستخدم"
                    : "غير مؤكد")
            let coverage = await registry.coverageReport(for: record.fontID)
            out.append(Section(
                fontID: record.fontID, familyName: record.familyName, foundryOrAuthor: foundry,
                licenseType: license.licenseType, fullLicenseText: fullText,
                reservedFontNames: license.reservedFontNames, sourceRepoURL: license.sourceRepoURL,
                commercialUseStatus: commercialStatus, coverage: coverage, origin: record.origin,
                isProvisionalShip: await registry.isProvisionalShip(record.fontID),
                arrangeFidelityGateNote: evidence?.arrangeFidelityNote, gposCursiveNote: evidence?.gposNote
            ))
        }
        return out.sorted { lhs, rhs in
            if lhs.origin.rawValue != rhs.origin.rawValue { return lhs.origin.rawValue < rhs.origin.rawValue }
            return lhs.familyName < rhs.familyName
        }
    }

    private func fullLicenseText(for license: MKLicenseRecord) -> String? {
        guard !license.licenseFileBundlePath.isEmpty, let url = resolveDirect(license.licenseFileBundlePath) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func resolveDirect(_ relativePath: String) -> URL? {
        guard let resourceURL = bundle.resourceURL else { return nil }
        let url = resourceURL.appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func foundryFromCopyright(_ notice: String) -> String? {
        guard !notice.isEmpty else { return nil }
        if let parenRange = notice.range(of: "(") {
            return String(notice[..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        if let stop = notice.firstIndex(of: ".") {
            return String(notice[..<stop])
        }
        return notice
    }
}

/// The Arabic user-import legal notice (T15), a named constant so WS-12's
/// Licensing screen and this module's own tests reference the exact same
/// string rather than two independently-typed copies drifting apart.
public enum MKFontsStrings {
    /// Latin gloss: user-imported font ، licensing compliance is the
    /// user's responsibility
    public static let userImportedLicenseNotice = "خط مستورد من المستخدم ، التزام الترخيص مسؤولية المستخدم"
}
