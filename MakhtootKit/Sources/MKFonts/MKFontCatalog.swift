import CoreText
import Foundation

/// T6/T7/T8/T9 ، catalog façade: merges the registry snapshot with search
/// and preview-string provisioning. WS-13's catalog UI is the consumer;
/// this module supplies data only (no view code ، FOUNDATION's "no
/// UIKit/CoreText/CG outside MKTextEngine/MKFonts" line is honored: this
/// type uses `CTFont`/`CFAttributedString` internally, never SwiftUI).
public actor MKFontCatalog {
    private let registry: MKFontRegistry
    private let search = MKFontSearchIndex()

    /// T9 ، user-neutral preview string (no Qur'anic content, BRIEF
    /// Q67-68 override of the market study's own suggested preview text ،
    /// see ARCHITECTURE §17.6's stale example, flagged in
    /// `docs/impl-log/WS-09.md`).
    public static let defaultPreviewText = "بسم الحرف العربي وجماله"
    public static let numeralsPreviewText = "١٢٣ 123"

    public init(registry: MKFontRegistry) {
        self.registry = registry
    }

    public struct BrowseEntry: Sendable, Hashable {
        public var fontID: MKFontID
        public var familyName: String
        public var categories: [MKFontCategory]
        public var tags: [String]
        public var origin: MKFontOrigin
        public var isLocked: Bool
        public var isFavorite: Bool
    }

    /// T7/T9 AC: default catalog excludes provisional (D-222-step-8-
    /// flagged) fonts from browse, but they remain registered (so the
    /// shaping harness / demo path can still reach them by fontID
    /// directly ، see `MKFontRegistry.isProvisionalShip`).
    public func browse(favorites: Set<MKFontID> = []) async -> [BrowseEntry] {
        let records = await registry.records()
        var entries: [BrowseEntry] = []
        for record in records {
            if await registry.isProvisionalShip(record.fontID) { continue }
            entries.append(BrowseEntry(
                fontID: record.fontID, familyName: record.familyName, categories: record.categories,
                tags: record.tags, origin: record.origin, isLocked: record.isLocked,
                isFavorite: favorites.contains(record.fontID)
            ))
        }
        return entries.sorted {
            let l = $0.categories.first?.rawValue ?? ""
            let r = $1.categories.first?.rawValue ?? ""
            return l != r ? l < r : $0.familyName < $1.familyName
        }
    }

    /// T7 AC: category → fonts, including empty categories (returns `[]`,
    /// never omits the category from the caller's own enumeration since
    /// `MKFontCategory.allCases` is the source of truth for which
    /// categories exist).
    public func fonts(in category: MKFontCategory, favorites: Set<MKFontID> = []) async -> [BrowseEntry] {
        await browse(favorites: favorites).filter { $0.categories.contains(category) }
    }

    /// T8 ، Arabic-aware search.
    public func search(_ query: String, favorites: Set<MKFontID> = []) async -> [BrowseEntry] {
        let all = await browse(favorites: favorites)
        let index = all.map {
            MKFontSearchIndex.Entry(
                fontID: $0.fontID, familyName: $0.familyName, familyNameArabic: nil,
                tags: $0.tags, categories: $0.categories, isFavorite: $0.isFavorite
            )
        }
        let orderedIDs = search.search(query, in: index)
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.fontID, $0) })
        return orderedIDs.compactMap { byID[$0] }
    }

    /// T9 ، preview data. Never triggers a download for an undownloaded
    /// premium font (AC): callers needing a preview for a `notDownloaded`
    /// premium entry should render the catalog thumbnail metadata instead
    /// of calling this (this method only resolves already-registered
    /// faces).
    public func previewAttributedString(
        for fontID: MKFontID, size: CGFloat, text: String? = nil
    ) async -> NSAttributedString? {
        guard let font = try? await registry.ctFont(for: fontID, size: size) else { return nil }
        let string = text ?? Self.defaultPreviewText
        // `.font` (`NSAttributedString.Key`) is a UIKit/AppKit extension ،
        // this module stays Core Text/Foundation-only (FOUNDATION's
        // "UIKit/AppKit confined to MKCanvas/MKRender/AppDelegate; Core
        // Text confined to MKTextEngine/MKFonts" rule), so the attribute
        // key is spelled via the Core Text constant directly.
        let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)
        return NSAttributedString(string: string, attributes: [fontKey: font])
    }

    public func coverageReport(for fontID: MKFontID) async -> MKCoverageReport? {
        await registry.coverageReport(for: fontID)
    }
}
