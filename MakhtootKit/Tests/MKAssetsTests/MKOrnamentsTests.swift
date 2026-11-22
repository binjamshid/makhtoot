import Foundation
import Testing
@testable import MKAssets

// WS-14 packet §5 task 5 accept criteria: "each ornament has provenance +
// thumbnail + Arabic name/tags; visual QA sheet rendered (T11) reviewed for
// quality (no self-intersection artifacts, clean fills at 4K raster)." The
// "no self-intersection artifacts" / "clean fills at 4K" claims are the
// MANUAL visual-QA gate (T-asset-01, contact sheet review) ، this suite
// covers everything mechanically checkable: counts, the free/premium
// split, provenance/thumbnail presence, and that every ornament rasterizes
// without error at a 4K-equivalent size (a structural proxy for "doesn't
// crash/degenerate at high resolution," not a substitute for the human
// visual review).
@Suite("MKOrnamentGenerator (T5)")
struct MKOrnamentsTests {
    @Test func atLeastSixteenOrnamentsWithSixFreeAndTenPremium() {
        let ornaments = MKOrnamentGenerator.makeAll()
        #expect(ornaments.count >= 16)
        #expect(ornaments.allSatisfy { $0.category == .ornaments })
        #expect(ornaments.filter { !$0.isPremium }.count == 6)
        #expect(ornaments.filter(\.isPremium).count >= 10)
        #expect(Set(ornaments.map(\.assetID)).count == ornaments.count)
    }

    @Test func everyOrnamentHasArabicNameAndAtLeastTwoTags() {
        for ornament in MKOrnamentGenerator.makeAll() {
            #expect(!ornament.nameAr.isEmpty)
            #expect(ornament.tags.count >= 2, "\(ornament.assetID)")
        }
    }

    @Test func everyOrnamentHasAProvenanceRecordWithConstructionNotes() {
        let store = MKAssetProvenanceStore.standard
        for ornament in MKOrnamentGenerator.makeAll() {
            let record = store.provenance(for: ornament.assetID)
            #expect(record != nil, "\(ornament.assetID)")
            #expect(!(record?.notes.isEmpty ?? true))
        }
    }

    @Test func everyOrnamentProducesAThumbnailAtStandardAndFourKSizes() {
        for ornament in MKOrnamentGenerator.makeAll() {
            let small = MKAssetThumbnailRenderer.render(descriptor: ornament, size: CGSize(width: 200, height: 200))
            let large = MKAssetThumbnailRenderer.render(descriptor: ornament, size: CGSize(width: 4096, height: 4096))
            #expect(small != nil, "\(ornament.assetID) failed to render at 200pt")
            #expect(large != nil, "\(ornament.assetID) failed to render at 4K")
        }
    }

    @Test func star8RosetteIsNamedKhatamPerThePacketExample() {
        let khatam = MKOrnamentGenerator.makeAll().first { $0.assetID == "ornament.star-rosette-8" }
        #expect(khatam?.nameAr == "خاتم")
        #expect(!khatam!.isPremium)
    }

    @Test func mihrabArchIsArchitecturalNotTextual() {
        // §6 compliance note: the mihrab-arch ornament is aniconic/
        // architectural, never presented as Qur'anic content. Verified at
        // the frame level (`MKFrameGenerator.archFrame`) and here for the
        // ornament-category equivalent name check.
        let mihrab = MKOrnamentGenerator.makeAll().first { $0.assetID == "ornament.mihrab-arch-outline" }
        #expect(mihrab != nil)
        #expect(mihrab!.tags.contains("محراب"))
    }
}
