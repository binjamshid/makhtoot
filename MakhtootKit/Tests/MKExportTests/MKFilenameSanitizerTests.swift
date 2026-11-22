import Testing
@testable import MKExport

// WS-08 packet §6: "Default export filename = project name, Arabic-safe
// sanitized; test 'مشروعي الأول.png'."
@Suite struct MKFilenameSanitizerTests {
    @Test func arabicProjectNamePassesThroughUnmodified() {
        #expect(MKFilenameSanitizer.sanitize("مشروعي الأول") == "مشروعي الأول")
    }

    @Test func arabicIndicDigitsAndTashkeelSurvive() {
        // §6: "Arabic-Indic digits survive every format (no ASCII
        // normalization in serialization)" ، extended to filenames here.
        let name = "مشروع ١٢٣ شَدَّةٌ"
        #expect(MKFilenameSanitizer.sanitize(name) == name)
    }

    @Test func illegalFilesystemCharactersAreReplaced() {
        let sanitized = MKFilenameSanitizer.sanitize("my/project:name*?")
        #expect(!sanitized.contains("/"))
        #expect(!sanitized.contains(":"))
        #expect(!sanitized.contains("*"))
        #expect(!sanitized.contains("?"))
    }

    @Test func emptyOrWhitespaceOnlyNameFallsBackToDefault() {
        #expect(MKFilenameSanitizer.sanitize("") == "مخطوط")
        #expect(MKFilenameSanitizer.sanitize("   ") == "مخطوط")
    }

    @Test func customFallbackIsHonored() {
        #expect(MKFilenameSanitizer.sanitize("", fallback: "project") == "project")
    }

    @Test func veryLongNameIsCapped() {
        let long = String(repeating: "أ", count: 500)
        let sanitized = MKFilenameSanitizer.sanitize(long)
        #expect(sanitized.utf8.count <= 200)
    }
}
