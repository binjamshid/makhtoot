import Foundation

/// T8 ، Arabic-aware search/ranking over the catalog snapshot. Pure value
/// type (no actor isolation needed: operates over an immutable snapshot
/// passed in, so `MKFontRegistry`/`MKFontCatalog` can call it from any
/// isolation context).
public struct MKFontSearchIndex: Sendable {
    public init() {}

    public struct Entry: Sendable {
        public var fontID: MKFontID
        public var familyName: String
        public var familyNameArabic: String?
        public var tags: [String]
        public var categories: [MKFontCategory]
        public var isFavorite: Bool

        public init(fontID: MKFontID, familyName: String, familyNameArabic: String?, tags: [String], categories: [MKFontCategory], isFavorite: Bool) {
            self.fontID = fontID
            self.familyName = familyName
            self.familyNameArabic = familyNameArabic
            self.tags = tags
            self.categories = categories
            self.isFavorite = isFavorite
        }
    }

    /// Empty query ⇒ full catalog, ordered by category then name (AC).
    public func search(_ query: String, in entries: [Entry]) -> [MKFontID] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return entries
                .sorted {
                    let lhsCat = $0.categories.first?.rawValue ?? ""
                    let rhsCat = $1.categories.first?.rawValue ?? ""
                    if lhsCat != rhsCat { return lhsCat < rhsCat }
                    return $0.familyName.localizedCaseInsensitiveCompare($1.familyName) == .orderedAscending
                }
                .map(\.fontID)
        }

        let needle = Self.normalize(trimmed)
        struct Scored { let id: MKFontID; let score: Int }
        var scored: [Scored] = []

        for entry in entries {
            var best = 0
            let candidates = [entry.familyName, entry.familyNameArabic ?? ""] + entry.tags
                + entry.categories.map(\.arabicDisplayName) + entry.categories.map(\.rawValue)
            for candidate in candidates {
                let normalizedCandidate = Self.normalize(candidate)
                guard !normalizedCandidate.isEmpty else { continue }
                if normalizedCandidate == needle {
                    best = max(best, 100)
                } else if normalizedCandidate.hasPrefix(needle) {
                    best = max(best, 80)
                } else if normalizedCandidate.contains(needle) {
                    best = max(best, 50)
                }
            }
            if best > 0 {
                if entry.isFavorite { best += 10 }   // favorites boosted
                scored.append(Scored(id: entry.fontID, score: best))
            }
        }

        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.id < $1.id }
            .map(\.id)
    }

    /// Normalization: strip tashkeel (U+064B–065F), unify alef forms
    /// (أ/إ/آ/ٱ → ا), fold ة→ه, lowercase Latin, strip diacritics/case.
    public static func normalize(_ input: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in input.unicodeScalars {
            let v = scalar.value
            if (0x064B...0x065F).contains(v) || v == 0x0670 { continue }  // tashkeel
            switch v {
            case 0x0623, 0x0625, 0x0622, 0x0671: scalars.append(Unicode.Scalar(0x0627)!)  // أإآٱ → ا
            case 0x0629: scalars.append(Unicode.Scalar(0x0647)!)                          // ة → ه
            case 0x0649: scalars.append(Unicode.Scalar(0x064A)!)                          // ى → ي
            default: scalars.append(scalar)
            }
        }
        let folded = String(scalars)
        return folded.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ar"))
    }
}
