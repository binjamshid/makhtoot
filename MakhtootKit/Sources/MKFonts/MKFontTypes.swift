import Foundation

/// Stable string identifier for a font family entry in the catalog ، e.g.
/// `"amiri"`, `"noto-naskh-arabic"`. Kept a plain `String` (not `MKID<Tag>`)
/// because it must round-trip byte-identical through the JSON manifest
/// (`catalog-manifest-v1.json`), the SwiftData `MKFontCatalogRecord.fontID`
/// column (also a plain `String`), and `MKLicenseRecord.fontID` ، three
/// systems outside this module's control over id representation.
public typealias MKFontID = String

/// Where a font came from ، drives locking behavior (D-119) and embedding
/// rights (D-227): only `bundled` origin can have `redistributionConfirmed
/// == true` from WS-09's own verification pipeline; `userImported` never
/// carries a license record at all (§17.5).
///
/// Raw values are pinned (not left to declaration order) because they are
/// persisted directly into `MKFontCatalogRecord.tier: Int` (MKPersistence,
/// WS-02) ، 0 bundled / 1 premium / 2 userImported, per that model's own
/// doc comment.
public enum MKFontOrigin: Int, Sendable, Codable, CaseIterable {
    case bundled = 0
    case premiumDownloaded = 1
    case userImported = 2
}

/// The ten BRIEF-locked font categories (D-120 §2/T1) ، this exact list,
/// nothing added, nothing removed. Arabic display names per T1.
public enum MKFontCategory: String, Sendable, Codable, CaseIterable {
    case naskh
    case ruqah
    case thuluth
    case diwani
    case kufi
    case maghrebi
    case modernDisplay
    case quranicStyle
    case handwriting
    case bilingual

    /// Arabic display name shown in catalog UI (WS-13 consumes this).
    public var arabicDisplayName: String {
        switch self {
        case .naskh: return "نسخ"
        case .ruqah: return "رقعة"
        case .thuluth: return "ثلث"
        case .diwani: return "ديواني"
        case .kufi: return "كوفي"
        case .maghrebi: return "مغربي"
        case .modernDisplay: return "عرض حديث"
        case .quranicStyle: return "طراز قرآني"
        case .handwriting: return "خط يدوي"
        case .bilingual: return "ثنائي اللغة"
        }
    }
}

/// sfnt container formats `MKFontValidator`/`MKFontImporter` (T14) accept.
/// Deliberately excludes `woff`/`woff2` ، those are explicit rejection
/// cases (D-122), not a case here.
public enum MKFontFileFormat: String, Sendable, Codable, CaseIterable {
    case ttf
    case otf
    case ttc
}

/// One physical face (a single weight/style/variable-instance file) within
/// a font family. `postScriptName` is the stable key `MKFontHandle`
/// (`MKFoundation`) and every shaping/render call site resolve against ،
/// see `MKRegistryFontProvider`.
public struct MKFontFace: Hashable, Sendable, Codable {
    public var postScriptName: String
    public var familyName: String
    public var fullName: String
    public var styleName: String
    /// CSS-style numeric weight (100...900); 400 = regular.
    public var weight: Int
    public var isVariable: Bool
    public var format: MKFontFileFormat
    /// Filename relative to the family's resource directory
    /// (`Resources/Fonts/<Family>/<filename>`), or the on-disk absolute
    /// path for premium-downloaded/user-imported faces.
    public var filename: String
    public var fileURL: URL

    public init(
        postScriptName: String, familyName: String, fullName: String, styleName: String,
        weight: Int, isVariable: Bool, format: MKFontFileFormat, filename: String, fileURL: URL
    ) {
        self.postScriptName = postScriptName
        self.familyName = familyName
        self.fullName = fullName
        self.styleName = styleName
        self.weight = weight
        self.isVariable = isVariable
        self.format = format
        self.filename = filename
        self.fileURL = fileURL
    }
}

/// One catalog-level font family entry: everything the registry knows
/// about a font independent of any single face ، origin, categories/tags,
/// lock state, license linkage. This is the T1/`MKFontRegistry` unit;
/// `MKFontCatalogEntry` (T6, `CatalogTypes.swift`) is the richer
/// UI/persistence-facing projection built on top of this.
public struct MKFontRecord: Sendable, Codable, Hashable {
    public var fontID: MKFontID
    public var familyName: String
    public var familyNameArabic: String?
    public var origin: MKFontOrigin
    public var faces: [MKFontFace]
    public var categories: [MKFontCategory]
    public var tags: [String]
    public var isLocked: Bool

    public init(
        fontID: MKFontID, familyName: String, familyNameArabic: String? = nil, origin: MKFontOrigin,
        faces: [MKFontFace], categories: [MKFontCategory], tags: [String] = [], isLocked: Bool = false
    ) {
        self.fontID = fontID
        self.familyName = familyName
        self.familyNameArabic = familyNameArabic
        self.origin = origin
        self.faces = faces
        self.categories = categories
        self.tags = tags
        self.isLocked = isLocked
    }
}

extension MKFontRecord {
    /// The face selected when no specific `postScriptName` is requested.
    ///
    /// `faces` is populated in raw `records.json` order (alphabetical by
    /// filename, see `BundledFontIndex.loadAll()`), NOT sorted by weight ،
    /// so `faces.first` silently lands on whatever cut sorts first
    /// alphabetically. For several families that is a Bold/Black/ExtraLight
    /// cut rather than Regular (e.g. `Amiri-Bold.ttf` sorts before
    /// `Amiri-Regular.ttf`), which made every default-face call site pick a
    /// bold face while `MKTextStyle.isBold == false`.
    ///
    /// Prefers the true regular cut (`weight == 400 && styleName ==
    /// "normal"`), falls back to the face with weight nearest 400 (for
    /// families with no exact-400-normal face), and finally to
    /// `faces.first` (only reachable if `faces` is empty, since every
    /// non-empty array has a weight nearest 400).
    public var defaultFace: MKFontFace? {
        if let regular = faces.first(where: { $0.weight == 400 && $0.styleName == "normal" }) {
            return regular
        }
        if let nearest = faces.min(by: { abs($0.weight - 400) < abs($1.weight - 400) }) {
            return nearest
        }
        return faces.first
    }
}
