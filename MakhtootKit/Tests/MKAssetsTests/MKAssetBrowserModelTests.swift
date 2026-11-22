import CoreGraphics
import Foundation
import MKFoundation
import Testing
@testable import MKAssets

// WS-14 packet §5 task 9 accept criteria: "model unit tests: search 'نجمة'
// finds stars; favorites persist (stub store); free-entitlement lock
// behavior; recents order."
@Suite("MKAssetBrowserModel (T9)")
struct MKAssetBrowserModelTests {
    @Test func sectionsCoverAllFiveCategoriesInBrowserOrder() async {
        let model = await MKAssetBrowserModel()
        let sections = await model.sections()
        #expect(sections.map(\.category) == MKAssetCategory.browserOrder)
        #expect(sections.allSatisfy { !$0.assets.isEmpty })
    }

    @Test func searchForStarFindsStarAssets() async {
        let model = await MKAssetBrowserModel()
        await model.setSearchQuery("نجمة")
        let matches = await model.descriptors(in: .basicShapes)
        #expect(matches.contains { $0.assetID == "shape.star-8" })
        #expect(matches.allSatisfy { $0.nameAr.contains("نجمة") || $0.tags.contains { $0.contains("نجمة") } })
    }

    @Test func searchIsTashkeelInsensitive() async {
        let model = await MKAssetBrowserModel()
        await model.setSearchQuery("نَجْمَة") // same word with tashkeel
        let matches = await model.descriptors(in: .basicShapes)
        #expect(matches.contains { $0.assetID == "shape.star-8" })
    }

    @Test func emptySearchReturnsEveryAssetInCategory() async {
        let model = await MKAssetBrowserModel()
        let all = await model.descriptors(in: .frames)
        #expect(all.count == MKFrameGenerator.makeAll().count)
    }

    @Test func favoritesToggleAndPersistViaTheStubStore() async {
        let store = MKInMemoryAssetMetadataStore()
        let model = await MKAssetBrowserModel(metadataStore: store)
        await model.loadMetadata()
        #expect(await model.isFavorite("shape.star-8") == false)

        await model.toggleFavorite("shape.star-8")
        #expect(await model.isFavorite("shape.star-8"))
        #expect(await store.isFavorite(assetID: "shape.star-8"))

        // A second model instance backed by the SAME store sees the
        // persisted favorite after loading metadata.
        let secondModel = await MKAssetBrowserModel(metadataStore: store)
        await secondModel.loadMetadata()
        #expect(await secondModel.isFavorite("shape.star-8"))

        await model.toggleFavorite("shape.star-8")
        #expect(await model.isFavorite("shape.star-8") == false)
    }

    @Test func freeEntitlementLocksPremiumAssetsOnly() async {
        let model = await MKAssetBrowserModel(entitlement: FreeEntitlementStub())
        let freeShape = MKAssetLibrary.standard.descriptor(assetID: "shape.rectangle")!
        let premiumOrnament = MKAssetLibrary.standard.descriptor(assetID: "ornament.girih-strapwork")!
        #expect(await model.isLocked(freeShape) == false)
        #expect(await model.isLocked(premiumOrnament))
    }

    @Test func premiumEntitlementUnlocksEverything() async {
        let model = await MKAssetBrowserModel(entitlement: StubEntitlementResolver())
        for descriptor in MKAssetLibrary.standard.all {
            #expect(await model.isLocked(descriptor) == false, "\(descriptor.assetID)")
        }
    }

    @Test func selectingAPremiumAssetUnderFreeEntitlementReturnsPremiumRequired() async {
        let model = await MKAssetBrowserModel(entitlement: FreeEntitlementStub())
        let premiumOrnament = MKAssetLibrary.standard.descriptor(assetID: "ornament.girih-strapwork")!
        let outcome = await model.select(premiumOrnament)
        guard case .premiumRequired(let capability, let assetID, let nameAr) = outcome else {
            Issue.record("expected .premiumRequired")
            return
        }
        #expect(capability == .premiumAssets)
        #expect(assetID == premiumOrnament.assetID)
        #expect(nameAr == premiumOrnament.nameAr)
        // Blocked attempts must NOT be recorded as "used."
        #expect(await model.recentAssetIDs.contains(premiumOrnament.assetID) == false)
    }

    @Test func selectingAFreeAssetUnderFreeEntitlementPlacesIt() async {
        let model = await MKAssetBrowserModel(entitlement: FreeEntitlementStub())
        let freeShape = MKAssetLibrary.standard.descriptor(assetID: "shape.rectangle")!
        let outcome = await model.select(freeShape)
        guard case .placed = outcome else {
            Issue.record("expected .placed")
            return
        }
    }

    @Test func recentsOrderMostRecentFirstCappedAtTwelve() async {
        let model = await MKAssetBrowserModel(entitlement: StubEntitlementResolver())
        let shapes = MKAssetLibrary.standard.descriptors(in: .basicShapes)
        #expect(shapes.count >= 13, "fixture needs >12 distinct free shapes to exercise the cap")
        for shape in shapes.prefix(13) {
            _ = await model.select(shape)
        }
        let recents = await model.recentAssetIDs
        #expect(recents.count == 12)
        // Most recently placed (13th selected) is first.
        #expect(recents.first == shapes[12].assetID)
        // The very first selection (now evicted past the 12-cap) is gone.
        #expect(!recents.contains(shapes[0].assetID))
    }

    @Test func recentDescriptorsResolveInRecentOrder() async {
        let model = await MKAssetBrowserModel(entitlement: StubEntitlementResolver())
        let a = MKAssetLibrary.standard.descriptor(assetID: "shape.rectangle")!
        let b = MKAssetLibrary.standard.descriptor(assetID: "shape.ellipse")!
        _ = await model.select(a)
        _ = await model.select(b)
        let recents = await model.recentDescriptors()
        #expect(recents.first?.assetID == b.assetID)
        #expect(recents.count == 2)
    }
}
