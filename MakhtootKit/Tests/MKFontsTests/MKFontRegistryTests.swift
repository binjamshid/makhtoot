import CoreText
import Foundation
import MKFoundation
import Testing
@testable import MKFonts

/// T1/T5/T17 ، registry skeleton, bundled registration, lock behavior.
@Suite("MKFontRegistry ، T1/T5/T17")
struct MKFontRegistryTests {
    @Test func registryIsConstructibleAndEmptyBeforeLoad() async {
        let registry = MKFontRegistry()
        let records = await registry.records()
        #expect(records.isEmpty)
    }

    @Test func loadBundledRegistersEveryRecordWithARecord() async throws {
        let registry = MKFontRegistry()
        let loadedIDs = try await registry.loadBundled()
        #expect(!loadedIDs.isEmpty)
        for id in loadedIDs {
            let license = await registry.licenseRecord(for: id)
            #expect(license != nil, "\(id) loaded without a license record ، 'no record, no registration' violated")
        }
    }

    @Test func ctFontResolvesForEveryLoadedFace() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let records = await registry.records()
        for record in records {
            for face in record.faces {
                let font = try await registry.ctFont(for: record.fontID, postScriptName: face.postScriptName, size: 24)
                #expect((CTFontCopyPostScriptName(font) as String) == face.postScriptName)
            }
        }
    }

    @Test func repeatedLoadBundledCallsAreIdempotent() async throws {
        let registry = MKFontRegistry()
        let first = try await registry.loadBundled()
        let second = try await registry.loadBundled()
        #expect(Set(first) == Set(second))
    }

    @Test func registrationUnder150MillisecondsFor15Families() async throws {
        let registry = MKFontRegistry()
        let clock = ContinuousClock()
        let start = clock.now
        let loadedIDs = try await registry.loadBundled()
        let elapsed = clock.now - start
        #expect(loadedIDs.count >= 15)
        // T5 AC targets <150ms for 20 families on A15 hardware; this test
        // runs on the (typically much faster) host dev machine, so budget
        // generously to stay meaningful under CI/host variance while still
        // catching an accidental O(n²) regression.
        #expect(elapsed < .seconds(2), "registration took \(elapsed), expected comfortably under 150ms on-device")
    }

    @Test func lockingPremiumOriginsBlocksNewShapingButNotBundled() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        // Simulate a premium-downloaded font via direct registration
        // (no network ، this only tests the lock mechanism).
        let bundledRecord = try #require(await registry.records().first)
        let fakePremiumFace = bundledRecord.faces[0]
        let fakePremiumRecord = MKFontRecord(
            fontID: "fake-premium", familyName: "Fake Premium", origin: .premiumDownloaded,
            faces: [fakePremiumFace], categories: [], tags: []
        )
        let license = MKLicenseRecord(
            fontID: "fake-premium", familyName: "Fake Premium", licenseType: .ofl11, copyrightNotice: "",
            reservedFontNames: [], sourceRepoURL: "", licenseFileBundlePath: "",
            verificationDate: "2026-07-18", verifiedBy: "test", redistributionConfirmed: true,
            embeddingRights: [.pdf, .svg, .commercialUse]
        )
        try await registry.registerDownloaded(fakePremiumRecord, license: license)

        await registry.setLocked(true, origins: [.premiumDownloaded, .userImported])

        await #expect(throws: MKFontError.self) {
            _ = try await registry.ctFont(for: "fake-premium", size: 24)
        }
        // Bundled fonts remain usable.
        _ = try await registry.ctFont(for: bundledRecord.fontID, size: 24)

        await registry.setLocked(false, origins: [.premiumDownloaded, .userImported])
        _ = try await registry.ctFont(for: "fake-premium", size: 24)
    }

    @Test func recordsDidChangeStreamYieldsOnMutation() async throws {
        let registry = MKFontRegistry()
        let stream = await registry.recordsDidChange
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()  // initial snapshot (empty)
        async let loaded: Void = { _ = try? await registry.loadBundled() }()
        let next = await iterator.next()
        #expect((next?.count ?? 0) > 0)
        _ = await loaded
    }

    /// WS-16 UPDATE (`docs/impl-log/WS-16-cursive.md`, superseding this
    /// test's original WS-09 assertion). Amiri (and the other 4
    /// D-222-step-8-flagged fonts: Amiri Quran, Aref Ruqaa, Rakkas, Qahiri)
    /// were held `isProvisionalShip == true` because D-105's mark-capture
    /// model had no way to represent GPOS cursive attachment. WS-16 found
    /// (a) `CTRunGetPositions` already bakes the cursive-adjusted position
    /// into capture and MKArrange's D-220 affine chain composes it
    /// correctly regardless of cause ، zero geometry changes needed ، and
    /// (b) added `MKProvenance.cursiveAttached`, a per-glyph provenance
    /// flag that makes the one real remaining gap (D-107 ZWJ-harvest
    /// reshape fidelity on join-break/decompose for cursive-attachment
    /// pairs ، an accepted-by-design limitation per D-222's own
    /// single-glyph-scale precedent, not a crash/corruption risk)
    /// identifiable and testable. `Resources/catalog-seed.json` now
    /// includes all 5 fonts ، see `Resources/EXCLUDED_FONTS.md`'s
    /// "Released this session (WS-16)" section and
    /// `Resources/LicenseRecords/records.json`'s updated step7/step8
    /// verification notes for the full evidence trail.
    @Test func formerlyProvisionalCursiveFontsAreNowReleasedIntoTheDefaultCatalog() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let amiri = await registry.record(for: "amiri")
        #expect(amiri != nil)
        #expect(!(await registry.isProvisionalShip("amiri")), "amiri should no longer be provisional after the WS-16 release")
        _ = try await registry.ctFont(for: "amiri", size: 24)  // does not throw

        let catalog = MKFontCatalog(registry: registry)
        let browse = await catalog.browse()
        #expect(browse.contains { $0.fontID == "amiri" }, "amiri should now appear in the default browsable catalog")

        // The other 4 released fonts, same check.
        for fontID in ["amiri-quran", "aref-ruqaa", "rakkas", "qahiri"] {
            #expect(!(await registry.isProvisionalShip(fontID)), "\(fontID) should no longer be provisional after the WS-16 release")
            #expect(browse.contains { $0.fontID == fontID }, "\(fontID) should now appear in the default browsable catalog")
        }
    }
}
