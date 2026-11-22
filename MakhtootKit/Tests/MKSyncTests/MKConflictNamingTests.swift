import Foundation
import Testing
@testable import MKSync

// T7 ، Conflict copy naming: base suffix, Arabic-Indic numeral suffixes,
// collision avoidance, RTL-safe name construction.

struct MKConflictNamingTests {
    // MARK: - Basic

    @Test("Base conflict name appended correctly")
    func baseConflictName() {
        let name = MKConflictNaming.conflictCopyName(
            for: "اختبار", existingNames: [])
        #expect(name == "اختبار (نسخة متعارضة)")
    }

    @Test("Suffix is exactly '(نسخة متعارضة)'")
    func suffixIsCanonical() {
        #expect(MKConflictNaming.conflictSuffix == "(نسخة متعارضة)")
    }

    // MARK: - Collision avoidance with Arabic-Indic numerals

    @Test("First collision appends ٢")
    func firstCollisionAppendsTwo() {
        let existing: Set<String> = ["اختبار (نسخة متعارضة)"]
        let name = MKConflictNaming.conflictCopyName(for: "اختبار", existingNames: existing)
        #expect(name == "اختبار (نسخة متعارضة) ٢")
    }

    @Test("Second collision appends ٣")
    func secondCollisionAppendsThree() {
        let existing: Set<String> = [
            "اختبار (نسخة متعارضة)",
            "اختبار (نسخة متعارضة) ٢",
        ]
        let name = MKConflictNaming.conflictCopyName(for: "اختبار", existingNames: existing)
        #expect(name == "اختبار (نسخة متعارضة) ٣")
    }

    @Test("Latin project name also works")
    func latinName() {
        let name = MKConflictNaming.conflictCopyName(for: "Test", existingNames: [])
        #expect(name == "Test (نسخة متعارضة)")
    }

    @Test("Empty project name produces a valid conflict name")
    func emptyName() {
        let name = MKConflictNaming.conflictCopyName(for: "", existingNames: [])
        #expect(name == " (نسخة متعارضة)")
    }

    // MARK: - Determinism

    @Test("Same inputs always produce same output")
    func deterministic() {
        let existing: Set<String> = ["مشروع (نسخة متعارضة)"]
        let a = MKConflictNaming.conflictCopyName(for: "مشروع", existingNames: existing)
        let b = MKConflictNaming.conflictCopyName(for: "مشروع", existingNames: existing)
        #expect(a == b)
    }

    // MARK: - Generated name is not in existingNames

    @Test("Generated name is always unique relative to existingNames")
    func generatedNameIsUnique() {
        // Build a big set of pre-existing names.
        var existing: Set<String> = ["تجربة (نسخة متعارضة)"]
        for numeral in MKConflictNaming.arabicIndicNumerals {
            existing.insert("تجربة (نسخة متعارضة) \(numeral)")
        }
        let name = MKConflictNaming.conflictCopyName(for: "تجربة", existingNames: existing)
        #expect(!existing.contains(name))
        #expect(name.hasPrefix("تجربة (نسخة متعارضة)"))
    }

    // MARK: - Arabic-Indic numeral sequence integrity

    @Test("numerals start with ٢ not ١")
    func numeralsStartWithTwo() {
        #expect(MKConflictNaming.arabicIndicNumerals.first == "٢")
    }

    @Test("numerals sequence has at least 20 entries")
    func numeralsCount() {
        #expect(MKConflictNaming.arabicIndicNumerals.count >= 20)
    }
}
