import Foundation
import MKFoundation

// WS-14 packet §5 task 13. "On placing any `isPremium` asset, the document
// gains a `premiumContent.assets` flag entry... Removing the last premium
// asset clears it." The real flag this feeds is a `MKModel` MANIFEST field
// (packet: "MKModel manifest field ، coordinate: WS-02 owns manifest
// schema"), which is outside this run's fence (`MKAssets` only) to add or
// even confirm exists yet. `MKPremiumContentLedger` is the real, tested,
// MKAssets-owned COMPUTATION this task needs ، a pure value type any future
// document-session integration (WS-02/WS-13) mirrors into the actual
// manifest field on every placement/removal, exactly the seam
// `MKAssetInstantiator.Placement`'s `MKPlacementRecord` exists to feed.
public struct MKPremiumContentLedger: Hashable, Sendable, Equatable {
    private var entries: [MKNodeID: MKPlacementRecord]

    public init(entries: [MKNodeID: MKPlacementRecord] = [:]) {
        self.entries = entries
    }

    /// Records a placement. No-ops (records everything, not just premium
    /// ones) so `removing` always has the full context to report an
    /// accurate name list even for a mixed free/premium scene ، but
    /// `isPremiumContentPresent`/`premiumAssetNamesAr` only ever surface
    /// the premium subset.
    public func adding(_ record: MKPlacementRecord) -> MKPremiumContentLedger {
        var copy = self
        copy.entries[record.nodeID] = record
        return copy
    }

    /// Clears the record for a removed/deleted node. No-op if `nodeID` was
    /// never a tracked placement (e.g. a non-asset shape).
    public func removing(nodeID: MKNodeID) -> MKPremiumContentLedger {
        var copy = self
        copy.entries.removeValue(forKey: nodeID)
        return copy
    }

    /// D-119's "premium content present" project flag ، true iff at least
    /// one currently-tracked placement is premium.
    public var isPremiumContentPresent: Bool {
        entries.values.contains { $0.isPremium }
    }

    /// Arabic names of every currently-placed premium asset, for the
    /// free-tier export replace-or-subscribe flow's "offending assets by
    /// Arabic name" list (packet task 13's accept criterion; ARCHITECTURE
    /// §16.2's `MKExportGate` item list). Stable order: insertion order of
    /// the still-tracked entries, deduplicated by name (two placements of
    /// the same premium asset show its name once).
    public var premiumAssetNamesAr: [String] {
        var seen = Set<String>()
        var names: [String] = []
        for record in entries.values where record.isPremium {
            if seen.insert(record.nameAr).inserted { names.append(record.nameAr) }
        }
        return names.sorted()
    }

    public var count: Int { entries.count }
    public var premiumCount: Int { entries.values.filter(\.isPremium).count }
}
