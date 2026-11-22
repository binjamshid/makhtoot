import Foundation
import Testing
@testable import MKFonts

/// T16 AC: every registered font appears exactly once; license full text
/// is byte-identical to the captured file; sorted bundled → premium →
/// imported.
@Suite("MKLicensingDataSource ، T16")
struct MKLicensingDataSourceTests {
    @Test func everyFontAppearsExactlyOnce() async throws {
        let registry = MKFontRegistry()
        let loadedIDs = try await registry.loadBundled()
        let dataSource = MKLicensingDataSource(registry: registry)
        let sections = await dataSource.sections()
        #expect(sections.count == loadedIDs.count)
        #expect(Set(sections.map(\.fontID)).count == sections.count)
    }

    @Test func fullLicenseTextIsByteIdenticalToTheCapturedFile() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let dataSource = MKLicensingDataSource(registry: registry)
        let sections = await dataSource.sections()
        let amiri = try #require(sections.first { $0.fontID == "amiri" })
        let expectedURL = MKFontsResources.bundle.resourceURL!.appendingPathComponent("Fonts/Amiri/LICENSE-OFL.txt")
        let expected = try String(contentsOf: expectedURL, encoding: .utf8)
        #expect(amiri.fullLicenseText == expected)
        #expect(amiri.fullLicenseText?.contains("SIL OPEN FONT LICENSE") == true)
    }

    @Test func sortedBundledBeforePremiumBeforeImported() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()

        let bundledRecord = try #require(await registry.records().first)
        let importedRecord = MKFontRecord(fontID: "user.zzz", familyName: "Imported", origin: .userImported, faces: bundledRecord.faces, categories: [], tags: [])
        try await registry.registerImported(importedRecord, license: .userProvided(fontID: "user.zzz", familyName: "Imported", importedAt: Date()))

        let dataSource = MKLicensingDataSource(registry: registry)
        let sections = await dataSource.sections()
        let bundledIndex = try #require(sections.firstIndex { $0.origin == .bundled })
        let importedIndex = try #require(sections.firstIndex { $0.origin == .userImported })
        #expect(bundledIndex < importedIndex)
    }

    @Test func userImportedShowsTheResponsibilityNotice() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let record = try #require(await registry.records().first)
        let importedRecord = MKFontRecord(fontID: "user.abc", familyName: "Imported", origin: .userImported, faces: record.faces, categories: [], tags: [])
        try await registry.registerImported(importedRecord, license: .userProvided(fontID: "user.abc", familyName: "Imported", importedAt: Date()))

        let dataSource = MKLicensingDataSource(registry: registry)
        let sections = await dataSource.sections()
        let imported = try #require(sections.first { $0.fontID == "user.abc" })
        #expect(imported.commercialUseStatus == MKFontsStrings.userImportedLicenseNotice)
    }
}
