import Foundation

// WS-08 packet §6 Arabic-correctness notes: "Default export filename =
// project name, Arabic-safe sanitized; test 'مشروعي الأول.png'." `MKScene`
// carries no title field (that lives at the `.makhtoot` package/project
// record level, WS-02/WS-13 territory, out of this module's fence) ،
// `ExportCoordinator.export(...)` accepts a caller-supplied
// `filenameBase: String` (the project title, when a caller has one) and
// runs it through this sanitizer, which is the actual in-scope, testable
// P10-EARLY deliverable for this note.
public enum MKFilenameSanitizer {
    /// Filesystem-illegal characters (`/` is illegal on every Apple
    /// filesystem; the rest are conservative Windows/legacy-safe
    /// exclusions so exported files stay portable) plus all control
    /// characters. Arabic letters, diacritics (tashkeel), and
    /// Arabic-Indic digits are NEVER touched ، §6: "no ASCII
    /// normalization in serialization" extends to filenames here too.
    private static let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|\0").union(.controlCharacters)

    public static func sanitize(_ raw: String, fallback: String = "مخطوط") -> String {
        var result = ""
        result.reserveCapacity(raw.count)
        for scalar in raw.unicodeScalars {
            result.unicodeScalars.append(illegal.contains(scalar) ? "_" : scalar)
        }
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let final = trimmed.isEmpty ? fallback : trimmed
        // Defensive cap ، APFS/most filesystems allow 255 UTF-8 bytes per
        // path component; leave headroom for the extension the caller
        // appends afterward.
        guard final.utf8.count > 200 else { return final }
        var capped = final
        while capped.utf8.count > 200 { capped.removeLast() }
        return capped
    }
}
