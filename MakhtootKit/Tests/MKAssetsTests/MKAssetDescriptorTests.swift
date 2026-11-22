import Foundation
import Testing
@testable import MKAssets

// WS-14 packet §5 task 1 accept criteria: "decode test; every field
// documented; category enum locked to the five BRIEF classes (no invented
// categories)."
@Suite("MKAssetDescriptor / MKAssetCategory (T1)")
struct MKAssetDescriptorTests {
    @Test func categoryEnumIsLockedToTheFiveBriefClasses() {
        let expected: Set<MKAssetCategory> = [.basicShapes, .ornaments, .frames, .calligraphicElements, .patternBackgrounds]
        #expect(Set(MKAssetCategory.allCases) == expected)
        #expect(MKAssetCategory.allCases.count == 5)
    }

    @Test func everyCategoryHasANonEmptyArabicName() {
        for category in MKAssetCategory.allCases {
            #expect(!category.nameAr.isEmpty)
        }
    }

    @Test func descriptorRoundTripsThroughJSON() throws {
        let descriptor = MKAssetLibrary.standard.all[0]
        let data = try JSONEncoder().encode(descriptor)
        let decoded = try JSONDecoder().decode(MKAssetDescriptor.self, from: data)
        #expect(decoded == descriptor)
    }

    @Test func defaultAspectMatchesLocalBoundsWidthOverHeight() {
        for descriptor in MKAssetLibrary.standard.all {
            let bounds = descriptor.pathData.localBounds
            guard bounds.height != 0 else { continue }
            let expected = bounds.width / bounds.height
            #expect(abs(descriptor.defaultAspect - expected) < 0.0001, "\(descriptor.assetID)")
        }
    }

    @Test func everyLibraryAssetHasNonEmptyGeometry() {
        for descriptor in MKAssetLibrary.standard.all {
            #expect(!descriptor.pathData.subpaths.isEmpty, "\(descriptor.assetID) has no subpaths")
            #expect(!descriptor.pathData.regions.isEmpty, "\(descriptor.assetID) has no styleable regions")
        }
    }

    @Test func manifestDecodeTest() throws {
        // T1's literal accept criterion: the manifest is Codable and
        // decodes. Exercised directly here against an encode of the full
        // library (the bundled-resource variant is covered separately by
        // MKAssetManifestResourceTests, which also loads via Bundle.module).
        let data = try MKAssetManifestCodec.encode(MKAssetLibrary.standard.all)
        let decoded = try MKAssetManifestCodec.decode(data)
        #expect(decoded.count == MKAssetLibrary.standard.all.count)
    }
}
