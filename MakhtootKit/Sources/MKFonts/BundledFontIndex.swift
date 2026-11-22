import Foundation

/// On-disk shape of `Resources/LicenseRecords/records.json` ، a superset of
/// the canonical `MKLicenseRecord` (D-227) plus the D-222 per-font
/// verification evidence (steps 7-8) and face-level data used to build
/// `MKFontFace`. `BundledFontIndex` (T3/T4/T5) decodes this once at launch
/// and splits it into the canonical record (for `MKLicenseStore`/T16) and
/// the richer evidence (for the Licensing screen's "why" detail + the T20
/// audit).
struct MKRecordsFileEntry: Codable {
    struct Face: Codable {
        var filename: String
        var postScriptName: String?
        var fullName: String?
        var style: String?
        var weight: Int?
        var sha256: String
        var sizeBytes: Int
        var isVariable: Bool
        var gposCursiveAttachment: Bool
        var gposLookupTypes: [Int]
        var arabicCmapCount: Int
    }
    struct Verification: Codable {
        var step1_6_licenseCapture: String
        var step7_arrangeFidelityGate: String
        var step7_note: String
        var step8_gposCursiveAudit: String
        var step8_note: String
    }

    var fontID: String
    var familyName: String
    var licenseType: String
    var copyrightNotice: String
    var reservedFontNames: [String]
    var sourceRepoURL: String
    var sourceCommit: String?
    var licenseFileBundlePath: String
    var verificationDate: String
    var verifiedBy: String
    var redistributionConfirmed: Bool
    var embeddingRights: [String]
    var designer: String?
    var googleFontsEvidencePath: String
    var faces: [Face]
    var verification: Verification
}

/// T7 seed data shape (`Resources/catalog-seed.json`).
struct MKCatalogSeedFile: Codable {
    struct SeedFont: Codable {
        var fontID: String
        var familyName: String
        var familyNameArabic: String?
        var categories: [String]
        var tags: [String]
        var origin: String
        var faces: [String]
    }
    var schemaVersion: Int
    var generatedAt: String
    var categories: [String: String]
    var fonts: [SeedFont]
    var provisionalFonts: [String]
}

/// T3/T4/T5 ، enumerates `Resources/Fonts/<Family>/` and the two seed JSON
/// files (`LicenseRecords/records.json`, `catalog-seed.json`), producing:
///   - `MKFontRecord` per family with resolved `MKFontFace.fileURL`s
///   - `MKLicenseRecord` per family (canonical D-227 shape)
///   - `MKFontVerificationEvidence` per family (D-222 steps 7-8)
///
/// Enforces "no record → no registration" (T2 AC, T3 AC): a family whose
/// `records.json` entry is missing, or whose `redistributionConfirmed ==
/// false` for `bundled` origin, is skipped entirely ، never silently
/// registered. This is the load-bearing gate `FontLicenseAudit` (T20) also
/// checks independently (build-time), so a bug here fails loudly in tests
/// rather than only at review time.
public struct BundledFontIndex: Sendable {
    public struct LoadedFont: Sendable {
        public var record: MKFontRecord
        public var license: MKLicenseRecord
        public var evidence: MKFontVerificationEvidence
        /// True for the D-222-step-8-flagged fonts (GPOS cursive
        /// attachment present, no D-105 cursive-pair support yet) ، these
        /// are registered (so the app-boot/demo smoke test the packet
        /// requires can still exercise Amiri) but excluded from
        /// `MKFontCatalog`'s default browsable list. See
        /// `Resources/EXCLUDED_FONTS.md`.
        public var isProvisionalShip: Bool
    }

    public let bundle: Bundle

    public init(bundle: Bundle = MKFontsResources.bundle) {
        self.bundle = bundle
    }

