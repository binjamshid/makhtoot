import Foundation

// WS-14 packet §5 task 9: "search over nameAr/tags (reuse shared Arabic
// normalizer)." The shared normalizer (`SearchNormalizer`,
// tashkeel-stripping + hamza/ta-marbuta/alif-maqsura unification) lives in
// `MKPersistence/Metadata/SearchNormalizer.swift` ، but FOUNDATION §2's
// module map locks `MKAssets`'s only dependency to `MKModel` (no
// `MKPersistence` edge), and this run's fence is `MKAssets` sources only.
// Rather than add an undeclared cross-module dependency, this file
// REIMPLEMENTS the identical normalization rule as a small, self-contained
// utility ، the same "duplicate a small shared utility across fenced
// modules" pattern this codebase already uses for `MKFixtureLocator`
// (duplicated verbatim into both `MKModelTests`/`MKPersistenceTests`, per
// `docs/impl-log/WS-02.md`'s own note on that file). Kept byte-for-byte
// identical in BEHAVIOR (not byte-for-byte in code, since this module's
// naming conventions differ slightly) to `MKPersistence.SearchNormalizer`
// so "نجمة" matches "نَجْمَة" the same way everywhere in the app.
public enum MKAssetSearchNormalizer {
    public static func normalize(_ input: String) -> String {
        var scalars: [Unicode.Scalar] = []
        scalars.reserveCapacity(input.unicodeScalars.count)
        for scalar in input.unicodeScalars {
            if (0x064B...0x0652).contains(scalar.value) { continue } // strip tashkeel
            scalars.append(unify(scalar))
        }
        return String(String.UnicodeScalarView(scalars)).lowercased()
    }

    private static func unify(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        switch scalar.value {
        case 0x0623, 0x0625, 0x0622: return Unicode.Scalar(0x0627)! // أ إ آ → ا
        case 0x0629: return Unicode.Scalar(0x0647)! // ة → ه
        case 0x0649: return Unicode.Scalar(0x064A)! // ى → ي
        default: return scalar
        }
    }

    public static func matches(query: String, in text: String) -> Bool {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return true }
        return normalize(text).contains(normalizedQuery)
    }

    /// Whether `query` matches an asset's Arabic name or any of its tags.
    public static func matches(query: String, nameAr: String, tags: [String]) -> Bool {
        matches(query: query, in: nameAr) || tags.contains { matches(query: query, in: $0) }
    }
}
