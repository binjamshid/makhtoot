import CoreGraphics
import Foundation

// WS-14 packet §5 task 1. `MKAssetDescriptor` ، every field task 1's prose
// names explicitly, documented per the task's accept criterion ("every
// field documented").

/// Task 6's "9-slice-like path groups metadata" seam: records which margin
/// (in the asset's own local units, same space as `MKAssetGeometry
/// .localBounds`) around a frame's edge is the "fixed-scale corner" zone.
/// v1 SHIPS the field and documents it (task 6 accept criterion: "non-
/// uniform-scale behavior documented"); v1 placement/transform behavior is
/// still uniform-scale-only ، `MKAssetInstantiator` does not yet stretch
/// edges independently of corners. A future WS-06 (`MKCanvas`) inspector
/// affordance for "stretch frame edges" would read this field to know how
/// much of the frame's border is corner vs. stretchable edge.
public struct MKFrameNineSliceInsets: Hashable, Sendable, Codable, Equatable {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double

    public init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    /// Even margin on all four sides ، the common case for the symmetric
    /// v1 frame set.
    public static func uniform(_ margin: Double) -> MKFrameNineSliceInsets {
        MKFrameNineSliceInsets(top: margin, left: margin, bottom: margin, right: margin)
    }
}

/// One bundled, placeable design element (BRIEF: shapes / ornaments /
/// frames / calligraphic elements / pattern backgrounds ، NOT a template,
/// §1 mission statement).
public struct MKAssetDescriptor: Hashable, Sendable, Codable, Equatable, Identifiable {
    /// Stable machine id, dotted `<category-short>.<slug>` (e.g.
    /// `"ornament.islamic-star-8"`, task 1's own example). Never changes
    /// once shipped ، it is the join key into `MKAssetProvenanceStore` and
    /// the future dedup/re-link key T3 describes.
    public var assetID: String

    /// Idiomatic Arabic display name (e.g. "نجمة ثمانية") ، never a
    /// transliterated-English name (task 14). Becomes the placed node's
    /// `MKNodeCore.name` (T3: "name = nameAr").
    public var nameAr: String

    /// One of the five BRIEF-locked categories (§4 D-111 "no invented
    /// categories" via `MKAssetCategory`'s closed `CaseIterable` set).
    public var category: MKAssetCategory

    /// Arabic search/browse tags, e.g. `["هندسي", "إسلامي", "نجمة"]` for
    /// "نجمة ثمانية" (task 1's own example). Every asset carries ≥2 (task 14
    /// accept criterion), never transliterated English.
    public var tags: [String]

    /// Whether placing this asset requires premium entitlement (D-119).
    /// Pattern backgrounds are unconditionally `true` (D-215/T8); basic
    /// shapes are unconditionally `false`; ornaments/frames/calligraphic
    /// elements are a mixed free/premium split per task 5–7's minimums.
    public var isPremium: Bool

    /// The authored vector geometry (subpaths, fill rule, styleable
    /// regions) ، see `MKAssetGeometry`'s file header for the full model
    /// and the fill-rule/hole-cancellation discipline.
    public var pathData: MKAssetGeometry

    /// `pathData.localBounds.width / pathData.localBounds.height` ، the
    /// aspect ratio the placement default transform preserves (a square
    /// asset gets `1.0`; a wide frame gets >1, etc.). Stored redundantly
    /// (rather than derived on every read) because it is the one number the
    /// asset browser's grid layout needs before decoding/measuring the full
    /// path ، cheap to keep in sync at authoring time (every generator in
    /// this module computes it from the same `localBounds` it hands to
    /// `MKAssetGeometry`, so the two can never drift for shipped assets;
    /// `AssetProvenanceAudit`-adjacent `MKAssetDescriptorTests` assert the
    /// invariant holds for the whole library).
    public var defaultAspect: Double

    /// Join key into `MKAssetProvenanceStore` (task 2). Equal to `assetID`
    /// for every asset in this library ، kept as its own field (rather than
    /// re-using `assetID` implicitly) because the packet's task 1 names it
    /// as a distinct field, and because a future asset-pack (T15's
    /// `libraryVersion` seam) could in principle reference a shared
    /// provenance record under a different key.
    public var provenanceRef: String

    /// Manifest schema/versioning seam (T15): the asset-pack version this
    /// descriptor shipped in. v1 = `1` for every asset (the one bundled
    /// pack); a future downloadable asset pack (§2 OUT, v2 seam) would
    /// increment this per-pack, never per-asset-edit.
    public var libraryVersion: Int

    /// Task 6's 9-slice seam (see `MKFrameNineSliceInsets`'s doc comment).
    /// Non-`nil` only for `.frames` category assets that have a
    /// rectangular corner/edge structure; `nil` for every other category
    /// and for non-rectangular frames (arch/circular/cartouche) where a
    /// 9-slice margin isn't a meaningful concept.
    public var nineSliceInsets: MKFrameNineSliceInsets?

    public init(
        assetID: String,
        nameAr: String,
        category: MKAssetCategory,
        tags: [String],
        isPremium: Bool,
        pathData: MKAssetGeometry,
        provenanceRef: String,
        libraryVersion: Int = 1,
        nineSliceInsets: MKFrameNineSliceInsets? = nil
    ) {
        self.assetID = assetID
        self.nameAr = nameAr
        self.category = category
        self.tags = tags
        self.isPremium = isPremium
        self.pathData = pathData
        let bounds = pathData.localBounds
        self.defaultAspect = bounds.height == 0 ? 1 : bounds.width / bounds.height
        self.provenanceRef = provenanceRef
        self.libraryVersion = libraryVersion
        self.nineSliceInsets = nineSliceInsets
    }

    public var id: String { assetID }
}
