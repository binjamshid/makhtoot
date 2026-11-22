import Foundation
import Testing
@testable import MKAssets

// WS-14 packet §5 task 13 accept criteria: "integration test: place premium
// ornament → flag set; delete → cleared; export gate sees the list." See
// `MKPremiumContentLedger`'s file header for the documented `MKModel`
// manifest-field coordination note (out of this run's fence) ، this test
// exercises the real, MKAssets-owned computation the packet's task asks
// for, at the level this run can actually build.
@Suite("MKPremiumContentLedger (T13)")
struct MKPremiumContentMarkingTests {
    private let instantiator = MKAssetInstantiator()

    @Test func placingAPremiumOrnamentSetsTheFlag() {
        let premiumOrnament = MKAssetLibrary.standard.descriptor(assetID: "ornament.girih-strapwork")!
        #expect(premiumOrnament.isPremium)

        var ledger = MKPremiumContentLedger()
        #expect(!ledger.isPremiumContentPresent)

        let placement = instantiator.place(premiumOrnament)
        ledger = ledger.adding(placement.record)

        #expect(ledger.isPremiumContentPresent)
        #expect(ledger.premiumAssetNamesAr == [premiumOrnament.nameAr])
    }

    @Test func deletingTheLastPremiumAssetClearsTheFlag() {
        let premiumOrnament = MKAssetLibrary.standard.descriptor(assetID: "ornament.girih-strapwork")!
        var ledger = MKPremiumContentLedger()
        let placement = instantiator.place(premiumOrnament)
        ledger = ledger.adding(placement.record)
        #expect(ledger.isPremiumContentPresent)

        ledger = ledger.removing(nodeID: placement.record.nodeID)
        #expect(!ledger.isPremiumContentPresent)
        #expect(ledger.premiumAssetNamesAr.isEmpty)
    }

    @Test func flagStaysSetWhileAnyPremiumAssetRemains() {
        let a = MKAssetLibrary.standard.descriptor(assetID: "ornament.girih-strapwork")!
        let b = MKAssetLibrary.standard.descriptor(assetID: "ornament.mandorla-lozenge-medallion")!
        var ledger = MKPremiumContentLedger()
        let placementA = instantiator.place(a)
        let placementB = instantiator.place(b)
        ledger = ledger.adding(placementA.record).adding(placementB.record)
        #expect(ledger.isPremiumContentPresent)

        ledger = ledger.removing(nodeID: placementA.record.nodeID)
        #expect(ledger.isPremiumContentPresent) // b still present
        #expect(ledger.premiumAssetNamesAr == [b.nameAr])

        ledger = ledger.removing(nodeID: placementB.record.nodeID)
        #expect(!ledger.isPremiumContentPresent)
    }

    @Test func freeAssetsNeverSetTheFlag() {
        let freeShape = MKAssetLibrary.standard.descriptor(assetID: "shape.rectangle")!
        var ledger = MKPremiumContentLedger()
        let placement = instantiator.place(freeShape)
        ledger = ledger.adding(placement.record)
        #expect(!ledger.isPremiumContentPresent)
    }

    /// "export gate sees the list" ، `premiumAssetNamesAr` is exactly the
    /// Arabic-name list ARCHITECTURE §16.2's `MKExportGate` needs for the
    /// replace-or-subscribe flow's offending-items display.
    @Test func premiumAssetNamesArListsEveryDistinctPremiumAssetByArabicName() {
        let ornament = MKAssetLibrary.standard.descriptor(assetID: "ornament.girih-strapwork")!
        let frame = MKAssetLibrary.standard.descriptor(assetID: "frame.oval")!
        var ledger = MKPremiumContentLedger()
        ledger = ledger.adding(instantiator.place(ornament).record)
        ledger = ledger.adding(instantiator.place(frame).record)
        // Two placements of the SAME asset must not duplicate the name.
        ledger = ledger.adding(instantiator.place(ornament).record)

        #expect(Set(ledger.premiumAssetNamesAr) == Set([ornament.nameAr, frame.nameAr]))
        #expect(ledger.premiumCount == 3)
    }
}