    public func loadAll() throws -> [LoadedFont] {
        guard bundle.url(forResource: "Fonts", withExtension: nil) != nil else {
            return []
        }
        guard let recordsURL = bundle.url(forResource: "records", withExtension: "json", subdirectory: "LicenseRecords"),
              let recordsData = try? Data(contentsOf: recordsURL) else {
            return []
        }
        let entries = try JSONDecoder().decode([MKRecordsFileEntry].self, from: recordsData)

        var seedByID: [String: MKCatalogSeedFile.SeedFont] = [:]
        if let seedURL = bundle.url(forResource: "catalog-seed", withExtension: "json"),
           let seedData = try? Data(contentsOf: seedURL),
           let seed = try? JSONDecoder().decode(MKCatalogSeedFile.self, from: seedData) {
            for f in seed.fonts { seedByID[f.fontID] = f }
        }

        var loaded: [LoadedFont] = []
        for entry in entries {
            // "no record → no registration": redistribution must be
            // explicitly confirmed for a bundled font to load at all.
            guard entry.redistributionConfirmed else { continue }

            let familyDirName = Self.directoryName(forFontID: entry.fontID, fallback: entry.familyName)
            guard let familyDir = bundle.url(forResource: familyDirName, withExtension: nil, subdirectory: "Fonts") else {
                continue
            }

            var faces: [MKFontFace] = []
            for face in entry.faces {
                let fileURL = familyDir.appendingPathComponent(face.filename)
                guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
                let format: MKFontFileFormat = face.filename.lowercased().hasSuffix(".otf") ? .otf
                    : (face.filename.lowercased().hasSuffix(".ttc") ? .ttc : .ttf)
                faces.append(MKFontFace(
                    postScriptName: face.postScriptName ?? face.filename,
                    familyName: entry.familyName,
                    fullName: face.fullName ?? face.postScriptName ?? entry.familyName,
                    styleName: face.style ?? "normal",
                    weight: face.weight ?? 400,
                    isVariable: face.isVariable,
                    format: format,
                    filename: face.filename,
                    fileURL: fileURL
                ))
            }
            guard !faces.isEmpty else { continue }

            let seedEntry = seedByID[entry.fontID]
            let categories = (seedEntry?.categories ?? []).compactMap(MKFontCategory.init(rawValue:))
            let isProvisional = seedEntry == nil   // not in catalog-seed.json ⇒ step-8-flagged

            let license = MKLicenseRecord(
                fontID: entry.fontID, familyName: entry.familyName,
                licenseType: MKLicenseType(rawValue: entry.licenseType) ?? .ofl11,
                copyrightNotice: entry.copyrightNotice, reservedFontNames: entry.reservedFontNames,
                sourceRepoURL: entry.sourceRepoURL, licenseFileBundlePath: entry.licenseFileBundlePath,
                verificationDate: entry.verificationDate, verifiedBy: entry.verifiedBy,
                redistributionConfirmed: entry.redistributionConfirmed,
                embeddingRights: MKEmbeddingRights.decodeWireKeys(entry.embeddingRights)
            )
            let evidence = MKFontVerificationEvidence(
                arrangeFidelityGate: entry.verification.step7_arrangeFidelityGate == "pass" ? .pass
                    : (entry.verification.step7_arrangeFidelityGate == "fail" ? .fail : .blocked),
                arrangeFidelityNote: entry.verification.step7_note,
                gposCursiveAttachmentPresent: entry.verification.step8_gposCursiveAudit == "cursive_attachment_present",
                gposNote: entry.verification.step8_note
            )
            let record = MKFontRecord(
                fontID: entry.fontID, familyName: entry.familyName,
                familyNameArabic: seedEntry?.familyNameArabic ?? Self.builtInArabicNames[entry.fontID],
                origin: .bundled,
                faces: faces, categories: categories, tags: seedEntry?.tags ?? [], isLocked: false
            )
            loaded.append(LoadedFont(record: record, license: license, evidence: evidence, isProvisionalShip: isProvisional))
        }
        return loaded.sorted { $0.record.fontID < $1.record.fontID }
    }

    /// Family directory names are PascalCase (`Amiri`, `NotoNaskhArabic`)
    /// while `fontID`s are kebab-case (`amiri`, `noto-naskh-arabic`) ،
    /// derive the mapping the same way the acquisition pipeline did rather
    /// than hardcoding a second lookup table that could drift.
    private static func directoryName(forFontID fontID: String, fallback: String) -> String {
        fontID.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// Built-in Arabic display names for bundled fonts, keyed by `fontID`.
    /// Used as a fallback when `familyNameArabic` is not in the seed data.
    static let builtInArabicNames: [String: String] = [
        "almarai": "المراعي",
        "amiri": "أميري",
        "amiri-quran": "أميري قرآني",
        "aref-ruqaa": "عارِف رقعة",
        "aref-ruqaa-ink": "عارِف رقعة حبر",
        "el-messiri": "المسيري",
        "harmattan": "هرمطان",
        "jomhuria": "جمهورية",
        "katibeh": "كتيبة",
        "lateef": "لطيف",
        "mada": "مدى",
        "markazi-text": "مركزي",
        "mirza": "ميرزا",
        "noto-kufi-arabic": "نوتو كوفي عربي",
        "noto-naskh-arabic": "نوتو نسخ عربي",
        "noto-sans-arabic": "نوتو سانس عربي",
        "qahiri": "قهيري",
        "rakkas": "رقّاص",
        "reem-kufi": "ريم كوفي",
        "reem-kufi-fun": "ريم كوفي المرح",
        "reem-kufi-ink": "ريم كوفي حبر",
        "scheherazade-new": "شهرزاد الجديدة",
        "tajawal": "تجوال",
        "alef": "أَلِف",
        "baloo-bhaijaan-2": "بالو بهيجان ٢",
        "blaka": "بلكا",
        "blaka-ink": "بلكا حبر",
        "cairo": "القاهرة",
        "cairo-play": "القاهرة بلاي",
        "changa": "تشانغا",
        "farsan": "فرسان",
        "gulzar": "كلزار",
        "kufam": "كوفام",
        "lalezar": "لاله زار",
        "lemonada": "ليموناضة",
        "marhey": "مرحي",
        "readex-pro": "ريدكس برو",
        "rubik": "روبيك",
        "suez-one": "سويس ون",
        "vazirmatn": "وزيرمتن",
        "zain": "زين",
        "ibm-plex-sans-arabic": "آي بي إم بليكس عربي",
        "alkalami": "القلمي",
        "noto-nastaliq-urdu": "نوتو نستعليق أردو",
    ]
}

extension MKEmbeddingRights {
    static func decodeWireKeys(_ keys: [String]) -> MKEmbeddingRights {
        var result: MKEmbeddingRights = []
        for key in keys {
            switch key {
            case "pdf": result.insert(.pdf)
            case "svg": result.insert(.svg)
            case "commercialUse": result.insert(.commercialUse)
            default: break
            }
        }
        return result
    }
}
