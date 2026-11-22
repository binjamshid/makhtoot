import Foundation

// T7 ، Conflict copy naming. Pure functions so the naming algorithm is
// tested independently of CloudKit, MetadataStore, or any concurrency.

/// Generates conflict-copy names per D-112 / T7.
///
/// The base suffix `(نسخة متعارضة)` follows the glossary in FOUNDATION §0.
/// If the base name is already taken, Arabic-Indic numeral suffixes are
/// appended: ٢, ٣, ٤, … until an unused name is found.
public enum MKConflictNaming {
    /// Arabic-Indic digit sequence used for collision disambiguation.
    /// Covers the practical maximum; if somehow all are taken, a UUID
    /// fragment is used as the final fallback.
    static let arabicIndicNumerals: [String] = [
        "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩",
        "١٠", "١١", "١٢", "١٣", "١٤", "١٥", "١٦", "١٧", "١٨", "١٩", "٢٠", "٢١",
    ]

    /// Suffix appended to the original name: space + this string in parens.
    public static let conflictSuffix = "(نسخة متعارضة)"

    /// Returns a conflict-copy name for `originalName` that does not
    /// already appear in `existingNames`.
    ///
    /// Resolution order:
    /// 1. `"<originalName> (نسخة متعارضة)"`
    /// 2. `"<originalName> (نسخة متعارضة) ٢"`, `" ٣"`, …
    /// 3. `"<originalName> (نسخة متعارضة) (<uuid prefix>)"` (last resort)
    ///
    /// - Parameters:
    ///   - originalName: The original project title.
    ///   - existingNames: The set of all project titles currently in use.
    /// - Returns: A unique conflict-copy title.
    public static func conflictCopyName(
        for originalName: String,
        existingNames: Set<String>
    ) -> String {
        let base = "\(originalName) \(conflictSuffix)"
        if !existingNames.contains(base) { return base }

        for numeral in arabicIndicNumerals {
            let candidate = "\(base) \(numeral)"
            if !existingNames.contains(candidate) { return candidate }
        }

        // Last resort: UUID fragment (should never be needed in practice).
        let fragment = UUID().uuidString.prefix(8)
        return "\(base) (\(fragment))"
    }
}
